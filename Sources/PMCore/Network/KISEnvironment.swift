import Foundation

/// KIS(한국투자증권) Open API URL 상수 레이어.
/// KiwoomEnvironment와 병존 — 치환(Task 5 AppDelegate 조립)까지 두 파일 공존 유지.
/// 요구사항 SSOT: docs/API_SPEC.md §실측 확정·§[3] 이식 체크리스트.
public enum KISEnvironment {
    /// REST base URL — 실전. HTTPS, 포트 9443.
    public static let restBaseURL = URL(string: "https://openapi.koreainvestment.com:9443")!

    /// 토큰 발급 엔드포인트 (`POST /oauth2/tokenP`, body key `appsecret`).
    public static let tokenURL = URL(string: "https://openapi.koreainvestment.com:9443/oauth2/tokenP")!

    /// WS 접속키 발급 엔드포인트 (`POST /oauth2/Approval`, body key `secretkey` — tokenP와 다름, 실측).
    public static let approvalURL = URL(string: "https://openapi.koreainvestment.com:9443/oauth2/Approval")!

    /// WS 실시간 체결 URL — 평문 ws 전용 (wss TLS -1200 실패, KIS 정책).
    /// ATS 예외 필요: Info.plist NSExceptionDomains ops.koreainvestment.com (Task 9).
    public static let webSocketURL = URL(string: "ws://ops.koreainvestment.com:21000")!
}
