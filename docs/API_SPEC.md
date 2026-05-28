# API Spec — PARAGON-MB

> placeholder. 키움 REST API 연동 스펙. `/team-dev:architect-design` 단계에서 채움.

## 외부 API
- **키움 REST API** (openapi.kiwoom.com): OAuth 토큰 발급, 시세 조회, 계좌 잔고(보유종목·평가손익)
- **키움 WebSocket**: 실시간 체결/시세 구독
- (보조) KRX OpenAPI: 종목 마스터/지연 데이터 — 실시간 불가(T+1)

## 검증 결과 (2026-05-28, contract 가설 4~6)

> ⚠️ **출처 등급 = 2차(커뮤니티)**. 공식 포털(openapi.kiwoom.com)은 JS 렌더링으로 스펙 본문 미확보.
> 아래는 .NET 래퍼([dongbin300/KiwoomRestApi.Net](https://github.com/dongbin300/KiwoomRestApi.Net)) + 블로그(pabburi) 기준.
> **키 발급 후 실측 또는 공식 가이드로 확정 필요.**

| 항목 | 검증 결과 | 출처 | 상태 |
|---|---|---|---|
| WebSocket 동시 실시간 등록 | **~40종목 / 인스턴스당 WS 1연결** (한투 41개와 유사) | .NET 래퍼 | 🟡 공식 확인 필요 |
| 접근토큰 유효기간 | **24시간**, `POST /oauth2/token` @ api.kiwoom.com (`grant_type=client_credentials`) | .NET 래퍼·pabburi | 🟡 공식 확인 필요 |
| 토큰 갱신 | 동일 호출 재발급 → 앱에 만료 전 자동 재발급 로직 | .NET 래퍼 | 🟡 |
| 실시간 시세 별도 요금 | 공개 출처에 별도 과금 언급 없음 (표준 키로 실시간 체결 수신 가능해 보임) | 추론 | 🔴 미확인 |
| 모의 vs 실계좌 | 모의투자 환경 존재(`isMock`). 보유종목/평가손익은 **실계좌 필수**(모의=가짜 잔고) | .NET 래퍼 | 🟡 |

### 보유종목 구현 경로 (계좌 엔드포인트 — 2차 출처 메서드명)
- 예수금 / 추정자산 / **계좌평가잔고**(보유종목 평가) / 일별손익 → 보유 합산 평가손익 산출 가능.

### 제품/아키텍처 영향
- **실시간 ~40슬롯 한도**: 관심 + 보유 + 지수(코스피·코스닥)가 모두 슬롯 소비 → 합산 ~40 예산. `product-define`에서 "관심종목 최대 N개" 정책 + 화면 가시 종목만 구독하는 lazy-subscribe 설계 검토.
- **토큰 24h 자동 재발급** + 자격증명 Keychain 보관(평문 금지).
- 개발 전략: 첫 슬라이스(관심종목 시세)는 **모의 환경**, 보유종목 단계에서 실계좌 연결.
