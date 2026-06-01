import XCTest
import Network
@testable import PMCore

/// T-NW1: 최초 satisfied 시 onRecovered 콜백 0회.
/// T-NW2: satisfied → unsatisfied → satisfied 시 콜백 정확히 1회.
/// design.md §상태·이벤트 계약 경계 계약, V10 검증 기준.
final class NetworkPathReachabilityTests: XCTestCase {

    // === SECTION: T-NW1 ===

    /// T-NW1: 최초 satisfied — 복구 콜백 0회.
    /// 앱 기동 직후 정상 네트워크 상태에서 자동 refresh가 튀면 안 됨(R1 오발화 방지).
    func testInitialSatisfiedDoesNotFireRecovery() {
        let reachability = NetworkPathReachability()
        var callCount = 0
        reachability.onRecovered { callCount += 1 }

        // 첫 상태 관측: satisfied (최초 관측이므로 발화 금지)
        reachability.handleStatusUpdate(.satisfied)

        XCTAssertEqual(callCount, 0, "최초 satisfied는 복구 콜백을 발화하면 안 됨 (T-NW1)")
    }

    /// T-NW1 확장: satisfied 연속 두 번 — 여전히 0회.
    func testConsecutiveSatisfiedDoesNotFireRecovery() {
        let reachability = NetworkPathReachability()
        var callCount = 0
        reachability.onRecovered { callCount += 1 }

        reachability.handleStatusUpdate(.satisfied)
        reachability.handleStatusUpdate(.satisfied)

        XCTAssertEqual(callCount, 0, "satisfied → satisfied는 복구 콜백 발화 없음")
    }

    // === SECTION: T-NW2 ===

    /// T-NW2: unsatisfied → satisfied 전이 — 콜백 정확히 1회.
    /// design.md 시나리오: [satisfied, unsatisfied, satisfied] → 콜백 1회.
    func testUnsatisfiedToSatisfiedFiresExactlyOnce() {
        let reachability = NetworkPathReachability()
        var callCount = 0
        reachability.onRecovered { callCount += 1 }

        // 앱 기동 후 최초 satisfied (0회)
        reachability.handleStatusUpdate(.satisfied)
        // 끊김
        reachability.handleStatusUpdate(.unsatisfied)
        // 복구 (1회 발화 기대)
        reachability.handleStatusUpdate(.satisfied)

        XCTAssertEqual(callCount, 1, "unsatisfied → satisfied 전이 시 복구 콜백 정확히 1회 (T-NW2)")
    }

    /// T-NW2 확장: requiresConnection → satisfied 도 복구로 간주.
    func testRequiresConnectionToSatisfiedFiresOnce() {
        let reachability = NetworkPathReachability()
        var callCount = 0
        reachability.onRecovered { callCount += 1 }

        // 최초 관측 = requiresConnection (발화 금지)
        reachability.handleStatusUpdate(.requiresConnection)
        // 복구 전이
        reachability.handleStatusUpdate(.satisfied)

        XCTAssertEqual(callCount, 1, "requiresConnection → satisfied 도 복구 콜백 1회")
    }

    /// T-NW2 확장: 복구 후 재끊김 + 재복구 — 2회.
    func testMultipleRecoveryCycles() {
        let reachability = NetworkPathReachability()
        var callCount = 0
        reachability.onRecovered { callCount += 1 }

        reachability.handleStatusUpdate(.satisfied)   // 최초, 0
        reachability.handleStatusUpdate(.unsatisfied) // 끊김
        reachability.handleStatusUpdate(.satisfied)   // 복구 1
        reachability.handleStatusUpdate(.unsatisfied) // 재끊김
        reachability.handleStatusUpdate(.satisfied)   // 복구 2

        XCTAssertEqual(callCount, 2, "복구 사이클 2회 → 콜백 2회")
    }

    // === SECTION: EDGE ===

    /// 핸들러 미등록 시 크래시 없음.
    func testNoHandlerRegistered() {
        let reachability = NetworkPathReachability()
        reachability.handleStatusUpdate(.satisfied)
        reachability.handleStatusUpdate(.unsatisfied)
        reachability.handleStatusUpdate(.satisfied)
        // 크래시 없으면 PASS
    }

    /// satisfied → unsatisfied 전이는 발화하지 않음.
    func testSatisfiedToUnsatisfiedDoesNotFire() {
        let reachability = NetworkPathReachability()
        var callCount = 0
        reachability.onRecovered { callCount += 1 }

        reachability.handleStatusUpdate(.satisfied)
        reachability.handleStatusUpdate(.unsatisfied)

        XCTAssertEqual(callCount, 0, "satisfied → unsatisfied는 복구 콜백 발화 없음")
    }
}
