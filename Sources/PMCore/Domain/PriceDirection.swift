import Foundation

/// 등락 방향. 심볼·부호의 단일 출처(M4 경계 계약).
/// SwiftUI 비의존(순수) — 색(priceUp/down/neutral) 매핑은 App 레이어(DESIGN_SYSTEM)에서 한다.
public enum PriceDirection: Sendable {
    case up      // 상승 (전일대비 +)
    case down    // 하락 (전일대비 −)
    case flat    // 보합 (0)

    /// 등락액 부호로 방향 도출.
    public init(change: Int) {
        if change > 0 { self = .up }
        else if change < 0 { self = .down }
        else { self = .flat }
    }

    /// 방향 심볼 (색각이상 대응 — 색 외 인코딩).
    public var symbol: String {
        switch self {
        case .up: return "▲"
        case .down: return "▼"
        case .flat: return "-"
        }
    }

    /// 부호 접두. 하락은 U+2212 MINUS SIGN(하이픈 아님 — 정렬·가독성).
    public var signPrefix: String {
        switch self {
        case .up: return "+"
        case .down: return "\u{2212}"
        case .flat: return ""
        }
    }
}
