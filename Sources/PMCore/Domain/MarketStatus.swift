import Foundation

/// 장 상태. MarketClock이 Date → 본 enum으로 판별(M3).
public enum MarketStatus: Equatable, Sendable {
    case preMarket   // 장전 (정규장 개시 전 평일)
    case open        // 장중 (정규장 시간)
    case closed      // 장마감 (정규장 종료 후·주말·공휴일)

    public var label: String {
        switch self {
        case .preMarket: return "장전"
        case .open: return "장중"
        case .closed: return "장마감"
        }
    }

    /// 실시간 갱신(WS 구독) 동작 여부 — 장중만 true(M3: 장 외 구독 차단).
    public var isLive: Bool { self == .open }
}
