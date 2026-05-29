import SwiftUI
import PMCore

/// 팝오버 패널 루트(P0). 헤더(고정) + 뷰 라우팅(V1/V2/V3) + 삭제 토스트 오버레이.
/// 라우팅: addViewModel 있으면 V3, 없고 empty면 V1, 그 외 V2. 화면 상태 소유는 WatchlistViewModel(M2).
struct PanelRootView: View {
    @ObservedObject var viewModel: WatchlistViewModel

    var body: some View {
        VStack(spacing: 0) {
            MarketStatusHeader(viewModel: viewModel)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: PMSpace.panelWidth, height: 360)
        .background(PMColor.panel)
        .overlay(alignment: .bottom) { toastOverlay }
        .animation(.easeInOut(duration: PMMotion.viewTransition), value: viewModel.state)
        .animation(.easeInOut(duration: PMMotion.viewTransition), value: viewModel.addViewModel == nil)
    }

    @ViewBuilder
    private var content: some View {
        if let addViewModel = viewModel.addViewModel {
            AddSymbolView(viewModel: addViewModel)
                .transition(.opacity)
        } else if viewModel.state == .empty {
            EmptyStateView(onAdd: { viewModel.presentAddSymbol() })
                .transition(.opacity)
        } else {
            WatchlistView(viewModel: viewModel)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = viewModel.undoToast {
            DeleteToast(onUndo: { viewModel.undoLastDelete() })
                .padding(.horizontal, PMSpace.panelX)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: toast.id) {
                    try? await Task.sleep(nanoseconds: UInt64(PMMotion.toastAutoDismiss * 1_000_000_000))
                    viewModel.dismissUndoToast()
                }
        }
    }
}
