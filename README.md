# PARAGON-MB

한국 주식 확인용 macOS 메뉴바 앱 (개인용). **표시명 = PARAGON**. 한국투자증권(KIS) Open API 실시간 시세 기반 (키움 → KIS 전환, 2026-06-05 완료).

- 관심종목 실시간 시세 — **MVP 첫 슬라이스 (구현 완료)**
- 보유종목 + 합산 평가손익 — 보류 (KIS 잔고 TR 재도출 후 재개)
- 코스피/코스닥 지수 — 후속
- 메뉴바 아이콘 → 클릭 시 320×360 팝오버 패널 (LSUIElement)

## 스택
- Swift / SwiftUI — AppKit `NSStatusItem`+`NSPopover` 셸 + `NSHostingController` (macOS 13+)
- KIS Open API (REST 초기값 + WebSocket 실시간 체결)
- 로컬 SwiftPM 패키지 `PMCore` + XcodeGen (`xcodegen generate` 후 빌드)

## 상태
watchlist-realtime 구현·라이브 검증 완료 (2026-06-05, KIS 골든패스 PASS). v0.1 릴리즈 준비.

## 문서
- 제품 논의·결정: Vault `appdev/PARAGON-MB/`
- 아키텍처·스펙: `docs/`
