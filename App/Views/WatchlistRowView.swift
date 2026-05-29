import SwiftUI
import PMCore

/// 단일 종목 행(M4). child — `Symbol`·`Quote`·장 상태만 받아 렌더하고 네트워크/토큰을 모른다(경계 계약).
/// 등락 표현 = 색 + 부호(+/−) + 심볼(▲▼) 3중 인코딩. 색·심볼·부호 매핑은 `PriceDirection` 단일 출처.
struct WatchlistRowView: View {
    let symbol: Symbol
    let quote: Quote?
    let isClosed: Bool          // 장 외(장전·장마감) — 종가 배지 + 0.75 불투명도
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var highlightOpacity: Double = 0

    private var direction: PriceDirection { quote?.direction ?? .flat }

    var body: some View {
        HStack(spacing: 6) {
            Text(symbol.name)
                .font(PMFont.name)
                .foregroundStyle(PMColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isClosed {
                Text("종가")
                    .font(PMFont.caption)
                    .foregroundStyle(PMColor.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(PMColor.hover)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(PMColor.borderMuted))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            priceColumn
            changeColumn
            deleteButton
        }
        .padding(.horizontal, PMSpace.panelX)
        .padding(.vertical, PMSpace.rowY)
        .frame(minHeight: 49)
        .background(rowBackground)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(PMColor.borderMuted), alignment: .bottom)
        .opacity(isClosed ? 0.75 : 1)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onChange(of: quote) { newValue in flashHighlight(for: newValue) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel)
        .accessibilityAction(named: "삭제") { onDelete() }
    }

    // 현재가 — 등락 방향색(보합은 주 텍스트). §6.2 오너 오버라이드.
    private var priceColumn: some View {
        Text(quote.map { PMFormat.price($0.price) } ?? "—")
            .font(PMFont.price)
            .foregroundStyle(direction.priceColor)
            .frame(minWidth: 52, alignment: .trailing)
    }

    // 등락 2단 스택(우측 정렬): 상단 등락률 / 하단 방향심볼+등락액.
    private var changeColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let quote {
                Text(PMFormat.pct(quote.changeRate, quote.direction))
                    .font(PMFont.changePct)
                Text(amountLine(quote))
                    .font(PMFont.changeAmt)
            } else {
                Text(" ").font(PMFont.changePct)
            }
        }
        .foregroundStyle(direction.displayColor)
        .frame(minWidth: 72, alignment: .trailing)
        .padding(.vertical, 4)
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Text("\u{00D7}")              // ×
                .font(PMFont.name)
                .foregroundStyle(isHovering ? PMColor.dataUpText : PMColor.textSecondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .frame(width: isHovering ? 20 : 0)
        .opacity(isHovering ? 1 : 0)
        .clipped()
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .accessibilityHidden(true)        // 행 accessibilityAction("삭제")이 대체
        .help("삭제")
    }

    @ViewBuilder
    private var rowBackground: some View {
        ZStack {
            (isHovering ? PMColor.hover : Color.clear)
            (direction == .down ? PMColor.highlightDown : PMColor.highlightUp)
                .opacity(highlightOpacity)
        }
    }

    /// 보합은 부호·심볼 없이 "0", 상승/하락은 "심볼 절대값".
    private func amountLine(_ quote: Quote) -> String {
        switch quote.direction {
        case .flat: return "0"
        case .up, .down: return "\(quote.direction.symbol) \(PMFormat.amountAbs(quote.change))"
        }
    }

    /// 실시간 갱신 시 0.3초 단방향 fade-out 하이라이트(§5, 깜빡임 금지). 장 외엔 갱신이 없어 발화 안 함.
    private func flashHighlight(for newValue: Quote?) {
        guard newValue != nil, !isClosed else { return }
        highlightOpacity = 1
        withAnimation(.easeOut(duration: PMMotion.highlightDuration)) { highlightOpacity = 0 }
    }

    // VoiceOver: 색·심볼로만 전달되는 방향을 텍스트로 중복 제공(Q20).
    private var voiceOverLabel: String {
        guard let quote else { return "\(symbol.name) \(symbol.code), 시세 불러오는 중" }
        let rate = String(format: "%.2f", abs(quote.changeRate))
        let amt = PMFormat.amountAbs(quote.change)
        return "\(symbol.name) \(symbol.code), 현재가 \(PMFormat.price(quote.price))원, \(quote.direction.spokenWord) \(rate)퍼센트 \(amt)원"
    }
}
