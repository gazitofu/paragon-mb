import Foundation

/// 제품 정책 상수. 수치 하드의존 금지 — 한 곳에서만 정의(K6).
public enum Policy {
    /// 관심종목 최대 개수. KIS WS 동시 등록 한도(커뮤니티 41건 설, 2차 출처 🟡 — API_SPEC §미실측 잔여) 내
    /// 20개 동시구독은 라이브 검증됨(V-A 골든패스 2026-06-05). 한도가 달라지면 이 상수 한 줄만 수정.
    public static let maxWatchlistCount = 20
}
