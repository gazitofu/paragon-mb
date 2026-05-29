import AppKit
import SwiftUI

/// 메뉴바 셸(K9). `NSStatusItem` + `NSPopover`(`.transient`)를 소유하고
/// 좌클릭=팝오버 토글 / 우클릭=컨텍스트 메뉴(설정·종료)로 분기한다.
/// 팝오버 콘텐츠는 `NSHostingController`로 SwiftUI 패널을 호스팅한다.
/// Phase B: 패널은 placeholder. 실 PanelRootView(task 23)는 Phase D에서 주입한다.
@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let viewModel: WatchlistViewModel   // 조립 루트 주입 — 렌더는 Phase D(PanelRootView)에서

    init(viewModel: WatchlistViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover = NSPopover()
        popover.behavior = .transient                                   // 바깥 클릭 시 자동 닫힘
        popover.contentSize = NSSize(width: 320, height: 360)           // 권장 폭 320pt (design §팝오버 크기)
        popover.contentViewController = NSHostingController(rootView: PlaceholderPanelView())

        if let button = statusItem.button {
            let icon = Self.gemIcon()
            icon.accessibilityDescription = "PARAGON"
            button.image = icon
            button.target = self
            button.action = #selector(handleButtonAction)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])       // 좌/우 클릭 모두 action으로
        }
    }

    /// 4면 명도 보석 아이콘(design-language §2.5). 다이아몬드를 중심에서 대각선으로
    /// 4개 삼각형 분할, 좌상단 수광(TL 최명·BR 최암). 워드마크 컬러 보석과 동일 비율(10:14).
    /// 비-template — 4면 명도를 살리기 위함(template이면 단색 알파마스크로 평탄화됨, A안 다크 튜닝 고정).
    private static func gemIcon() -> NSImage {
        let h: CGFloat = 16
        let w: CGFloat = h * (10.0 / 14.0)
        let image = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            let top    = NSPoint(x: w / 2, y: h)        // AppKit 좌표(y 위로 증가)
            let right  = NSPoint(x: w,     y: h / 2)
            let bottom = NSPoint(x: w / 2, y: 0)
            let left   = NSPoint(x: 0,     y: h / 2)
            let center = NSPoint(x: w / 2, y: h / 2)

            func facet(_ a: NSPoint, _ b: NSPoint, gray: CGFloat) {
                let path = NSBezierPath()
                path.move(to: a)
                path.line(to: b)
                path.line(to: center)
                path.close()
                NSColor(white: gray, alpha: 1).setFill()
                path.fill()
            }
            facet(top,   left,   gray: 1.0)             // TL #FFFFFF
            facet(top,   right,  gray: 224.0 / 255.0)   // TR #E0E0E0
            facet(left,  bottom, gray: 184.0 / 255.0)   // BL #B8B8B8
            facet(right, bottom, gray: 138.0 / 255.0)   // BR #8A8A8A
            return true
        }
        image.isTemplate = false
        return image
    }

    @objc private func handleButtonAction() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "설정…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "PARAGON 종료", action: #selector(quit), keyEquivalent: "q").target = self

        statusItem.menu = menu                  // 메뉴 일시 부착 → 클릭 시 표시
        statusItem.button?.performClick(nil)
        statusItem.menu = nil                   // 좌클릭 토글 동작 복원
    }

    @objc private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Phase B placeholder — 실 패널(PanelRootView, task 23)은 Phase D에서 교체.
private struct PlaceholderPanelView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "diamond.fill")
                .font(.title2)
            Text("PARAGON")
                .font(.headline)
            Text("패널 준비 중")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
