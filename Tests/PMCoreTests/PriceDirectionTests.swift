import XCTest
@testable import PMCore

/// T-direction: 상승/하락/보합 부호·심볼 매핑 + Quote 파생(부호·스케일) 잠금(M4).
final class PriceDirectionTests: XCTestCase {

    func testDirectionFromChange() {
        XCTAssertEqual(PriceDirection(change: 1500), .up)
        XCTAssertEqual(PriceDirection(change: -650), .down)
        XCTAssertEqual(PriceDirection(change: 0), .flat)
    }

    func testSymbolMapping() {
        XCTAssertEqual(PriceDirection.up.symbol, "▲")
        XCTAssertEqual(PriceDirection.down.symbol, "▼")
        XCTAssertEqual(PriceDirection.flat.symbol, "-")
    }

    func testSignPrefix() {
        XCTAssertEqual(PriceDirection.up.signPrefix, "+")
        // 하락 부호는 U+2212 MINUS SIGN — ASCII 하이픈("-")이 아님.
        XCTAssertEqual(PriceDirection.down.signPrefix, "\u{2212}")
        XCTAssertNotEqual(PriceDirection.down.signPrefix, "-")
        XCTAssertEqual(PriceDirection.flat.signPrefix, "")
    }

    // Quote 파생: 부호·스케일 단일 출처 검증(실측 PoC 005930 값 기준).
    func testQuoteDerivationUp() {
        let q = Quote(price: 310_500, previousClose: 299_500)
        XCTAssertEqual(q.change, 11_000)              // 등락액 = 현재가 − 전일종가
        XCTAssertEqual(q.changeRate, 3.6728, accuracy: 0.0001)  // % (≈ +3.67)
        XCTAssertEqual(q.direction, .up)
    }

    func testQuoteDerivationDown() {
        let q = Quote(price: 73_700, previousClose: 74_350)
        XCTAssertEqual(q.change, -650)
        XCTAssertEqual(q.changeRate, -0.8742, accuracy: 0.0001)
        XCTAssertEqual(q.direction, .down)
    }

    func testQuoteDerivationFlat() {
        let q = Quote(price: 50_000, previousClose: 50_000)
        XCTAssertEqual(q.change, 0)
        XCTAssertEqual(q.changeRate, 0)
        XCTAssertEqual(q.direction, .flat)
    }

    func testQuoteZeroPreviousCloseNoCrash() {
        let q = Quote(price: 1_000, previousClose: 0)
        XCTAssertEqual(q.changeRate, 0)  // 0 나눗셈 방지
    }
}
