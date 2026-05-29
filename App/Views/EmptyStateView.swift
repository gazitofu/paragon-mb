import SwiftUI

/// V1 빈 상태(관심종목 0개). 보석 마크 + 안내 + 등록 CTA. 다음 행동을 명확히 제시.
struct EmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            GemMark(width: 18, height: 24)
                .frame(width: 36, height: 36)
                .background(PMColor.hover)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(PMColor.border, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("아직 등록된 종목이 없습니다")
                .font(PMFont.name)
                .foregroundStyle(PMColor.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Text("+ 종목 추가")
                    .font(PMFont.button)
                    .foregroundStyle(PMColor.primaryButtonText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(PMColor.primaryButtonBg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, PMSpace.panelX)
        .padding(.vertical, 32)
    }
}
