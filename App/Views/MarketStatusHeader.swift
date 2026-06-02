import SwiftUI
import PMCore

/// 패널 sticky 헤더(M3 + M2 연결/인증 인디케이터). 워드마크(좌) · 장상태 텍스트·배지·"+"(우) 1줄 +
/// 하단 인라인 경고/배너(ws-disconnected / auth-failed / network-error). 등록 모드에선 "종목 추가" 타이틀.
struct MarketStatusHeader: View {
    @ObservedObject var viewModel: WatchlistViewModel

    private var isAdding: Bool { viewModel.addViewModel != nil }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            if !isAdding, let banner = activeBanner {
                AlertBanner(kind: banner, onRetry: { viewModel.refresh() })
            }
        }
        .background(PMColor.header)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(PMColor.border), alignment: .bottom)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Wordmark()
            Spacer(minLength: 0)
            if isAdding {
                Text("종목 추가")
                    .font(PMFont.status)
                    .foregroundStyle(PMColor.textSecondary)
            } else {
                Text(statusText)
                    .font(PMFont.status)
                    .foregroundStyle(PMColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(viewModel.marketStatus == .closed ? "NXT·시간외 시세 미반영" : "")
                if let badge = activeBadge {
                    StatusBadge(kind: badge)
                }
                if !viewModel.symbols.isEmpty {
                    refreshButton
                }
                addButton
            }
        }
        .padding(.horizontal, PMSpace.panelX)
        .padding(.vertical, PMSpace.headerY)
    }

    private var refreshButton: some View {
        Button {
            viewModel.refresh()
        } label: {
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(PMColor.sapphire)
                    .frame(width: 22, height: 22)
            }
        }
        .buttonStyle(.plain)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(PMColor.border))
        .disabled(viewModel.isRefreshing)
        .accessibilityLabel(viewModel.isRefreshing ? "새로고침 중" : "새로고침")
        .keyboardShortcut("r", modifiers: .command)
    }

    private var addButton: some View {
        Button { viewModel.presentAddSymbol() } label: {
            Text("+")
                .font(PMFont.iconPlus)
                .foregroundStyle(PMColor.sapphire)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(PMColor.border))
        .accessibilityLabel("종목 추가")
    }

    // "장중 14:23:05 기준" / "정규장 마감 · 종가 기준" / "장전" (Phase C M3 copy 결정).
    private var statusText: String {
        switch viewModel.marketStatus {
        case .open:
            if let t = viewModel.lastUpdated { return "장중 \(Self.timeFormatter.string(from: t)) 기준" }
            return "장중"
        case .preMarket:
            return "장전"
        case .closed:
            return "정규장 마감 · 종가 기준"
        }
    }

    // 배지/배너 우선순위: 인증 실패 > 네트워크 실패 > WS 끊김.
    private var activeBadge: StatusBadge.Kind? {
        if viewModel.state == .authFailed { return .error }
        if viewModel.loadFailed { return .error }
        if viewModel.state == .wsDisconnected { return .warning }
        return nil
    }

    private var activeBanner: AlertBanner.Kind? {
        if viewModel.state == .authFailed { return .authFailed }
        if viewModel.loadFailed { return .networkError }
        if viewModel.state == .wsDisconnected { return .wsDisconnected }
        return nil
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

// MARK: - 워드마크 P◇RAGON (§2.1 — 첫 A를 컬러 보석으로 대체, 브랜드존 데이터색 금지)

private struct Wordmark: View {
    var body: some View {
        HStack(spacing: 0) {
            letter("P")
            GemMark(width: 10, height: 14).padding(.horizontal, 0.5)
            letter("R"); letter("A"); letter("G"); letter("O"); letter("N")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PARAGON")
    }

    private func letter(_ ch: String) -> some View {
        Text(ch)
            .font(PMFont.t2)
            .tracking(0.6)
            .foregroundStyle(PMColor.wordmark)
    }
}

// MARK: - 상태 배지 (헤더 우측 원형)

private struct StatusBadge: View {
    enum Kind { case warning, error }
    let kind: Kind

    var body: some View {
        Text(kind == .warning ? "\u{26A0}" : "!")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(kind == .warning ? PMColor.midnight : PMColor.pearl)
            .frame(width: 18, height: 18)
            .background(kind == .warning ? PMColor.badgeWarning : PMColor.badgeError)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - 인라인 경고/배너 (헤더 하단 full-width)

private struct AlertBanner: View {
    enum Kind { case wsDisconnected, authFailed, networkError }
    let kind: Kind
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(message)
                .font(PMFont.caption)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            if kind == .networkError {
                Button("다시 시도", action: onRetry)
                    .font(PMFont.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(textColor))
            }
        }
        .padding(.horizontal, PMSpace.panelX)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(PMColor.borderMuted), alignment: .bottom)
        .accessibilityElement(children: .combine)
    }

    private var message: String {
        switch kind {
        case .wsDisconnected: return "실시간 연결 끊김 — 재연결 중"
        case .authFailed: return "인증이 만료되었습니다 — 새로고침해 주세요"
        case .networkError: return "네트워크 연결을 확인해 주세요"
        }
    }

    private var textColor: Color {
        kind == .wsDisconnected ? PMColor.alertWarningText : PMColor.alertErrorText
    }

    private var backgroundColor: Color {
        kind == .wsDisconnected ? PMColor.alertWarningBg : PMColor.alertErrorBg
    }
}
