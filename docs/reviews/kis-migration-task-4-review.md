# 코드 리뷰 리포트 — kis-migration Task 4: KISWebSocketClient

- 일자: 2026-06-04
- 대상 diff (이 태스크 한정):
  - `Sources/PMCore/Network/KISWebSocketClient.swift` (신규, 226줄)
  - `docs/OPERATIONAL_NOTES.md` (+1줄)
- 참고 대조: API_SPEC.md §H0STCNT0 / tools/kis-ws-poc.swift / KiwoomWebSocketClient.swift / KISQuoteParser.swift / QuoteService.swift / design.md §상태·이벤트 계약 행 1~6

## 전체 평가

PoC(`kis-ws-poc.swift`)의 검증된 흐름을 actor로 충실히 이식했다. raw `flag|tr_id|건수|본문` 분기, JSON 제어(PINGPONG/SUBSCRIBE) 분기, PINGPONG echo, 46×N 청킹 위임, per-record emit, 백오프 상한 30s, 재연결 시 재구독이 모두 정답지와 일치한다. **Event enum 시그니처는 KiwoomWebSocketClient와 case·라벨·타입까지 완전 동일**하여 QuoteService.handle(_:)이 Task 10에서 타입명 교체만으로 무수정 컴파일된다(계약 경계 PASS). 치명적 결함은 없다. 다만 developer가 보고한 리스크 3건 중 **#3(중복 .connected emit)은 실재하는 권장 수정 대상**이고, #1·#2는 설계 계약대로 구현된 것으로 위반이 아니다. 또한 design 검증 컬럼이 약속한 단위 테스트(T-ws-connect/T-ws-pingpong/T-parse)가 이 태스크 산출물에 없다.

---

## developer 보고 리스크 검증 결과

### 리스크 #1 — setSubscriptions diff마다 approvalKeyProvider 재호출 → 판정: 설계대로 (참고)
`setSubscriptions`는 added/removed 각각에 대해 `sendSubscribe`를 호출하고, 그 안에서 `approvalKeyProvider()`를 매번 호출한다(L107-112). design **결정 6**(design.md:174)과 코드 주석(L18)이 명시적으로 "호출마다 새 키 발급, 별도 제한 미관측 → 캐시 불요, connect마다 1콜"을 잠갔다. API_SPEC.md:20도 동일("호출마다 새 키 발급, 별도 제한 미관측"). 즉 키 캐시 책임은 **설계상 어디에도 없도록 결정**된 것이며 위반 아님. 다만 P7(WS 동시 등록 한도) 라이브 실측 시 다종목 구독에서 Approval REST 호출이 종목 수만큼 발생하므로, EGW00201류 초당 한도(REST는 600ms 스로틀 실측)와의 상호작용은 라이브에서 관찰 필요 — 아래 [참고] 항목으로 등록.

### 리스크 #2 — open() approval 실패가 scheduleReconnect로 삼켜짐 → 판정: 설계 계약대로, Event 위반 아님 (권장: 상위 가시화)
키움 대조 결과 `KiwoomWebSocketClient.open()`도 `tokenProvider()` 실패를 동일하게 `scheduleReconnect()`로 흡수한다(Kiwoom L63-72). **WS Event enum에는 양쪽 모두 `authFailed` case가 존재하지 않는다** — `authFailed`는 `QuoteService.QuoteUpdate.ServiceError.authFailed`로, **REST 토큰 경로**(QuoteService.loadInitial L87)에서만 emit된다. design.md 행 1(design.md:243)이 "approval_key 발급 실패 시 scheduleReconnect(지수 백오프), `.connected` 미발화"를 명시 계약으로 잠갔으므로, 코드의 흡수 동작은 **계약 위반이 아니라 계약 준수**다. case 누락 0건.
다만 developer 우려의 실체는 유효하다: WS approval_key 자격증명이 영구 손상된 경우 `.disconnected`조차 emit되지 않고(첫 open 실패는 `handleDisconnect`를 거치지 않음) 무한 백오프에 들어가며, REST 토큰이 캐시로 살아 있으면 `authFailed`도 안 뜬다 → **사용자에게 어떤 신호도 없는 무한 재시도**. 이는 Task 4 구현 결함이 아니라 **WS 계약의 설계 갭**이므로, architect/조립(Task 5) 단계에서 "WS approval 영구 실패 → 사용자 가시 신호" 경로를 다룰지 결정 필요. 아래 [권장]으로 기록.

### 리스크 #3 — SUBSCRIBE SUCCESS 판별 → 판정: 중복 .connected emit 실재 (권장)
`handleJSON`의 H0STCNT0 분기는 `rt_cd == "0"`마다 `.connected`를 yield한다(L182-184). 구독 envelope은 **종목당 1개씩** 전송되고(`sendSubscribeEnvelope` L92 for-loop), KIS는 각 구독에 대해 개별 SUBSCRIBE SUCCESS 응답을 보낸다. 따라서 **N종목 구독 시 .connected가 N회 emit**된다. QuoteService는 이를 `.connection(true)` N회로 승격하고, VM은 동일 상태 재진입이라 시각적 무해할 가능성이 높으나, design 행 1의 검증 기준 "approval 성공 시 `.connected` 1회"(design.md:243, T-ws-connect)와 **명백히 어긋난다**. 재연결마다 `reconnectAttempt = 0` 리셋도 N회 발생(무해하나 불필요). 멱등화 권장(아래).

---

## 발견된 이슈

### [권장] SUBSCRIBE SUCCESS 중복 .connected emit (멱등 아님)
- 위치: `KISWebSocketClient.swift:178-185` (`handleJSON` H0STCNT0 분기)
- 현재 동작: 종목당 구독 응답마다 `rt_cd=="0"` → `.connected` yield. N종목이면 N회.
- 문제: design.md:243 검증 기준("approval 성공 시 `.connected` 1회")과 불일치. T-ws-connect를 작성하면 N=1 단종목에선 통과하나 다종목에서 깨진다. 상위 QuoteService는 `.connection(true)`를 N회 받으며, 향후 connection 카운팅/토글 로직이 들어오면 회귀 위험.
- 수정 제안: 이미 연결 상태면 중복 emit 억제. 예) `private var didEmitConnected = false` 상태를 두고, `.connected`는 false→true 전이 시 1회만 yield, `handleDisconnect`에서 false로 리셋. (reconnectAttempt 리셋도 같은 전이 가드 안으로.)
  ```swift
  case "H0STCNT0":
      let body = json["body"] as? [String: Any]
      if (body?["rt_cd"] as? String) == "0", !didEmitConnected {
          didEmitConnected = true
          reconnectAttempt = 0
          emit.yield(.connected)
      }
  ```
  (단종목 현행 watchlist에선 즉시 영향 적으나, P7 다종목 실측 전에 잠그는 것이 안전.)

### [권장] WS approval_key 영구 실패 시 사용자 가시 신호 부재 (설계 갭 — Task 5 결정 위임)
- 위치: `KISWebSocketClient.swift:72-89` (`open` catch → `scheduleReconnect`)
- 현재 동작: 첫 `open()`의 approval 실패는 `.disconnected`도 `authFailed`도 emit하지 않고 곧장 무한 백오프. (절단 후 재연결 실패 경로도 동일하게 신호 없음.)
- 문제: refresh-recovery 이력상 자격증명 영구 손상의 가시화가 중요했음. WS Event 계약에 `authFailed`가 없어 구조적으로 표면화 불가. design 행 1이 "미발화"를 계약으로 잠갔으므로 **Task 4에서 임의로 case를 추가하면 오히려 계약·Module Map 경계 위반**이 된다.
- 수정 제안: Task 4 코드 변경 금지. 대신 Task 5(조립)/architect에서 결정 — 예: 연속 재연결 실패 임계 도달 시 `.disconnected`를 1회라도 emit해 VM `.wsDisconnected` 배너로라도 가시화할지, 아니면 REST 토큰 경로의 `authFailed`로 충분하다고 볼지. **결정 사항으로 SPRINT_PLAN 이월 권장.**

### [참고] 다종목 구독 시 Approval REST 호출량 (P7 라이브 관찰 포인트)
- 위치: `KISWebSocketClient.swift:107-112` (`sendSubscribe`) + `91-104` (`sendSubscribeEnvelope`)
- 내용: 캐시 불요 결정(결정 6)은 단종목 기준 합리적이나, 다종목 setSubscriptions가 added/removed 각 1회씩 approval 발급 + envelope를 종목 수만큼 전송. P7(동시 등록 한도) 라이브 실측 시 Approval 발급 빈도와 KIS 측 제한 상호작용을 관찰 대상에 포함할 것. 현시점 코드 결함 아님.

### [참고] 약속된 단위 테스트 부재 (T-ws-connect / T-ws-pingpong / T-parse 청킹)
- 위치: design.md:243-247 검증 컬럼 vs `Tests/PMCoreTests/`
- 내용: design 상태·이벤트 계약 행 1·3·2가 각각 T-ws-connect(`.connected` 1회), T-ws-pingpong(echo), T-parse 청킹(건수 011)을 검증 근거로 명시하나, 이 태스크 산출물에 신규 테스트 파일/케이스가 없다(diff = 클라이언트 + ops 1줄). 청킹은 Task 3 KISQuoteParserTests가 일부 커버하나, WS 클라이언트의 `.connected` 멱등·PINGPONG echo·raw 분기는 미커버. SPRINT_PLAN상 Task 4가 "골격→프로토콜"로 정의되어 테스트가 Task 5/QA로 이월된 것일 수 있으나, **명시적으로 이월 등록되지 않았다**. URLSessionWebSocketTask 의존으로 순수 단위 테스트가 어렵다면(actor + 실 WS), QA 라이브(A-2/A-6)로 대체한다는 결정을 SPRINT_PLAN에 남길 것. design 검증 컬럼이 약속한 테스트를 조용히 누락하지 말 것.

### [참고] reconnectAttempt가 매 H0STCNT0 응답마다 리셋 (중복 #3에 종속)
- 위치: `KISWebSocketClient.swift:183`
- 내용: 다종목 시 SUBSCRIBE SUCCESS마다 `reconnectAttempt = 0`. 기능상 무해(연결 성공 = 백오프 리셋이 맞음)하나 N회 중복. 위 [권장] #1 멱등 가드 안으로 옮기면 자연 해소.

---

## 중점 체크 결과 (8항목)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | Event enum 시그니처 키움과 완전 동일 (case 누락·타입 차이 0) | **PASS** | KIS L12-16 = Kiwoom L9-13 (`connected`/`disconnected`/`quote(code:String, quote:Quote)`). QuoteService.handle L110-115 switch 무수정 컴파일 가능 |
| 2 | design 상태·이벤트 행 1~6 관찰 가능 동작 구현 | **부분** | 행1(연결)·행2(체결 청킹)·행3(PINGPONG)·행4(절단)·행5(재연결+재구독)·행6(다종목 한도) 모두 코드 경로 존재. 단 **행1 ".connected 1회" 미충족(중복 emit)** → 권장 수정 |
| 3 | raw 분기 `0|H0STCNT0|건수|본문` flag·tr_id 판별·본문만 위임·JSON 제어 분기 | **PASS** | L158 `hasPrefix("{")` JSON/raw 분기 = PoC L165. handleRaw L194-199 parts 검증·`parts[1]=="H0STCNT0"`·count>0·`parts[3]`만 위임. PoC L180-186와 일치 |
| 4 | PINGPONG echo가 받은 메시지 그대로 회신 | **PASS** | L174-176 `sendRaw(text)` 원문 echo = API_SPEC:72 "동일 메시지 echo" = PoC L169-171 |
| 5 | per-record emit (N건 각각 yield) | **PASS** | L204-206 for record in records → `.quote` yield. parseExecutionChunked가 46×N 청킹 후 N개 반환(KISQuoteParser L23-30) |
| 6 | 백오프 상한 30s + 재연결 시 구독 복구(V-A6) | **PASS** | L122 `min(pow(2,attempt),30)`. 재open L82-84이 보존된 `subscribed`로 재구독(disconnect/handleDisconnect가 subscribed 미클리어) |
| 7 | approval_key 평문 로깅 0건 | **PASS** | 클라이언트 내 print/log 호출 0건. approvalKey는 envelope 조립에만 사용, 로그 경로 없음 |
| 8 | 키움 legacy·기존 테스트 무변경 | **PASS** | diff = KISWebSocketClient(신규)+ops 1줄. KiwoomWebSocketClient.swift·Tests/ 무변경. swift test 회귀 0(ops 노트 보고) |

## Trash-code / 도달성 게이트 (diff 기준)

- **도달성**: KISWebSocketClient는 Task 4 시점에 **아직 미배선**(QuoteService L31/49는 KiwoomWebSocketClient 유지, Task 10/5 조립에서 교체 예정). SPRINT_PLAN이 "KIS* 신규 병존, 즉시 삭제 금지" 전략을 명시(L19)했고 Task 5에 reachability 게이트가 이월 등록되어 있으므로(L25, L62) **의도된 미배선** — 치명 아님. **단 Task 5에서 반드시 배선 검증(import·실호출 경로) 필요** (EYWA dead-component 사고 방지). 미배선 상태로 스프린트 종료 시 치명 승격.
- 중복/구신 공존: 의도된 병존(키움↔KIS). 정리는 design.md:80 + Task 5 후.
- debug 잔존: print/임시 mock/주석코드 0건.
- 미사용 import/export: `import Foundation`만, 전량 사용.
- 방치 TODO/죽은 분기: `handleJSON` default·`handleRaw` guard는 정상 방어 분기. 죽은 코드 아님.
- over-engineering: 없음. actor 상태 최소.

## 요약

| 심각도 | 건수 |
|--------|------|
| 치명적 | 0건 |
| 권장 | 2건 |
| 참고 | 3건 |

## 다음 단계 (우선순위)

1. [권장] `.connected` 멱등화 — `didEmitConnected` 전이 가드 (다종목 P7 실측 전 잠금, T-ws-connect 작성 시 필수).
2. [권장] WS approval 영구 실패 가시화 여부를 Task 5/architect 결정으로 SPRINT_PLAN 이월 (Task 4 코드 변경 금지).
3. [참고] design 검증 컬럼이 약속한 T-ws 테스트 — 작성 또는 "QA 라이브 대체" 결정을 SPRINT_PLAN에 명시.
4. [Task 5 필수] KISWebSocketClient 배선(reachability) 게이트 — 미배선 잔존 시 치명 승격.
