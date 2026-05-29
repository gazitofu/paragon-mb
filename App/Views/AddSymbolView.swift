import SwiftUI
import PMCore

/// V3 종목 등록 폼(M1). `AddSymbolViewModel` 상태만 구독·바인딩하고 등록/취소를 위임한다.
/// Return=등록 / Escape=취소. 한도·중복·형식 선검사 결과는 VM의 `phase`에서 인라인 에러로 표시.
struct AddSymbolView: View {
    @ObservedObject var viewModel: AddSymbolViewModel
    @FocusState private var focused: Bool

    private var isLoading: Bool { viewModel.phase == .loading }
    private var errorMessage: String? {
        if case let .error(msg) = viewModel.phase { return msg }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("종목코드")
                    .font(PMFont.caption)
                    .tracking(0.4)
                    .foregroundStyle(PMColor.textSecondary)

                TextField("예: 005930", text: $viewModel.codeInput)
                    .textFieldStyle(.plain)
                    .font(PMFont.input)
                    .foregroundStyle(PMColor.textPrimary)
                    .focused($focused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(PMColor.sunken)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(errorMessage != nil ? PMColor.dataUpText : (focused ? PMColor.sapphire : PMColor.border))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onChange(of: viewModel.codeInput) { newValue in
                        let filtered = String(newValue.filter(\.isNumber).prefix(6))
                        if filtered != newValue { viewModel.codeInput = filtered }
                    }
                    .onSubmit { viewModel.submit() }
                    .accessibilityLabel("종목코드 6자리 입력")

                if let errorMessage {
                    Text(errorMessage)
                        .font(PMFont.caption)
                        .foregroundStyle(PMColor.dataUpText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isStaticText)
                }
            }

            HStack(spacing: 8) {
                submitButton
                cancelButton
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, PMSpace.panelX)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { focused = true }
    }

    private var submitButton: some View {
        Button { viewModel.submit() } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .progressViewStyle(.circular)
                }
                Text("등록")
                    .font(PMFont.button)
            }
            .foregroundStyle(PMColor.primaryButtonText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(PMColor.primaryButtonBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(isLoading ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .keyboardShortcut(.defaultAction)        // Return
    }

    private var cancelButton: some View {
        Button { viewModel.cancel() } label: {
            Text("취소")
                .font(PMFont.button.weight(.regular))
                .foregroundStyle(PMColor.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(PMColor.border))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)         // Escape
    }
}
