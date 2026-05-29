import Foundation

/// 현재 시각 → 장 상태 판별(K5 — 순수 함수, 외부 호출 0 → 결정적 테스트 100%).
/// 정규장 09:00–15:30 KST(점심 연속거래·휴장 없음), 주말·공휴일은 장마감.
public struct MarketClock {
    /// KRX 휴장일 (KST "yyyy-MM-dd"). ⚠️ 음력 연동 휴일·대체공휴일은 매년 갱신 필요 — 사용자 검증 대상.
    public let holidays: Set<String>

    private let openMinutes = 9 * 60          // 09:00 = 540
    private let closeMinutes = 15 * 60 + 30   // 15:30 = 930

    public static let kst = TimeZone(identifier: "Asia/Seoul")!

    public static var kstCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = kst
        return c
    }

    public init(holidays: Set<String> = MarketClock.defaultHolidays2026) {
        self.holidays = holidays
    }

    /// 경계: 09:00 정각 = 장중, 15:30 정각 = 장마감(종가 단일가 종료).
    public func status(at date: Date, calendar: Calendar = MarketClock.kstCalendar) -> MarketStatus {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: date)
        // 주말 (Gregorian: 1=일요일, 7=토요일)
        if c.weekday == 1 || c.weekday == 7 { return .closed }
        // 공휴일
        if holidays.contains(Self.dateKey(c)) { return .closed }
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if minutes < openMinutes { return .preMarket }
        if minutes >= closeMinutes { return .closed }
        return .open
    }

    private static func dateKey(_ c: DateComponents) -> String {
        String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 2026 KRX 휴장일 시드 (best-effort — ⚠️ 사용자 연 1회 검증·확정 필요).
    /// 음력(설날·추석)·대체공휴일은 정확도 확보 전까지 비워둔다(틀린 날짜 배제 — 글로벌 §2 grounding).
    public static let defaultHolidays2026: Set<String> = [
        "2026-01-01", // 신정
        "2026-12-25", // 성탄절
        "2026-12-31", // 연말 폐장일(KRX 휴장)
    ]
}
