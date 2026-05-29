import Foundation

/// 접근토큰 단일 소유·만료 추적·자동 재발급(K2 — actor 격리로 동시 접근 안전).
/// 토큰은 메모리 보관(DB_SCHEMA "메모리 보관 택"). appkey/secret만 Keychain 영속.
/// 재발급 실패는 throw로 표면화 → ViewModel이 auth-failed("앱 재시작 안내")로 처리(M2).
public actor TokenManager {
    public struct Token: Equatable, Sendable {
        public let value: String
        public let expiresAt: Date
        public init(value: String, expiresAt: Date) {
            self.value = value
            self.expiresAt = expiresAt
        }
    }

    /// 토큰 발급 호출(REST). 네트워크 세부는 주입 — TokenManager는 만료·캐시 로직만 소유.
    public typealias Fetcher = @Sendable () async throws -> Token

    private let fetcher: Fetcher
    private let refreshMargin: TimeInterval      // 만료 잔여가 이 값 이하이면 선제 재발급
    private let now: @Sendable () -> Date
    private var cached: Token?

    public init(
        refreshMargin: TimeInterval = 300,
        now: @escaping @Sendable () -> Date = { Date() },
        fetcher: @escaping Fetcher
    ) {
        self.fetcher = fetcher
        self.refreshMargin = refreshMargin
        self.now = now
    }

    /// 유효 토큰 반환. 캐시가 만료 임박(잔여 ≤ margin)이면 재발급 후 반환.
    public func validToken() async throws -> String {
        if let cached, cached.expiresAt.timeIntervalSince(now()) > refreshMargin {
            return cached.value
        }
        let fresh = try await fetcher()
        cached = fresh
        return fresh.value
    }

    /// 401 등으로 현재 토큰 무효 시 호출 → 다음 validToken()이 강제 재발급.
    public func invalidate() {
        cached = nil
    }
}
