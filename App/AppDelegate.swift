import AppKit

/// AppKit 셸 생명주기 연결점(K9). `applicationDidFinishLaunching`에서 메뉴바 셸을 구성한다.
/// Phase A: 부트스트랩 검증용 최소 구현 — StatusBarController·조립 루트는 Phase B/C에서 채운다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Phase B: StatusBarController 생성·보유.
    }
}
