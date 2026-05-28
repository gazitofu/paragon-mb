# API Spec — PARAGON-MB

> placeholder. 키움 REST API 연동 스펙. `/team-dev:architect-design` 단계에서 채움.

## 외부 API
- **키움 REST API** (openapi.kiwoom.com): OAuth 토큰 발급, 시세 조회, 계좌 잔고(보유종목·평가손익)
- **키움 WebSocket**: 실시간 체결/시세 구독
- (보조) KRX OpenAPI: 종목 마스터/지연 데이터 — 실시간 불가(T+1)

## 검증 필요 (contract 가설 4~6)
- WebSocket 동시 실시간 등록 종목 수 한도
- 토큰 만료/자동 갱신 정책
- 실시간 시세 별도 신청 필요 여부
- 모의투자 vs 실계좌 응답 차이
