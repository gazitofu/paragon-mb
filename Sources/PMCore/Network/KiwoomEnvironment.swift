import Foundation

/// 키움 모의/실 baseURL·엔드포인트 상수(K7 — 전환 로직 없음, 상수만).
/// 엔드포인트는 PoC 실측·사용자 확인(2026-05-29): mockapi.kiwoom.com(.NET 래퍼)은 outdated.
public enum KiwoomEnvironment {
    case real
    case mock

    /// REST baseURL — 실전 api.kiwoom.com / 모의 :9443. (모의 구분은 토큰에 내재)
    public var restBaseURL: URL {
        switch self {
        case .real: return URL(string: "https://api.kiwoom.com")!
        case .mock: return URL(string: "https://api.kiwoom.com:9443")!
        }
    }

    /// WebSocket URL — 실전·모의 공통.
    public var webSocketURL: URL {
        URL(string: "wss://api.kiwoom.com:10000/api/dostk/websocket")!
    }

    /// OAuth 토큰 발급(검증됨, PoC).
    public var tokenURL: URL { restBaseURL.appendingPathComponent("oauth2/token") }
}
