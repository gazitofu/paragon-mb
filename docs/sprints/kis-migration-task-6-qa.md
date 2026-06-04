---
task: 6
sprint: kis-migration
qa-date: 2026-06-04
verdict: PASS
---

# QA Report — Task 6: 자동화 검증 스위프 (회귀 0 게이트)

> 검증 항목: V-C1b · V-B1t · V-B2 · V-C4  
> 실행 환경: feat/kis-migration 브랜치 (HEAD 34ccd56 → 249f563)  
> 로그 경로: `/tmp/qa-task6-swift-1780561563.log` (211줄) · `/tmp/qa-task6-app-1780561992.log` (1182줄)

---

## 1. 수용 기준 판정 표

| 항목 | 수용 기준 (proposal.md 참조) | 판정 | 근거 |
|---|---|---|---|
| V-C1b | 기존 자동화 회귀 0 — PMCore 83개 + AppTests 11개 전부 PASS | **PASS** | swift test exit=0, 83 passed · xcodebuild test exit=0, 11 passed |
| V-B1t | TokenManager 4케이스 무변경 통과 (파일 무변경 git 확인 포함) | **PASS** | 4케이스 전부 passed · 스프린트 기간 TokenManagerTests.swift 변경 커밋 0건 |
| V-B2 | Keychain 정석 — env 직접 읽기 0 · 평문 노출 0 · 식별자 사용 확인 | **PASS** | grep env/ProcessInfo 앱 본체 0건 · 식별자 `kr.co.koreainvestment.paragon.*` 확인 · 평문 print/log 0건 |
| V-C4 | UI/도메인 무변경 diff scope — ViewModel·View·DesignTokens·Quote·PriceDirection·MarketClock 0 diff | **PASS** | `git diff --stat main...feat/kis-migration` 전수 확인: 해당 파일군 변경 0건 |

---

## 2. 테스트 실행 결과

### PMCore — swift test (non-watch)

```
명령: swift test
로그: /tmp/qa-task6-swift-1780561563.log
exit: 0
```

| 테스트 슈트 | 케이스 수 | 결과 |
|---|---|---|
| KISQuoteParserTests | 18 | 18 PASS |
| KISRESTClientTests | 19 | 19 PASS |
| KeychainStoreTests | 5 | 5 PASS |
| MarketClockTests | 6 | 6 PASS |
| NetworkPathReachabilityTests | 7 | 7 PASS |
| PolicyTests | 1 | 1 PASS |
| PriceDirectionTests | 7 | 7 PASS |
| QuoteParsingTests | 9 | 9 PASS |
| TokenManagerTests | 5 | 5 PASS |
| WatchlistStoreTests | 6 | 6 PASS |
| **합계** | **83** | **83 PASS / 0 FAIL** |

### AppTests — xcodebuild test (fresh derivedDataPath)

```
명령: xcodebuild test -scheme PARAGON-MB -configuration Debug -derivedDataPath /tmp/qa-task6-dd -destination "platform=macOS"
로그: /tmp/qa-task6-app-1780561992.log
exit: 0
```

| 테스트 슈트 | 케이스 수 | 결과 |
|---|---|---|
| AppSmokeTests | 1 | 1 PASS |
| WatchlistViewModelRefreshTests | 10 | 10 PASS |
| **합계** | **11** | **11 PASS / 0 FAIL** |

**전체 자동화: 94 PASS / 0 FAIL**

---

## 3. V-C1b — 기존 자동화 회귀 0 상세

impact map 무영향 확인 대상 슈트별 판정:

| 슈트 | 판정 | 비고 |
|---|---|---|
| TokenManagerTests | PASS (5/5) | actor 로직 무변경 |
| PriceDirectionTests | PASS (7/7) | 도메인 무변경 |
| MarketClockTests | PASS (6/6) | Asia/Seoul 무변경 |
| WatchlistStoreTests | PASS (6/6) | 파일 입출력 무변경 |
| KeychainStoreTests | PASS (5/5) | CRUD 로직 무변경 |
| PolicyTests | PASS (1/1) | maxWatchlistCount 무변경 |
| NetworkPathReachabilityTests | PASS (7/7) | 네트워크 감시 무변경 |

---

## 4. V-B1t — TokenManager 타이밍 회귀 상세

TokenManagerTests.swift 스프린트 내 변경 이력 확인:
- `git log --oneline a8d2440..HEAD -- Tests/PMCoreTests/TokenManagerTests.swift` → **0건** (최초 생성 커밋 23a358a 이후 미변경)
- `git diff --name-only main...feat/kis-migration -- Tests/PMCoreTests/TokenManagerTests.swift` → **출력 없음 (0 diff 확인)**

4케이스 결과:

| 케이스 | 결과 |
|---|---|
| testFetchesOnceWhenValid | PASS |
| testRefetchesWithinRefreshMargin | PASS |
| testInvalidateForcesRefetch | PASS |
| testFetcherErrorPropagates | PASS |

---

## 5. V-B2 — Keychain-only 자격증명 상세

**① env 직접 읽기 grep (Sources/ App/ Tests/ — tools/ 제외)**

대상 패턴: `api.env`, `KIS_APP_KEY`, `KIS_APP_SECRET`, `ProcessInfo.*environment.*[Kk][Ii][Ss]`, `loadenv`, `.env"`
결과: **0건**

**② ProcessInfo.processInfo.environment 분류**

| 경로 | 건수 | 비고 |
|---|---|---|
| Sources/ + App/ (앱 본체) | 0건 | 자격증명 경로 없음 |
| tools/ (PoC 도구 전용) | 3건 | tools/kis-auth-poc.swift, tools/kis-name-poc.swift, tools/kis-ws-poc.swift — PARAGON_SECRETS_ENV 경로 (`env` 파일 포인터) |

tools/ PoC 도구의 ProcessInfo 사용은 앱 본체와 분리된 독립 실행 파일이며, 앱 번들에 포함되지 않음. V-B2 범위 외.

**③ Keychain 식별자 사용 확인**

```
Sources/PMCore/Auth/KeychainStore.swift:73:  public static let appKey = "kr.co.koreainvestment.paragon.appkey"
Sources/PMCore/Auth/KeychainStore.swift:74:  public static let appSecret = "kr.co.koreainvestment.paragon.appsecret"
```

AppDelegate.swift:
```swift
let keychain = KeychainStore()
let appKey    = (try? keychain.get(service: KISCredential.appKey))    ?? nil
let appSecret = (try? keychain.get(service: KISCredential.appSecret)) ?? nil
```

Keychain → `KISCredential.appKey` / `KISCredential.appSecret` 식별자 경유 확인.

**④ 평문 print/log 자격증명 노출**: grep 결과 0건.

**⑤ 정적 범위 판정 한계 명시**: 실행 로그(런타임) 검증은 라이브 게이트 범위. 정적 코드 분석 기준으로 env 경로 부재·Keychain 정석 PASS 판정.

---

## 6. V-C4 — UI/도메인 무변경 diff scope 잠금 상세

`git diff --stat main...feat/kis-migration` 결과 (24개 파일):

**변경 허용 범위 (전수 확인 — 모두 해당)**

| 파일 | 분류 |
|---|---|
| App/AppDelegate.swift | 조립 루트 (T10 명시) |
| Sources/PMCore/Auth/KeychainStore.swift | Auth — KISCredential 식별자 추가 (T2) |
| Sources/PMCore/Network/KISEnvironment.swift | Network 신규 (T1) |
| Sources/PMCore/Network/KISQuoteParser.swift | Network 파서 신규 (T6) |
| Sources/PMCore/Network/KISRESTClient.swift | Network 신규 (T3~T5) |
| Sources/PMCore/Network/KISWebSocketClient.swift | Network 신규 (T7~T8) |
| Sources/PMCore/Service/QuoteService.swift | 타입 참조 갱신 (T10 명시 범위) |
| project.yml | ATS 예외 +4줄 (T9) |
| CHANGELOG.md | docs |
| Tests/PMCoreTests/KISRESTClientTests.swift | 테스트 신규 |
| Tests/PMCoreTests/QuoteParsingTests.swift | 테스트 갱신 |
| docs/OPERATIONAL_NOTES.md | docs |
| docs/reviews/kis-migration-task-{1~5}-review.md (5건) | docs |
| docs/sprints/SPRINT_PLAN-2026-06-02.md | docs |
| docs/sprints/SPRINT_PLAN.md | docs |
| docs/sprints/kis-migration-task-{1~5}-qa.md (5건) | docs |

**금지 파일군 0 diff 전수 확인**

| 대상 | 결과 |
|---|---|
| ViewModel 파일군 | 0 diff |
| View 파일군 | 0 diff |
| DesignTokens 파일군 | 0 diff |
| Quote.swift | 0 diff |
| PriceDirection.swift | 0 diff |
| MarketClock.swift | 0 diff |

QuoteService.swift diff 내용 확인: `KiwoomRESTClient`→`KISRESTClient`, `KiwoomWebSocketClient`→`KISWebSocketClient` 타입 참조 교체 + approvalKeyProvider/appKey/appSecret DI 파라미터 추가. tasks.md T10 명시 범위 내. **도메인 로직·인터페이스 계약(`QuoteServicing` 프로토콜) 무변경.**

---

## 7. Units & Signs Audit (PASS 직전 확인)

Task 3 QA에서 V-C2로 전수 잠금 완료. 본 Task 6에서 재확인:

| function | input unit | output unit | sign convention | test 확인 |
|---|---|---|---|---|
| `KISQuoteParser.parseRecord` [2]현재가 | 원 정수 문자열 | `Int`(원) | 부호 없음 | testParseRecord_PoC_005930 PASS |
| `KISQuoteParser.parseRecord` [4]전일대비 | signed 문자열 | `Int`(원, signed 직접) | 음수=하락 직접 | testParseRecord_PoC_005930 PASS |
| `KISQuoteParser.parseRecord` [5]등락률 | signed 문자열 | `Double`(%, signed) | 음수=하락 직접 | testParseRecord_ChangeRate_SignedDirect PASS |
| `KISQuoteParser.parseRecord` [3]sign | `"2"`/`"5"` | 검증 보조 | signed 모순 시 signed 채택 | testParseRecord_SignContradiction_SignedWins PASS |
| `Quote.previousClose` (역산) | price − change | `Int`(원) | change 부호 보존 | testParseRecord_PoC_005930 PASS |
| `parsePrice` `prdy_vrss` (REST) | signed 추정 | `Int`(원, signed 직접) | P5 🟡 미실측 — 라이브 V-A3 | (라이브 게이트) |
| `parseStockInfo` `prdt_abrv_name` | 문자열 (trailing 공백) | `String`(trim) | N/A | testParseStockInfo_TrailingSpaceTrimmed PASS |

---

## 8. 라이브 게이트로 넘어가는 잔여 항목

자동화 범위 외 — 거래일 09:00~15:30 KST 또는 특정 조건 필요:

| 항목 | 이유 |
|---|---|
| V-A1 | 장중 KIS REST end-to-end (EGW00201 미발생 확인) |
| V-A1e | P6 등록 실패 분기 실제 응답 형태 관측 |
| V-A2 | 장중 WS 체결 수신 → 0.3s 내 하이라이트·갱신 |
| V-A3 | 부호 체계 정확 표시 + P5 REST prdy_vrss 하락 실측 |
| V-A4 | 20개 한도 + P7 WS 동시 구독 한도 종결 |
| V-A5 | 삭제 시 KIS WS 구독 즉시 제거 |
| V-A6 | WS 재연결 구독 자동 복구 |
| V-B1 | 토큰 24h 갱신 지속 end-to-end |
| V-C3 | 장외 종가 + 장상태 라벨 + 갱신 정지 (MarketClock 렌더) |
| P5 | REST prdy_vrss 하락 부호 — 다음 하락 시점 실측 1건으로 종결 |
| P6 | 미존재 종목코드 응답 형태 관측 |
| P7 | 다종목 동시 WS 구독 한도 종결 |

---

## 9. 요약

- **V-C1b**: PMCore 83 PASS + AppTests 11 PASS — 회귀 0 게이트 통과
- **V-B1t**: TokenManagerTests 4케이스 무변경 통과 + git 변경 이력 0건 확인
- **V-B2**: 앱 본체 env 직접 읽기 0건 · Keychain 정석 확인 · 평문 노출 0건 (정적 범위)
- **V-C4**: 금지 파일군 6종 0 diff · 24개 변경 파일 전수 허용 범위 내

**자동화 영역 회귀 0 게이트: 4항목 전부 PASS**
