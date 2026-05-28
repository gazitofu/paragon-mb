# PARAGON-MB

한국 주식 확인용 macOS 메뉴바 앱 (개인용). 키움 REST API 실시간 시세 기반.

- 관심종목 실시간 시세 — **MVP 첫 슬라이스**
- 보유종목 + 합산 평가손익 (키움 계좌 잔고)
- 코스피/코스닥 지수
- 메뉴바 아이콘 → 클릭 시 팝오버 패널

## 스택
- Swift / SwiftUI (`MenuBarExtra`, macOS 13+)
- 키움 REST API (REST 조회 + WebSocket 실시간)

## 상태
초기 부트스트랩. 실제 구현은 PRD 작성(`/team-dev:product-define`) 이후.

## 문서
- 제품 논의·결정: Vault `appdev/PARAGON-MB/`
- 아키텍처·스펙: `docs/`
