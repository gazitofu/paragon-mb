# Operational Notes

에이전트들이 발견한 빌드/테스트/환경 관련 학습 사항. 최대 50항목.
형식: `- [{날짜}] {내용} ({에이전트명})`

## 빌드

## 테스트

## 환경

## 주의사항

- [2026-06-01] NWPath.Status를 직접 주입하는 테스트 패턴: NetworkPathReachability는 handleStatusUpdate(_:) 내부 메서드를 @testable import로 노출해 NWPathMonitor 실물 없이 결정론적 단위 테스트 가능. Swift 6 모드에서 @Sendable 클로저 내 var 캡처는 warning이나 Swift 5.9(Package.swift swift-tools-version:5.9)에서는 에러 아님. (developer)
- [2026-06-01] PARAGON-MBTests Xcode unit test 타겟: bundle.unit-test + BUNDLE_LOADER/TEST_HOST로 App 타겟 호스트 설정. CODE_SIGN_IDENTITY="-" + CODE_SIGNING_REQUIRED/ALLOWED=NO 플래그 없이도 xcodebuild test 성공(ad-hoc). XCTest dylib은 macOS 14.0 기준이라 macOS 13.0 배포 대상 지정 시 ld warning 발생하나 테스트 실행에는 무해. (developer)
- [2026-06-01] PARAGON-MBTests Info.plist 필수: bundle.unit-test 타입은 xcodegen이 Info.plist를 자동 생성하지 않음. project.yml settings.base에 GENERATE_INFOPLIST_FILE: YES를 명시하지 않으면 "Cannot code sign because the target does not have an Info.plist file" 에러로 빌드 실패. (developer)
