import Foundation

/// 키움 REST 클라이언트 — 토큰 발급(검증됨, PoC) + 종목 조회(미검증, 4b·격리 디코더).
public struct KiwoomRESTClient {
    public enum RESTError: Error, Equatable {
        case tokenRejected(code: Int, message: String)
        case missingToken
        case lookupFailed(code: Int, message: String)
        case http(Int)
    }

    private let environment: KiwoomEnvironment
    private let session: URLSession

    public init(environment: KiwoomEnvironment, session: URLSession = .shared) {
        self.environment = environment
        self.session = session
    }

    /// OAuth 토큰 발급. PoC 검증 경로 — POST /oauth2/token {grant_type,appkey,secretkey}.
    public func issueToken(appKey: String, secret: String) async throws -> TokenManager.Token {
        var req = URLRequest(url: environment.tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "client_credentials",
            "appkey": appKey,
            "secretkey": secret,
        ])
        let (data, _) = try await session.data(for: req)
        let dto = try JSONDecoder().decode(TokenDTO.self, from: data)
        if let rc = dto.return_code, rc != 0 {
            throw RESTError.tokenRejected(code: rc, message: dto.return_msg ?? "")
        }
        guard let token = dto.token, !token.isEmpty else { throw RESTError.missingToken }
        let expiry = Self.parseExpiry(dto.expires_dt) ?? Date().addingTimeInterval(23 * 3600)
        return TokenManager.Token(value: token, expiresAt: expiry)
    }

    /// 종목 조회 — 검증됨(PoC 2026-05-29): POST /api/dostk/stkinfo, api-id ka10001, body {stk_cd}.
    /// 종목명 + 초기 시세(현재가·전일종가) 반환. 파싱은 KiwoomQuoteParser.parseStockInfo(잠금) 위임.
    public func lookup(code: String, token: String) async throws -> (symbol: Symbol, quote: Quote) {
        var req = URLRequest(url: environment.restBaseURL.appendingPathComponent("api/dostk/stkinfo"))
        req.httpMethod = "POST"
        req.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        req.setValue("ka10001", forHTTPHeaderField: "api-id")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["stk_cd": code])
        let (data, _) = try await session.data(for: req)
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw RESTError.lookupFailed(code: -1, message: "JSON 파싱 실패")
        }
        if let rc = json["return_code"] as? Int, rc != 0 {
            throw RESTError.lookupFailed(code: rc, message: json["return_msg"] as? String ?? "")
        }
        guard let parsed = KiwoomQuoteParser.parseStockInfo(json) else {
            throw RESTError.lookupFailed(code: -1, message: "종목 필드 누락(미존재 코드 가능)")
        }
        return parsed
    }

    private struct TokenDTO: Decodable {
        let token: String?
        let token_type: String?
        let expires_dt: String?
        let return_code: Int?
        let return_msg: String?
    }

    /// 토큰 만료시각 파싱. 키움 expires_dt = KST "yyyyMMddHHmmss"(PoC: 20260530095257).
    public static func parseExpiry(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyyMMddHHmmss"
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: s)
    }
}
