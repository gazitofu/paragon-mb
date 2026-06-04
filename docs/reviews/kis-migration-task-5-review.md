# 코드 리뷰 리포트 — kis-migration Task 5 (T9+T10: 조립 루트 KIS 전환 + QuoteService 타입 참조)

리뷰일: 2026-06-04 · 리뷰어: reviewer (모드 1) · 브랜치: `feat/kis-migration`

## 전체 평가

조립 루트(AppDelegate) + QuoteService 타입 참조 전환이 설계(design.md §결정 1·6·8·10, §Module Map impact map, §상태·이벤트 계약)와 정확히 일치한다. 배선 게이트(Floor 2)는 5개 KIS 컴포넌트 전부 실제 도달 경로에 연결되었고, 키움 경로는 조립에서 완전히 분리되었다(AppDelegate·QuoteService에 `Kiwoom*` 참조 0). QuoteService diff는 타입명·주입 시그니처에 한정되며 상태 머신·스트림·재시도 로직 변경 0건(V-C4 충족). 자격증명은 Keychain만 읽고 평문 로깅 0(Floor 4·V-B2 충족). ATS 예외는 단일 도메인 한정으로 최소 권한 원칙을 지킨다. 치명 이슈 0건. 발견된 것은 모두 참고 수준의 잔재·방어 코드 항목이다.

## 변경 범위 전수 확인 (git diff --stat HEAD)

| 파일 | 변경 | 스코프 판정 |
|---|---|---|
| `App/AppDelegate.swift` | +24 −13 | 태스크 범위 OK |
| `Sources/PMCore/Service/QuoteService.swift` | +16 −11 | 태스크 범위 OK |
| `project.yml` | +4 | 태스크 범위 OK |
| `docs/OPERATIONAL_NOTES.md` | +1 | 태스크 범위 OK |
| `docs/sprints/SPRINT_PLAN.md` | 6줄 | 스프린트 상태 갱신(범위 외 메타, 정상) |

`Sources/PMCore/Model/`·`App/Views/`·`App/ViewModels/`·`Sources/PMCore/Domain/` diff 0건 — Symbol·Quote·PriceDirection·MarketClock·DesignTokens·ViewModel·View 전부 무변경(V-C4 게이트 충족).

---

## 중점 체크 결과

### 1. 배선 게이트 (Floor 2) — PASS

grep 호출처 독립 재검증(developer 보고 표 검증):

| 컴포넌트 | 도달 경로 | 판정 |
|---|---|---|
| `KISEnvironment` | `KISRESTClient.swift`(tokenURL 등) + `KISWebSocketClient.swift` 내부 참조 | 도달 OK |
| `KISCredential` | `AppDelegate.swift:21-22`(Keychain get) ← `KeychainStore.swift` 정의 | 도달 OK |
| `KISRESTClient` | `AppDelegate.swift:17` 생성 → `QuoteService` 주입 → `Tests/.../KISRESTClientTests` | 도달 OK |
| `KISQuoteParser` | `KISRESTClient`(lookupPrice 파싱) + `KISWebSocketClient`(체결 파싱) 위임 | 도달 OK |
| `KISWebSocketClient` | `QuoteService.swift:57` 생성(approvalKeyProvider 주입) ← `AppDelegate`가 provider 공급 | 도달 OK |

5개 전부 import 0 / 라우팅 미등록 아님. EYWA 류 dead-component 사고 위험 없음.

**키움 경로 분리 검증**: `App/`·`Sources/PMCore/Service/`에서 `Kiwoom*` 코드 참조 0. 유일한 잔존은 `AddSymbolViewModel.swift:5`의 주석(`KiwoomRESTClient.RESTError`)이며 이 파일은 Task 5 diff에 없음(아래 [참고] 참조). 병존 파일(`KiwoomRESTClient.swift`·`KiwoomWebSocketClient.swift`·`KiwoomQuoteParser.swift`·`KiwoomEnvironment.swift`)은 빌드에 남으나 조립 루트에서 도달 불가 — 설계상 정상(점진 폐기, design.md §결정 1 "키움 폐기 확정").

### 2. QuoteService diff = 타입 참조·주입 시그니처 한정 — PASS

diff 전체가 다음으로 한정됨:
- 필드 타입: `KiwoomRESTClient`→`KISRESTClient`, `KiwoomWebSocketClient`→`KISWebSocketClient` + `appKey`/`appSecret` 저장 프로퍼티 추가
- `init`: `environment:` 제거, `approvalKeyProvider:`·`appKey:`·`appSecret:` 추가, WS 생성자를 KIS 생성자로 교체
- `loadInitial`: `rest.lookup(...).symbol/.quote` → `rest.lookupPrice(...)`로 메서드 교체(반환이 `Quote` 단일이라 `emit.yield(.quote(code: code, quote: quote))`로 정정 — code는 입력값 사용, 설계 §결정 1 "코드 키는 입력 6자리 그대로" 와 일치)
- `handle` 파라미터 타입: `KiwoomWebSocketClient.Event`→`KISWebSocketClient.Event`

상태 머신(`start`/`updateWatchlist`/`stop`), WS on/off 분기(`status.isLive`), 재시도/구독 diff, AsyncStream emit 흐름 로직 변경 0건. impact map(design.md §200) "타입 참조만" 명시와 정확히 일치.

### 3. symbolLookup = 종목명만 (CTPF1002R) — PASS

`AppDelegate.swift:44-55` 클로저는 `rest.lookupName(...)`(CTPF1002R)만 호출하고 `Symbol` 반환. 초기 시세(inquire-price/FHKST01010100)는 호출하지 않음 → 설계 §결정 8("등록 클로저는 1콜로 끝나고 초기 시세는 QuoteService.loadInitial 담당")과 일치. 초기 시세 중복 호출 없음. `AddSymbolViewModel` 시그니처 무변경(`(String) async throws -> Symbol` 불변, 파일 diff 0).

### 4. RESTError→SymbolLookupError 매핑 완결성 — PASS

`RESTError` 전체 케이스: `apiError`·`lookupFailed`·`missingToken`·`tokenRejected`·`http`·`decodingFailed`.

| RESTError | → SymbolLookupError | 사용자 가시 결과 |
|---|---|---|
| `lookupFailed` | `.invalidCode` | "등록할 수 없는 종목코드입니다"(인라인) |
| `apiError` | `.invalidCode` | 동일(인라인) — design.md §107 "`rt_cd!=0`/빈 output → 인라인 에러"와 일치 |
| `missingToken` | `.network`(fall-through) | "네트워크 연결을 확인해 주세요" |
| `tokenRejected` | `.network`(fall-through) | 동일 |
| `http` | `.network`(fall-through) | 동일 |
| `decodingFailed` | `.network`(fall-through) | 동일 |
| (비-RESTError) | `.network`(outer catch) | 동일 |

`if case` 2개 미스 시 `throw SymbolLookupError.network`로 떨어지고 outer `catch`가 나머지를 잡아 누락 케이스 없음. design.md §상태·이벤트 계약 V3 error 행(invalidCode/network 2분기)과 정합. P6(에러 형태 미실측)는 design.md §190 R7에서 deferred 등록됨.

### 5. ATS 최소 권한 — PASS

`project.yml:31-34`: `NSAppTransportSecurity → NSExceptionDomains → ops.koreainvestment.com → NSExceptionAllowsInsecureHTTPLoads: true`. 단일 도메인 한정, `NSAllowsArbitraryLoads`(전역 개방) 미사용. design.md §결정 10("전송 정책이라 config가 정석, Floor 4 위반 아님")과 일치. API_SPEC §WS의 평문 ws 도메인(`ops.koreainvestment.com:21000`)과 일치. `info.properties` 경유 → xcodegen 재생성으로 `App/Info.plist`(gitignore) 영속 — 영속 경로 정확. REST 도메인(`openapi.koreainvestment.com:9443`)은 HTTPS라 예외 불요(올바름).

### 6. 자격증명 안전 (Floor 4 / V-B2) — PASS

- Keychain만 읽음(`KeychainStore().get(service: KISCredential.appKey/appSecret)`) — env 파일 직접 읽기 0.
- 평문 로깅 0(변경 파일에 `print`/`NSLog`/`debugPrint` 0건).
- 헤더 주입 외 노출 0 — `appKey`/`appSecret`은 fetcher·approvalKeyProvider·symbolLookup·QuoteService 주입에만 전달, 외부 출력 경로 없음.
- 자격증명 로드·토큰 발급·approval 발급이 Auth 레이어 + AppDelegate 조립 루트에 명시(config/helper 숨김 0) — design.md §220 ⑤ 충족.

### 7. TokenManager fetcher 타이밍 보존 — PASS

`git diff HEAD -- Sources/PMCore/Auth/TokenManager.swift` 빈 diff(무변경). 캐시+margin(`refreshMargin`)·`validToken()`·`invalidate()` 로직 불변. AppDelegate는 `fetcher` 클로저 본문만 교체(`rest.issueToken(appKey:appSecret:)` 호출) — 캐시/만료/재발급 타이밍 로직 미접촉. design.md §205("fetcher 주입만 외부에서 교체") + §189 R6(분당 1회 제약은 캐시+margin이 보장) 정합.

### 8. 모델·뷰·VM·디자인 토큰 diff 0 (V-C4) — PASS

§"변경 범위 전수 확인" 표 참조. 해당 디렉토리 전부 0건.

### 9. 기존 테스트 무변경 + AppTests 회귀 — PASS (판단)

- 테스트 파일 diff 0(`Tests/` 변경 없음).
- `Tests/AppTests/AppSmokeTests.swift`: `WatchlistViewModel.ScreenState` 심볼만 접근 — AppDelegate `makeWatchlistViewModel`이나 QuoteService init 미참조 → 영향 없음.
- `Tests/AppTests/WatchlistViewModelRefreshTests.swift`: `MockQuoteService`(`QuoteServicing` 프로토콜 구현)를 주입 — 구체 `QuoteService` init·AppDelegate 미참조. init 시그니처 변경이 AppTests에 도달하지 않음.
- developer 보고 "swift test 83/83 PASS 회귀 0, xcodebuild BUILD SUCCEEDED"는 위 구조와 모순 없음(AppTests 11케이스는 프로토콜 경계로 격리되어 회귀 불가능한 설계).

---

## 발견된 이슈

### [참고] AddSymbolViewModel 주석에 구 타입명(`KiwoomRESTClient`) 잔존
- 위치: `App/ViewModels/AddSymbolViewModel.swift:5`
- 현재: `/// 조립 루트가 KiwoomRESTClient.RESTError → 본 enum으로 매핑해 주입한다.`
- 문제: 실제 매핑 주체는 이제 `KISRESTClient.RESTError`(AppDelegate.swift:48). 코드 동작에는 무영향(주석)이나 신·구 구조 공존 잔재로, 마이그레이션 종료 시 혼동 유발 가능.
- 영향: 없음(빌드·동작 무관). Task 5 변경 파일이 아니므로 이번 태스크의 결함은 아님.
- 제안: 키움 병존 파일 정리 태스크(전환 종료 시) 또는 차기 AddSymbolView 손볼 때 `KISRESTClient.RESTError`로 정정. 지금 단독 수정은 스코프 외이므로 권장하지 않음.

### [참고] `appKey ?? ""` / `appSecret ?? ""` 빈 문자열 폴백 — 무자격 시 동작 경로
- 위치: `App/AppDelegate.swift:39-40`, `47`
- 현재: 자격증명 미로드 시 QuoteService에 `""`·`""` 전달, symbolLookup에도 `""` 전달.
- 문제: Keychain에 키가 없으면 fetcher/approvalKeyProvider는 `guard let appKey, let appSecret`에서 `missingToken`을 던지므로(토큰 발급 차단) 안전하게 실패한다. `lookupPrice`/`lookupName`에는 빈 문자열이 헤더로 전달될 수 있으나 이 경로는 `validToken()`(또는 fetcher)이 먼저 throw하므로 실제로 도달하지 않음 — 현재는 무해. 다만 "왜 안전한가"가 호출 순서에 의존하는 암묵 계약이라 추적성 측면에서 기록.
- 영향: 낮음(현재 도달 불가 경로). design.md §259("키 미존재 = missingToken → authFailed 배너")와 결과 일관.
- 제안: 추가 작업 불요. 차후 자격증명 미설정 UX(온보딩)를 다룰 때 빈 문자열 대신 명시적 실패 게이트로 단일화 고려.

### [참고] `issueToken`은 ThrottleQueue를 경유하지 않음 (T6 범위 — Task 5 무관)
- 위치: `Sources/PMCore/Network/KISRESTClient.swift:106` (issueToken에 `throttle.waitIfNeeded()` 없음; `issueApprovalKey`·lookup 계열은 경유)
- 문제: tokenP 분당 1회 제한 관점에서 token 발급은 스로틀 큐 밖이다. 단 분당 1회 보호는 TokenManager 캐시+margin이 담당(design.md §189 R6)하므로 issueToken 자체를 스로틀하지 않는 것은 설계상 일관됨.
- 영향: 없음(Task 5는 fetcher 본문만 교체, KISRESTClient 내부는 T6 산출물). Task 5 결함 아님 — 컨텍스트 기록용.
- 제안: 없음. R6의 라이브 모니터링(401 폭주 시 invalidate 후 재발급 간격 가드)은 이미 deferred 등록됨.

---

## 요약

| 심각도 | 건수 |
|--------|------|
| 치명적 | 0건 |
| 권장 | 0건 |
| 참고 | 3건 |

치명·권장 0건. 참고 3건 전부 Task 5 변경 파일 외부의 기존 잔재이거나 무해한 방어 코드로, 이번 태스크의 결함이 아니다.

## 다음 단계

1. Task 5는 PASS — 추가 수정 없이 커밋 진행 가능.
2. 커밋 단위 제안: 변경 4파일(project.yml·AppDelegate.swift·QuoteService.swift·OPERATIONAL_NOTES.md) + SPRINT_PLAN.md 상태 갱신. Conventional Commit 후보: `feat(kis): switch assembly root and QuoteService to KIS provider (T9+T10)`. 커밋은 사용자가 실행.
3. (스코프 외, 추후) 키움 병존 파일 폐기 태스크에서 `AddSymbolViewModel.swift:5` 주석의 `KiwoomRESTClient` → `KISRESTClient` 정정 포함.
4. (확인 권장) `xcodegen generate` 후 `App/Info.plist`(gitignore 재생성물)에 ATS 예외가 실제 반영됐는지 라이브 빌드 시 1회 확인 — project.yml 검증으로 갈음했으나 재생성 산출물 실측은 Stage 6/라이브에서.
