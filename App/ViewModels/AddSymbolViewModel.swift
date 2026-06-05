import Foundation
import PMCore

/// 종목 등록 lookup 실패 분류(M1 경계 — child는 REST/token 세부를 모른다).
/// 조립 루트가 `KISRESTClient.RESTError` → 본 enum으로 매핑해 주입한다.
enum SymbolLookupError: Error {
    case invalidCode   // 미존재/유효하지 않은 종목코드
    case network       // 네트워크/토큰 등 일시 실패
}

/// V3 종목 등록 화면 상태 소유(M1). child — 한도·중복 **선검사** 후 주입된 lookup만 호출하고,
/// 성공 시 `onRegister(Symbol)`을 emit(영속·구독은 parent 책임), 취소 시 `onCancel`.
/// REST client·token은 직접 생성하지 않고 parent가 `lookup` 클로저로 주입(M1 경계 계약).
@MainActor
final class AddSymbolViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published var codeInput: String = ""

    private let existing: [Symbol]
    private let lookup: @Sendable (String) async throws -> Symbol
    private let onRegister: (Symbol) -> Void
    private let onCancel: () -> Void

    init(existing: [Symbol],
         lookup: @escaping @Sendable (String) async throws -> Symbol,
         onRegister: @escaping (Symbol) -> Void,
         onCancel: @escaping () -> Void) {
        self.existing = existing
        self.lookup = lookup
        self.onRegister = onRegister
        self.onCancel = onCancel
    }

    /// 등록 시도(버튼 또는 Return). 한도→중복→형식 순 선검사 후 lookup(M1 idle/loading 행).
    func submit() {
        guard phase != .loading else { return }
        let code = codeInput.trimmingCharacters(in: .whitespaces)

        if existing.count >= Policy.maxWatchlistCount {
            phase = .error("관심종목은 최대 \(Policy.maxWatchlistCount)개까지 등록할 수 있습니다")
            return
        }
        if existing.contains(where: { $0.code == code }) {
            phase = .error("이미 등록된 종목입니다")
            return
        }
        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            phase = .error("등록할 수 없는 종목코드입니다")
            return
        }

        phase = .loading
        Task { [weak self] in
            guard let self else { return }
            do {
                let symbol = try await self.lookup(code)
                self.onRegister(symbol)          // parent: Store.save + 구독 갱신(M1 loading→성공)
            } catch SymbolLookupError.invalidCode {
                self.phase = .error("등록할 수 없는 종목코드입니다")
            } catch {
                self.phase = .error("네트워크 연결을 확인해 주세요")
            }
        }
    }

    /// Escape/취소 — 입력 폐기, 복귀 뷰는 parent가 결정(M1: P-nav).
    func cancel() {
        onCancel()
    }
}
