import Foundation

/// 제품 정책 상수. 수치 하드의존 금지 — 한 곳에서만 정의(K6).
public enum Policy {
    /// 관심종목 최대 개수. Premise #3(키움 WS ~40슬롯, 2차 출처 🟡) 미검증 →
    /// 실측으로 한도가 달라지면 이 상수 한 줄만 수정. 현재 40슬롯의 절반을 관심종목에 배정.
    public static let maxWatchlistCount = 20
}
