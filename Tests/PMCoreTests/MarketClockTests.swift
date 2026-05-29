import XCTest
@testable import PMCore

/// T-clock-pre/open/close, T-holiday: 장 상태 경계·주말·공휴일 잠금(M3·K5).
final class MarketClockTests: XCTestCase {

    private func kst(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        c.timeZone = MarketClock.kst
        return MarketClock.kstCalendar.date(from: c)!
    }

    // 2026-05-29 = 금요일(평일)
    func testPreMarketBeforeOpen() {
        let clock = MarketClock(holidays: [])
        XCTAssertEqual(clock.status(at: kst(2026, 5, 29, 8, 59)), .preMarket)
        XCTAssertEqual(clock.status(at: kst(2026, 5, 29, 0, 0)), .preMarket)
    }

    func testOpenBoundaries() {
        let clock = MarketClock(holidays: [])
        XCTAssertEqual(clock.status(at: kst(2026, 5, 29, 9, 0)), .open)   // 정각 개장
        XCTAssertEqual(clock.status(at: kst(2026, 5, 29, 12, 0)), .open)  // 점심 연속거래
        XCTAssertEqual(clock.status(at: kst(2026, 5, 29, 15, 29)), .open) // 마감 직전
    }

    func testClosedAfter1530() {
        let clock = MarketClock(holidays: [])
        XCTAssertEqual(clock.status(at: kst(2026, 5, 29, 15, 30)), .closed) // 정각 마감
        XCTAssertEqual(clock.status(at: kst(2026, 5, 29, 18, 0)), .closed)
    }

    func testWeekendClosed() {
        let clock = MarketClock(holidays: [])
        XCTAssertEqual(clock.status(at: kst(2026, 5, 30, 10, 0)), .closed) // 토요일
        XCTAssertEqual(clock.status(at: kst(2026, 5, 31, 10, 0)), .closed) // 일요일
    }

    func testHolidayClosed() {
        // 2026-06-03 = 수요일(평일). 휴일 주입 → 장중 시간이어도 장마감.
        let weekday = kst(2026, 6, 3, 10, 0)
        XCTAssertEqual(MarketClock(holidays: []).status(at: weekday), .open)
        XCTAssertEqual(MarketClock(holidays: ["2026-06-03"]).status(at: weekday), .closed)
    }

    func testDefaultHolidaySeedNewYear() {
        // 시드된 신정(2026-01-01 = 목요일·평일)은 장마감.
        XCTAssertEqual(MarketClock().status(at: kst(2026, 1, 1, 10, 0)), .closed)
    }
}
