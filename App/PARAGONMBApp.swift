import SwiftUI

/// SwiftUI App 진입점 + AppKit 셸 연결(K9). 메뉴바 상주 앱이라 메인 윈도우는 없다 —
/// UI는 AppDelegate가 소유하는 NSStatusItem+NSPopover(StatusBarController)가 전담한다.
@main
struct PARAGONMBApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 메인 윈도우 없음. Settings 씬은 LSUIElement 앱이 윈도우 없이 살아 있도록 두는 표준 패턴.
        Settings { EmptyView() }
    }
}
