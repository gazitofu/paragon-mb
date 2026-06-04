import Foundation

// KIS(한국투자증권) REST 클라이언트.
// 요구사항 SSOT: docs/API_SPEC.md §인증·§현재가·§종목명·§EGW00201 실측.
// Floor 4: auth/credential 로직은 여기 명시 — config/helper에 숨기지 않음.
public struct KISRESTClient {

    // === SECTION: ERROR ===

    public enum RESTError: Error, Equatable {
        /// rt_cd ≠ "0" 또는 output 빈 객체 (P6: 실측 전 1차 가정)
        case apiError(code: String, message: String)
        /// 종목 필드 누락 (미존재 종목코드 가능)
        case lookupFailed(String)
        /// Keychain 자격증명 미로드
        case missingToken
        /// 토큰 발급 거부 (EGW 등)
        case tokenRejected(message: String)
        /// HTTP 레벨 오류
        case http(Int)
        /// JSON 파싱 실패
        case decodingFailed
    }

    // === SECTION: DTO ===

    private struct TokenResponse: Decodable {
        let access_token: String?
        let token_type: String?
        let expires_in: Int?
        let access_token_token_expired: String?
        // rt_cd/msg_cd: 발급 실패 시 포함 가능 (P6)
        let rt_cd: String?
        let msg_cd: String?
        let msg1: String?
    }

    private struct ApprovalResponse: Decodable {
        let approval_key: String?
        let rt_cd: String?
        let msg_cd: String?
        let msg1: String?
    }

    // CTPF1002R 응답 (종목명 조회)
    private struct StockInfoEnvelope: Decodable {
        let rt_cd: String?
        let msg_cd: String?
        let msg1: String?
        let output: StockInfoOutput?
        struct StockInfoOutput: Decodable {
            let prdt_abrv_name: String?  // 상품약어명 — 앱 표시명 (trailing 공백 필요 trim)
            let pdno: String?            // 12자리 zero-pad+A접두 (응답 전용, 코드 키로 미사용)
        }
    }

    // FHKST01010100 응답 (현재가 조회)
    private struct InquirePriceEnvelope: Decodable {
        let rt_cd: String?
        let msg_cd: String?
        let msg1: String?
        let output: InquirePriceOutput?
        struct InquirePriceOutput: Decodable {
            let stck_prpr: String?       // 현재가(원 정수 문자열)
            let prdy_vrss: String?       // 전일대비(signed 직접 파싱 — P5, sign 재구성 금지)
            let prdy_vrss_sign: String?  // 부호 필드 (2=상승·5=하락, 검증용만)
            let prdy_ctrt: String?       // 등락률(% signed)
            let stck_sdpr: String?       // 기준가=전일종가(원)
            let stck_shrn_iscd: String?  // 종목코드(6자리)
        }
    }

    // === SECTION: THROTTLE ===

    // 직렬 큐 + last-call 타임스탬프 600ms 가드 (EGW00201 회피 — REST 전 호출 전역 직렬).
    private actor ThrottleQueue {
        private var lastCallAt: Date = .distantPast
        private let minInterval: TimeInterval = 0.600

        func waitIfNeeded() async {
            let now = Date()
            let elapsed = now.timeIntervalSince(lastCallAt)
            if elapsed < minInterval {
                let delay = minInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            lastCallAt = Date()
        }
    }

    // === SECTION: INIT ===

    private let environment: KISEnvironment.Type
    private let session: URLSession
    private let throttle = ThrottleQueue()

    public init(session: URLSession = .shared) {
        self.environment = KISEnvironment.self
        self.session = session
    }

    // === SECTION: AUTH ===

    /// 액세스 토큰 발급. POST /oauth2/tokenP, body key `appsecret` (tokenP 전용 — Approval `secretkey`와 다름, 실측).
    /// 자격증명은 반드시 Keychain 경유 값으로 주입 (V-B2 게이트: env 직접 읽기 금지).
    public func issueToken(appKey: String, appSecret: String) async throws -> TokenManager.Token {
        var req = URLRequest(url: KISEnvironment.tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "client_credentials",
            "appkey": appKey,
            "appsecret": appSecret,  // ⚠️ tokenP 전용 키명 (Approval은 secretkey)
        ])
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw RESTError.http(http.statusCode)
        }
        let dto = try decodeOrThrow(TokenResponse.self, from: data)
        // rt_cd 존재하고 "0"이 아니면 거부
        if let rc = dto.rt_cd, rc != "0" {
            throw RESTError.tokenRejected(message: dto.msg1 ?? dto.msg_cd ?? rc)
        }
        guard let tokenValue = dto.access_token, !tokenValue.isEmpty else {
            throw RESTError.missingToken
        }
        let expiry = parseExpiry(expiresIn: dto.expires_in, expiredAt: dto.access_token_token_expired)
        return TokenManager.Token(value: tokenValue, expiresAt: expiry)
    }

    /// WS 접속키 발급. POST /oauth2/Approval, body key `secretkey` (tokenP `appsecret`와 다름 — 실측).
    /// 호출마다 새 키 발급, 별도 분당 제한 미관측. 스로틀 큐 경유.
    public func issueApprovalKey(appKey: String, appSecret: String) async throws -> String {
        await throttle.waitIfNeeded()
        var req = URLRequest(url: KISEnvironment.approvalURL)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "client_credentials",
            "appkey": appKey,
            "secretkey": appSecret,  // ⚠️ Approval 전용 키명 (tokenP는 appsecret)
        ])
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw RESTError.http(http.statusCode)
        }
        let dto = try decodeOrThrow(ApprovalResponse.self, from: data)
        if let rc = dto.rt_cd, rc != "0" {
            throw RESTError.tokenRejected(message: dto.msg1 ?? dto.msg_cd ?? rc)
        }
        guard let key = dto.approval_key, !key.isEmpty else {
            throw RESTError.missingToken
        }
        return key
    }

    // === SECTION: LOOKUP ===

    /// 종목명 조회. CTPF1002R — prdt_abrv_name trailing trim → Symbol.
    /// 스로틀 큐 경유. rt_cd≠"0" 또는 output 없음 → lookupFailed (P6 1차 가정).
    public func lookupName(code: String, token: String, appKey: String, appSecret: String) async throws -> Symbol {
        await throttle.waitIfNeeded()
        var components = URLComponents(url: KISEnvironment.restBaseURL, resolvingAgainstBaseURL: false)!
        components.path = "/uapi/domestic-stock/v1/quotations/search-stock-info"
        components.queryItems = [
            URLQueryItem(name: "PRDT_TYPE_CD", value: "300"),  // 300 = 주식·ETF·ETN·ELW (실측)
            URLQueryItem(name: "PDNO", value: code),
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        req = applyCommonHeaders(req, token: token, appKey: appKey, appSecret: appSecret, trId: "CTPF1002R")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw RESTError.http(http.statusCode)
        }
        let dto = try decodeOrThrow(StockInfoEnvelope.self, from: data)
        try assertSuccess(rt_cd: dto.rt_cd, msg: dto.msg1 ?? dto.msg_cd)
        guard let out = dto.output,
              let rawName = out.prdt_abrv_name, !rawName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RESTError.lookupFailed("종목명 필드 누락 (미존재 코드 가능, code=\(code))")
        }
        let name = rawName.trimmingCharacters(in: .whitespaces)
        return Symbol(code: code, name: name)
    }

    /// 현재가 조회. FHKST01010100 → Quote.
    /// prdy_vrss: signed 직접 파싱 (부호 필드로 재구성 금지 — 경계 규칙 ④, P5).
    /// 스로틀 큐 경유.
    public func lookupPrice(code: String, token: String, appKey: String, appSecret: String) async throws -> Quote {
        await throttle.waitIfNeeded()
        var components = URLComponents(url: KISEnvironment.restBaseURL, resolvingAgainstBaseURL: false)!
        components.path = "/uapi/domestic-stock/v1/quotations/inquire-price"
        components.queryItems = [
            URLQueryItem(name: "FID_COND_MRKT_DIV_CODE", value: "J"),
            URLQueryItem(name: "FID_INPUT_ISCD", value: code),
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        req = applyCommonHeaders(req, token: token, appKey: appKey, appSecret: appSecret, trId: "FHKST01010100")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw RESTError.http(http.statusCode)
        }
        let dto = try decodeOrThrow(InquirePriceEnvelope.self, from: data)
        try assertSuccess(rt_cd: dto.rt_cd, msg: dto.msg1 ?? dto.msg_cd)
        guard let out = dto.output else {
            throw RESTError.lookupFailed("output 없음 (code=\(code))")
        }
        guard let priceStr = out.stck_prpr, let price = KISQuoteParser.parseSignedInt(priceStr), price > 0 else {
            throw RESTError.lookupFailed("stck_prpr 누락/파싱 실패 (code=\(code))")
        }
        // prdy_vrss: signed 직접 파싱 via KISQuoteParser.parseSignedInt (콤마·부호 견고 처리 — R1 수렴)
        // 부호 필드 `prdy_vrss_sign` 재구성 금지 — 경계 규칙 ④
        // stck_sdpr(기준가=전일종가) 우선, 없으면 price - prdy_vrss 역산
        let change = out.prdy_vrss.flatMap { KISQuoteParser.parseSignedInt($0) } ?? 0
        let previousClose = out.stck_sdpr.flatMap { KISQuoteParser.parseSignedInt($0) } ?? (price - change)
        return Quote(price: price, previousClose: previousClose)
    }

    // === SECTION: EXPIRY ===

    /// 토큰 만료시각 파싱. `expires_in`(초, 실측 86400) 우선, 없으면 `access_token_token_expired`(KST "yyyy-MM-dd HH:mm:ss") 폴백.
    func parseExpiry(expiresIn: Int?, expiredAt: String?) -> Date {
        if let seconds = expiresIn, seconds > 0 {
            return Date().addingTimeInterval(TimeInterval(seconds))
        }
        if let s = expiredAt, !s.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            f.timeZone = TimeZone(identifier: "Asia/Seoul")
            f.locale = Locale(identifier: "en_US_POSIX")
            if let d = f.date(from: s) { return d }
        }
        // 양쪽 파싱 실패 시 보수적 23h 폴백 (분당 재발급 제한 안전 유지)
        return Date().addingTimeInterval(23 * 3600)
    }

    // === SECTION: HELPERS ===

    /// rt_cd≠"0" 시 apiError throw (P6 1차 가정 — 라이브 관측으로 보정).
    private func assertSuccess(rt_cd: String?, msg: String?) throws {
        guard let rc = rt_cd else { return }  // rt_cd 없으면 성공으로 간주
        if rc != "0" {
            throw RESTError.apiError(code: rc, message: msg ?? rc)
        }
    }

    /// 공통 요청 헤더 적용. 자격증명은 값만 전달 — 로그/예외 메시지 비노출 (Floor 4).
    private func applyCommonHeaders(_ req: URLRequest, token: String, appKey: String, appSecret: String, trId: String) -> URLRequest {
        var r = req
        r.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        r.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        r.setValue(appKey, forHTTPHeaderField: "appkey")
        r.setValue(appSecret, forHTTPHeaderField: "appsecret")
        r.setValue(trId, forHTTPHeaderField: "tr_id")
        r.setValue("P", forHTTPHeaderField: "custtype")
        return r
    }

    private func decodeOrThrow<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw RESTError.decodingFailed
        }
    }
}
