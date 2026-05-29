# API Spec — PARAGON-MB

> 갱신: 2026-05-28 (`/team-dev:architect-design`, 기능 `watchlist-realtime`).
> **출처 등급 주의**: 아래 엔드포인트·필드·프로토콜 상세는 공식 포털 본문 미확보로 대부분 2차 출처(🟡) 또는 미확인(🔴)이었다. **2026-05-29 실측으로 핵심 항목 확정** — 아래 §실측 확정이 SSOT이며 하단 🟡/🔴 추정 표를 갱신한다.

## ✅ 실측 확정 (2026-05-29 PoC)

키 발급 후 `tools/kiwoom-ws-poc.swift` + `tools/kiwoom-rest-lookup-poc.swift`로 실측. .NET 래퍼의 `mockapi.kiwoom.com`은 **outdated** — 정정.

| 항목 | 실측 확정값 | 비고 |
|---|---|---|
| REST baseURL | 실전 `https://api.kiwoom.com` / 모의 `https://api.kiwoom.com:9443` | 모의 구분은 토큰에 내재 |
| 토큰 발급 | `POST /oauth2/token` body `{grant_type:client_credentials, appkey, secretkey}` → `{token, expires_dt, return_code}` | `expires_dt` = KST `yyyyMMddHHmmss`, 24h |
| WS | `wss://api.kiwoom.com:10000/api/dostk/websocket` (실전·모의 공통) | LOGIN→REG(`grp_no`/`refresh`/`data[item,type=0B]`)→PING echo→REAL |
| WS 0B FID | 10 현재가(부호=방향·abs) / 11 전일대비(부호) / 12 등락률% / 13 누적거래량 / 15 체결량 / 16·17·18 시·고·저 / 20 체결시각 / 27·28 최우선 매도·매수호가 | 가격 **원 단위, 스케일 없음**(사용자 확인 2026-05-29) |
| 종목조회 | `POST /api/dostk/stkinfo` header `api-id: ka10001` + `authorization: Bearer {token}`, body `{stk_cd}` | 응답 `stk_nm`·`cur_prc`(부호)·`base_pric`(전일종가)·`pred_pre`·`flu_rt`(%) |
| **Premise #1** 표준 키 WS 체결 수신 | **✅ TRUE** — 005930 실시간 0B 수신 | 별도 신청·요금 없이 수신 확인 |
| 부호·스케일 잠금 | `KiwoomQuoteParser`(parseRealtimeExecution·parseStockInfo) + `QuoteParsingTests` | price=abs · change 부호 보존 · prevClose=base_pric(REST) 또는 price−change(WS) |

> ⏳ 미실측 잔여: Premise #2(모의환경 실시간), #3(슬롯 한도), WS 구독해제(REMOVE) 정확 동작 — 모의 토큰·다종목 구독 시 추가 확인.

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

## watchlist-realtime 연동 스펙 (2026-05-28, architect-design)

> 아래는 본 기능 구현이 의존하는 호출 윤곽이다. 경로·필드명·페이로드 키는 2차 출처 추정이므로 **🟡/🔴 등급을 유지**한다. 실측 PoC에서 실제 값으로 교정한다.

### 인증 — 토큰 발급/재발급

| 항목 | 추정 스펙 | 출처 | 상태 |
|---|---|---|---|
| 엔드포인트 | `POST https://api.kiwoom.com/oauth2/token` (모의: 모의 baseURL) | .NET 래퍼·pabburi | 🟡 |
| 요청 | `grant_type=client_credentials`, `appkey`, `secretkey`(또는 `appsecret`) | .NET 래퍼 | 🟡 필드명 확인 필요 |
| 응답 | access token + 만료(24h 추정) | .NET 래퍼 | 🟡 |
| 재발급 | 동일 호출 재발급. 앱은 만료 임박 또는 401 시 갱신 | 추론 | 🟡 |

- 앱 측 흐름: `TokenManager`(actor)가 토큰 1개 + 만료 시각 보유 → 모든 REST/WS 호출 전 유효 토큰 주입 → 만료 임박/401 시 재발급. 재발급 실패는 사용자 가시 에러로 표면화(앱 재시작 안내, v1).
- 자격증명은 Keychain에서 로드. 평문 파일 금지.

### 종목 조회 (등록 시 종목명·초기 시세)

| 항목 | 추정 스펙 | 출처 | 상태 |
|---|---|---|---|
| 용도 | 종목코드(6자리) → 종목명 + 초기 현재가·전일종가·등락 | — | 🔴 정확한 엔드포인트 미확인 |
| 추정 경로 | 키움 REST 시세/종목정보 계열(예: 주식기본정보·현재가). 정확한 path·요청 헤더(`api-id`/`tr_id` 류)·응답 키 미확인 | .NET 래퍼 추론 | 🔴 |
| 실패 케이스 | 미존재 코드 → 등록 실패 안내 / 네트워크 오류 → 재시도 | — | 구현 처리 |

- **확정 필요**: 종목 조회 엔드포인트의 정확한 path·tr 식별자·응답 필드(종목명, 현재가, 전일종가, 등락액, 등락률 키). 실측 전까지 `KiwoomRESTClient`는 응답 파싱을 격리된 디코딩 함수로 두어 실제 키 확정 시 한 곳만 수정.

### 실시간 체결 구독 (WebSocket)

| 항목 | 추정 스펙 | 출처 | 상태 |
|---|---|---|---|
| 프로토콜 | WSS 단일 연결, 종목코드 set 구독 등록/해제 메시지 | .NET 래퍼 | 🔴 메시지 포맷 미확인 |
| 동시 등록 한도 | ~40종목 / WS 1연결(추정) | .NET 래퍼 | 🟡 |
| 수신 페이로드 | 체결 단위 현재가·등락·체결시각. **필드명·스케일(원 단위/호가 단위)·부호 규칙 미확인** | 추론 | 🔴 |
| 별도 신청/요금 | 표준 키로 수신 가능 여부 — **미확인(Premise #1)** | 추론 | 🔴 |
| 모의환경 수신 | 모의에서 실시간 체결 수신 가능 여부 — **미확인(Premise #2)** | 추론 | 🔴 |

- **부호·스케일 주의**(Sprint Execution Rules §Units & signs): WS 페이로드의 현재가·등락액 단위(원), 등락률(% vs 소수), 등락 부호 규칙은 실측으로 확정하고 `QuoteParsingTests`로 잠근다. PASS 전 Units & Signs Audit 필수.
- 앱 측: `KiwoomWebSocketClient`가 종목코드 set 구독/해제·재연결(지수 백오프)·끊김 이벤트 emit. 슬롯 예산 추상화는 두지 않음(하이브리드 경계 — architecture.md).

### 미해결 (sprint 전 실측 대상)

- **Premise #1 (🔴 최대 리스크)**: 표준 키 WS 체결 수신 가능 여부. **키 발급 직후 PoC 1건 필수.**
- Premise #2 (모의환경 실시간), #3 (슬롯 한도), #6 (토큰 24h 재발급) — 동일 PoC에서 검증.
- 종목 조회·WS 메시지의 정확한 경로·필드·스케일 — 실측으로 교정 전까지 🔴/🟡 유지.
