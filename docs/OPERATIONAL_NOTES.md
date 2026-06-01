# Operational Notes

에이전트들이 발견한 빌드/테스트/환경 관련 학습 사항. 최대 50항목.
형식: `- [{날짜}] {내용} ({에이전트명})`

## 빌드

## 테스트

## 환경

## 주의사항

- [2026-06-01] NWPath.Status를 직접 주입하는 테스트 패턴: NetworkPathReachability는 handleStatusUpdate(_:) 내부 메서드를 @testable import로 노출해 NWPathMonitor 실물 없이 결정론적 단위 테스트 가능. Swift 6 모드에서 @Sendable 클로저 내 var 캡처는 warning이나 Swift 5.9(Package.swift swift-tools-version:5.9)에서는 에러 아님. (developer)
