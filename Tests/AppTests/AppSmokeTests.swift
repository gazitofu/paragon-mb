import XCTest
@testable import PARAGON_MB

// App 타겟 @testable import 가능 여부 확인용 스모크 테스트.
// WatchlistViewModel.ScreenState 심볼 접근으로 테스트 파이프라인이 App 타겟에 실제로 연결됨을 입증.
final class AppSmokeTests: XCTestCase {
    func testScreenStateAccessible() {
        let state = WatchlistViewModel.ScreenState.empty
        XCTAssertEqual(state, .empty)
    }
}
