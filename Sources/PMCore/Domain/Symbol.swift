import Foundation

/// 관심종목 식별 모델. 영속 대상(코드+이름)이며 시세는 포함하지 않는다(K4: 시세 비영속).
public struct Symbol: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let code: String   // 6자리 종목코드 (예: "005930")
    public let name: String   // 종목명 (REST 조회로 채움)

    public var id: String { code }

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}
