import AppKit

/// AppKit 셸 생명주기 연결점(K9). `applicationDidFinishLaunching`에서 메뉴바 셸을 구성한다.
/// Phase B: StatusBarController 생성·보유. ViewModel 조립 루트는 Phase C에서 채운다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }
}
