# Architecture — PARAGON-MB

> placeholder. `/team-dev:architect-design` 단계에서 채움.

## 개요
macOS 메뉴바 앱 (SwiftUI `MenuBarExtra`). 키움 REST API로 실시간 시세·계좌 조회. 조회 전용.

## 주요 컴포넌트 (TBD)
- 메뉴바 아이콘 + 팝오버 패널 UI 레이어
- 키움 인증·토큰 관리 (Keychain)
- REST 조회 + WebSocket 실시간 구독 레이어
- 관심종목·설정 로컬 저장
