import Foundation

/// 단일 종목의 시세 스냅샷. 휘발성 런타임 상태(K4 — 디스크 영속 안 함).
/// 등락액·등락률은 현재가와 전일종가에서 파생한다 — 부호·스케일 단일 출처(K8).
public struct Quote: Equatable, Sendable {
    public let price: Int           // 현재가 (원)
    public let previousClose: Int   // 전일 종가 (원)

    public init(price: Int, previousClose: Int) {
        self.price = price
        self.previousClose = previousClose
    }

    /// 등락액 (원). 부호 = 현재가 − 전일종가 (상승 +, 하락 −).
    public var change: Int { price - previousClose }

    /// 등락률 (%, 예: 3.67). 전일종가 0이면 0 (0 나눗셈 방지).
    public var changeRate: Double {
        guard previousClose != 0 else { return 0 }
        return Double(change) / Double(previousClose) * 100
    }

    /// 등락 방향 (상승/하락/보합) — 등락액 부호에서 파생.
    public var direction: PriceDirection { PriceDirection(change: change) }
}
