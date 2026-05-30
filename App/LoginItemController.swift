import ServiceManagement

/// 로그인 시 자동 실행 등록 제어(SMAppService, macOS 13+).
///
/// 시스템 로그인 항목 상태가 SSOT — 별도 영속 bool을 두지 않는다(상태 드리프트 방지).
/// 사용자가 시스템 설정 > 로그인 항목에서 직접 끈 경우도 `status`가 즉시 반영한다.
/// 메인 앱 로그인 항목은 헬퍼 데몬과 달리 특별 entitlement가 불요하며 ad-hoc 서명에서도
/// 로컬 등록이 동작한다(decisions/2026-05-30-launch-at-login.md).
@MainActor
struct LoginItemController {
    /// 현재 로그인 항목 등록 여부(시스템 상태 직접 조회).
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 등록(`true`)/해제(`false`) 토글. 실패 시 throw — 호출처가 로깅하고
    /// 체크마크는 `isEnabled` 재조회로 거짓 ON을 방지한다.
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
