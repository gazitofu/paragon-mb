# QA 리포트 — Task 3: WatchlistViewModel refresh 상태기계 (T2~T6)

- 일자: 2026-06-02
- QA agent: qa (모드: sprint Task Loop Step 3)
- 검증 게이트: 빌드 통과 레벨 (전이 단언은 Task 4 위임)
- SSOT: `Vault/appdev/PARAGON-MB/prd/refresh-recovery/design.md §상태·이벤트 계약`
- 리뷰 참조: `docs/reviews/task-3-review.md` (보강 재확인 2026-06-02 포함)

## 수용 기준 대조표

| # | 기준 | 결과 |
|---|------|------|
| 1 | `xcodegen generate` 성공 | PASS |
| 2 | `xcodebuild -scheme PARAGON-MB -configuration Debug build` → BUILD SUCCEEDED | PASS |
| 3 | `swift test` 46/46 회귀 없음 | PASS |
| 4 | 계약 매트릭스 커버리지 — design.md §상태·이벤트 계약 11행 모두 코드에 반영 (빈 셀/미구현 행 0건) | PASS |
| 5 | `isRefreshing=false` 해제가 모든 종료 경로(.quote / .error / .connection(true))에서 보장 | PASS |
| 6 | `retry()` 완전 삭제 확인 (함수 정의 0건, 호출처 0건) | PASS |

## 기준 1: xcodegen generate

- 명령: `cd /Users/gazitofu/Developer/PARAGON-MB && xcodegen generate`
- 결과: exit=0, "Created project at PARAGON-MB.xcodeproj"
- 오류: 0건

## 기준 2: xcodebuild Debug 빌드

- 명령: `xcodebuild -scheme PARAGON-MB -configuration Debug build`
- 로그: `/tmp/qa-task3-build-1780360407.log` (117줄)
- 결과: **BUILD SUCCEEDED** (exit=0)
- error: 행 0건 (warning: 다중 destination — 무해, arm64 첫 번째 선택)

## 기준 3: swift test 회귀 확인

- 명령: `swift test`
- 로그: `/tmp/qa-task3-test-1780360442.log` (126줄)
- 결과: **46/46 passed**, 0 failures (exit=0)
- 스위트 구성: KeychainStoreTests · MarketClockTests · NetworkPathReachabilityTests · PolicyTests · PriceDirectionTests · QuoteParsingTests · TokenManagerTests · WatchlistStoreTests — 전 스위트 passed

## 기준 4: 계약 매트릭스 커버리지 (정적 확인)

design.md §상태·이벤트 계약 11행 대조 (reviewer task-3-review.md 정합표 기반 최종 확인).

| 매트릭스 행 | 코드 위치 | 상태 |
|---|---|---|
| 행1: authFailed →(버튼/NWPath) refresh | VM:198-209 — isRefreshing=true, state=.loading(선리셋), loadFailed=false, service.start | 반영 |
| 행2: authFailed →(refresh후) .quote | VM:109-115 — state=.normal(확장조건 .authFailed 포함), isRefreshing=false | 반영 |
| 행3: authFailed →(refresh후) .error(.authFailed) | VM:127-131 — isRefreshing=false(switch 전), state=.authFailed | 반영 |
| 행4: wsDisconnected →(버튼/NWPath) refresh | VM:198-209 — isRefreshing=true, state=.loading(선리셋), service.start | 반영 |
| 행5: wsDisconnected →(refresh후) .connection(true) 단독 | VM:119-124 — `(isRefreshing && state == .loading)` 가드로 state=.normal + isRefreshing=false 보장 (보강 재확인 닫힘) | 반영 |
| 행6: loadFailed →(배너 "다시 시도") refresh | VM:198-209 + Header:15 — retry()→refresh() 배선, loadFailed=false, service.start | 반영 |
| 행7: normal →(버튼) refresh | VM:204-208 — state 유지(`.normal` 선리셋 제외), isRefreshing=true, service.start | 반영 |
| 행8: normal →(refresh후) .quote | VM:109-115 — isRefreshing=false, quotes 갱신, state 유지(.normal) | 반영 |
| 행9: loading →(버튼) refresh | VM:204 — `state != .normal` true → .loading 재대입(no-op), isRefreshing=true | 반영 |
| 행10: refreshing(isRefreshing==true) → 추가 refresh | VM:201 — `guard !isRefreshing` early return, service.start 미호출 | 반영 |
| 행11: empty(symbols 0건) → refresh | VM:202 — `guard !symbols.isEmpty` early return | 반영 |
| 경계: NWPath transition-edge만 발화 | NetworkPathReachability — T-NW1/T-NW2 통과(Task 1 완료) | 반영 |
| 경계: AlertBanner onRetry emit만, 배선은 parent | Header:15 — `{ viewModel.refresh() }` 배선 | 반영 |

빈 셀 0건. deferred(R2 완전 무응답 v1 비목표)는 매트릭스에 명시 등록.

## 기준 5: isRefreshing 해제 경로 확인

| 종료 경로 | 코드 위치 | isRefreshing=false 보장 |
|---|---|---|
| .quote 수신(성공) | VM:113 | 보장 |
| .error 수신(.authFailed/.loadFailed) | VM:128 (switch 진입 전) | 보장 |
| .connection(true) 수신 | VM:123 | 보장 (행5 보강 포함) |

세 경로 모두 `isRefreshing = false` 명시 확인. 스피너 무한 회전(R2) 방지 구현.

## 기준 6: retry() 완전 삭제 확인

- `func retry()` 정의: 0건 (`grep -n "func retry"` → 없음)
- `retry()` 호출: 0건 (`grep -rn "retry()" App/` → 주석 2건만, 함수 정의/호출 0건)
- `MarketStatusHeader` `onRetry` 배선: `{ viewModel.refresh() }` (Header:15) — retry 아닌 refresh 배선 확인

## Units & Signs Audit (Task 3 해당분)

| function | input unit | output unit | sign convention | test proving it |
|---|---|---|---|---|
| `refresh()` 중복 가드 | 연속 호출 N회(bool flag) | service.start 호출 count | count==1 불변식 (guard !isRefreshing) | T-VM9 (Task 4 예정) |
| 선리셋 경계 | state enum | state enum | .normal이면 유지 / 그 외 .loading | T-VM7(normal 유지)·T-VM1(.loading) (Task 4 예정) |
| isRefreshing 해제 경계 | 종료 이벤트(.quote/.error/.connection(true)) | isRefreshing bool | 모든 종료 경로에서 false | T-VM2/3/5 (Task 4 예정) |

수치 변환(ms↔s / ×10^6 / 부호) 해당 없음. 가드 count 단언은 Task 4 단위 테스트로 잠금 (SPRINT_PLAN 설계).

## 최종 Verdict

**PASS**

- 기준 1(xcodegen): PASS
- 기준 2(빌드): PASS — BUILD SUCCEEDED
- 기준 3(회귀): PASS — 46/46
- 기준 4(매트릭스 커버리지): PASS — 11행 전 반영, 빈 셀 0건, 행5 보강 재확인 닫힘
- 기준 5(isRefreshing 해제): PASS — .quote/.error/.connection(true) 3경로 보장
- 기준 6(retry 삭제): PASS — 함수 정의 0건, 호출 0건

치명적 이슈 0건. Task 4 의존 항목(T-VM1~10 단위 테스트 단언)은 설계 범위대로 Task 4에서 잠금.

## Next Step

- Task 4 (`Tests/AppTests/WatchlistViewModelRefreshTests.swift`) — T-VM1~10 단위 테스트 작성 및 실행. T-VM5는 `wsDisconnected → refresh → .connection(true)` 단독(quote 미도착) 케이스를 단언으로 잠글 것 (reviewer 권고 — 행5 코드 보강 회귀 방지 안전망).
- Task 5 — `MarketStatusHeader` refreshButton 본체 + authFailed 배너 문구 변경.
