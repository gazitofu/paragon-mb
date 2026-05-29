import XCTest
@testable import PMCore

/// T-policy: 관심종목 한도 상수 잠금(K6 — 수치 하드의존 금지).
final class PolicyTests: XCTestCase {
    func testMaxWatchlistCount() {
        XCTAssertEqual(Policy.maxWatchlistCount, 20)
    }
}
