# QA Report — kis-migration Task 4

**날짜**: 2026-06-04
**태스크**: KISWebSocketClient — 골격(Event 불변·approvalKeyProvider) → 프로토콜(envelope·46필드 청킹 위임·PINGPONG)
**범위**: 정적+단위 (UI 변경 없음, 라이브 WS 검증 V-A2·A5·A6는 오너 게이트)
**판정**: PASS

---

## 수용 기준 표

| # | 항목 | 판정 | 근거 |
|---|---|---|---|
| 1 | 회귀 0: swift test 83개 전부 PASS, 기존 테스트 파일 변경 0 | PASS | `swift test` exit=0, 83 passed 0 failures; `git diff HEAD -- Tests/` 출력 없음 |
| 2 | Event enum 시그니처 KiwoomWebSocketClient와 완전 동일 | PASS | grep 대조: case connected / disconnected / quote(code: String, quote: Quote) 3-case 완전 일치 |
| 3a | H0STCNT0 tr_id envelope 구독 송신 | PASS | line 100: `"tr_id": "H0STCNT0"` — API_SPEC.md §WS 구독 송신 일치 |
| 3b | tr_key 6자리 종목코드 | PASS | line 100: `"tr_key": code` (코드 그대로 전달, 별도 변환 없음) — API_SPEC 정합 |
| 3c | PINGPONG echo | PASS | line 174~176: `case "PINGPONG"` → `sendRaw(text)` — PoC 동일 패턴 |
| 3d | raw 프레임 `\|` 구분 분기 | PASS | line 194: `text.components(separatedBy: "\|")` + parts[1]=="H0STCNT0" 필터 |
| 3e | 백오프 2·4·8·16·30s | PASS | `min(pow(2.0, Double(reconnectAttempt)), 30.0)`: 1→2/2→4/3→8/4→16/5+→30 수열 검증 |
| 3f | approvalKeyProvider 주입(connect마다 1회) | PASS | `open()` 내 `approvalKeyProvider()` 1회 호출, 별도 캐시 없음 |
| 3g | KISQuoteParser 위임 + per-record emit | PASS | line 202: `KISQuoteParser.parseExecutionChunked` 위임 + for-loop emit |
| 4 | 단위 테스트 갭 판단 | N/A (갭 사유 기록) | 아래 §갭 판단 참조 |
| 5 | scope 잠금: 변경 2파일 한정 | PASS | `git status`: KISWebSocketClient.swift(untracked), OPERATIONAL_NOTES.md(M). SPRINT_PLAN.md(M)는 상태 갱신 — 제품 로직 외 docs 파일로 scope 위반 없음 |

---

## §갭 판단 (검증 항목 4)

`KISWebSocketClient`의 핵심 수신 로직(`handle`, `handleJSON`, `handleRaw`, `startReceiver`)은 전부 `private`. actor 격리 상 `@testable import`로도 직접 호출 불가. 현 API 표면에서 단위 테스트 가능한 순수 함수는 없음.

단 `decodeJSON(_:)` 및 frame 분기 판단(`text.hasPrefix("{")`)은 handleRaw/handleJSON 안에 인라인으로 묻혀 있어 별도 internal 노출 없이는 테스트 불가 — 제품 코드 수정 금지(Constraints ①) 해당.

**결론**: 이 패턴은 `KiwoomWebSocketClient` 동일 구조(handle private, PoC 실증). 라이브 게이트 V-A2(구독 응답 수신)·V-A6(체결 raw 수신)이 커버하는 범위로 갭 사유 기록하고 PASS 허용.

---

## 테스트 실행 결과

```
명령: xcodegen generate && swift test
로그: /tmp/qa-task4-1780553858.log (207줄)
exit: 0

Test Suite 'All tests' passed
  Executed 83 tests, with 0 failures (0 unexpected) in 0.050 seconds

주요 suite:
  KISQuoteParserTests  — 18 passed
  KISRESTClientTests   — 5 passed
  QuoteParsingTests (Kiwoom)  — 7 passed
  기타 (MarketClock, TokenManager, Keychain, Watchlist, Policy, PriceDirection, Reachability, AppSmoke) — 53 passed
```

---

## Units & Signs Audit (Task 4 신규 코드)

`KISWebSocketClient`에서 발생하는 숫자 변환:

| 위치 | 입력 | 출력 | 변환 | 검증 |
|---|---|---|---|---|
| scheduleReconnect (line 122) | reconnectAttempt: Int | delay: Double (초) | `pow(2.0, Double(attempt))` cap 30.0 | 백오프 수열 python3 재계산 PASS |
| scheduleReconnect (line 123) | delay: Double (초) | nanoseconds: UInt64 | `delay * 1_000_000_000` | 30s→30_000_000_000ns, 오버플로 없음 (UInt64.max≈18.4×10⁹s) |
| handleRaw (line 198) | parts[2]: String | count: Int | `Int(...)` with whitespace trim | count>0 가드 보호 |

파서 수치(price/change/previousClose) 변환은 KISQuoteParser(Task 3 Units & Signs Audit 통과)에 위임 — KISWebSocketClient 자체 변환 없음.

---

## scope 잠금 확인

```
git status:
  M  docs/OPERATIONAL_NOTES.md       (+1줄 ops 노트)
  M  docs/sprints/SPRINT_PLAN.md     (Task 3 commit SHA, Task 4 상태 갱신)
  ?? Sources/PMCore/Network/KISWebSocketClient.swift  (신규)
  ?? docs/reviews/kis-migration-task-4-review.md      (reviewer 산출물)

기존 테스트 파일 변경: 0건 (git diff HEAD -- Tests/ 출력 없음)
제품 로직 파일 수정: 0건
```

---

## 라이브 WS 검증 게이트 (본 QA 범위 외)

| 항목 | 상태 |
|---|---|
| V-A2: 구독 응답(rt_cd:"0") + .connected emit | 오너 게이트 (라이브 필요) |
| V-A5: PINGPONG echo 미회신 시 재연결 | 오너 게이트 |
| V-A6: 체결 raw H0STCNT0 건수N → N틱 emit | 오너 게이트 |

이 항목들은 `tools/kis-ws-poc.swift` 실측 정답지와 구현 대조 완료(정적 검증). 라이브 동작은 Task 완료 후 장중 실행으로 오너가 확인.
