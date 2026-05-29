import SwiftUI
import PMCore

/// V2 목록 뷰 본문(M2). 헤더·토스트는 PanelRootView가 소유 — 본 뷰는 스크롤 목록/스켈레톤만 렌더.
/// loading(첫 시세 도착 전)엔 스켈레톤, 그 외엔 행 목록. 행은 quotes/marketStatus를 주입받는다.
struct WatchlistView: View {
    @ObservedObject var viewModel: WatchlistViewModel

    private var showSkeleton: Bool {
        viewModel.state == .loading && viewModel.quotes.isEmpty
    }

    var body: some View {
        if showSkeleton {
            VStack(spacing: 0) {
                ForEach(0..<max(viewModel.symbols.count, 1), id: \.self) { _ in
                    SkeletonRow()
                }
                Spacer(minLength: 0)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.symbols) { symbol in
                        WatchlistRowView(
                            symbol: symbol,
                            quote: viewModel.quotes[symbol.code],
                            isClosed: !viewModel.marketStatus.isLive,
                            onDelete: { viewModel.remove(symbol) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 스켈레톤 (W2 loading — shimmer pulse, period ≈1.6s)

private struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 8) {
            SkeletonBlock().frame(maxWidth: .infinity).frame(height: 11)
            SkeletonBlock().frame(width: 52, height: 11)
            SkeletonBlock().frame(width: 64, height: 37)
        }
        .padding(.horizontal, PMSpace.panelX)
        .padding(.vertical, PMSpace.rowY)
        .frame(minHeight: 49)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(PMColor.borderMuted), alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel("시세 불러오는 중")
    }
}

private struct SkeletonBlock: View {
    @State private var pulse = false
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(PMColor.skeletonBase)
            .opacity(pulse ? 1.0 : 0.45)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

// MARK: - 삭제 토스트 (PanelRootView 오버레이에서 사용 — 빈 상태 전환 후에도 되돌리기 가능)

struct DeleteToast: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("삭제됨")
                .font(PMFont.price)
                .foregroundStyle(PMColor.textPrimary)
            Spacer(minLength: 0)
            Button("되돌리기", action: onUndo)
                .font(PMFont.price.weight(.medium))
                .foregroundStyle(PMColor.sapphire)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PMColor.hover)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(PMColor.border))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
    }
}
