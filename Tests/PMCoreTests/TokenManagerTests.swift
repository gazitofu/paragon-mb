import XCTest
@testable import PMCore

/// T-token: 토큰 캐시·만료 재발급·margin·invalidate·실패 표면화(K2·M2 token 행).
/// tasks.md 미등재이나 인증 타이밍은 Strict 핵심 — 추가 잠금.
final class TokenManagerTests: XCTestCase {

    private actor Counter {
        private(set) var n = 0
        func bump() { n += 1 }
    }

    private func token(_ offset: TimeInterval) -> TokenManager.Token {
        TokenManager.Token(value: "tok", expiresAt: Date().addingTimeInterval(offset))
    }

    func testFetchesOnceWhenValid() async throws {
        let c = Counter()
        let tm = TokenManager(refreshMargin: 300, fetcher: { await c.bump(); return self.token(3600) })
        _ = try await tm.validToken()
        _ = try await tm.validToken()
        let n = await c.n
        XCTAssertEqual(n, 1)   // 유효 캐시 → 두 번째는 재발급 안 함
    }

    func testRefetchesWhenExpired() async throws {
        let c = Counter()
        let tm = TokenManager(refreshMargin: 300, fetcher: { await c.bump(); return self.token(-1) })
        _ = try await tm.validToken()
        _ = try await tm.validToken()
        let n = await c.n
        XCTAssertEqual(n, 2)   // 만료 → 매번 재발급
    }

    func testRefetchesWithinRefreshMargin() async throws {
        let c = Counter()
        // 잔여 100s < margin 300s → 선제 재발급 대상
        let tm = TokenManager(refreshMargin: 300, fetcher: { await c.bump(); return self.token(100) })
        _ = try await tm.validToken()
        _ = try await tm.validToken()
        let n = await c.n
        XCTAssertEqual(n, 2)
    }

    func testInvalidateForcesRefetch() async throws {
        let c = Counter()
        let tm = TokenManager(refreshMargin: 300, fetcher: { await c.bump(); return self.token(3600) })
        _ = try await tm.validToken()
        await tm.invalidate()
        _ = try await tm.validToken()
        let n = await c.n
        XCTAssertEqual(n, 2)
    }

    func testFetcherErrorPropagates() async {
        struct Boom: Error {}
        let tm = TokenManager(fetcher: { throw Boom() })
        do {
            _ = try await tm.validToken()
            XCTFail("재발급 실패가 표면화되지 않음")
        } catch {
            // 기대: throw 전파 → ViewModel auth-failed 처리
        }
    }
}
