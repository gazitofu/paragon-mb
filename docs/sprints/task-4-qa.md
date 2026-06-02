---
task: T9 (V1~V9 단위 테스트 — WatchlistViewModelRefreshTests)
sprint: refresh-recovery
date: 2026-06-02
verdict: PASS
---

# Task 4 QA — WatchlistViewModelRefreshTests (V1~V9)

## 1. 수용 기준 표

| # | 수용 기준 (proposal.md) | 대응 검증 ID | 결과 |
|---|---|---|---|
| 1 | authFailed에서 새로고침 버튼 → 앱 재시작 없이 .normal 복귀 | V2 (T-VM2) | **pass** |
| 2 | refresh() 호출 시 state 선리셋 → quote 도착 시 막힌 상태에서도 .normal 복귀 | V1 (T-VM1), V2 (T-VM2), V4 (T-VM4/T-VM5) | **pass** |
| 3 | 진행 중 헤더 진행 표시 + 연타 시 service.start 중복 미호출 | V8 (T-VM9) | **pass** |
| 4 | NWPathMonitor 복구 감지 → refresh() 자동 호출 | V10 (T-NW1/T-NW2 — T8 소관, 별도 PMCoreTests) | N/A (T8 범위) |
| 5 | normal에서 새로고침 → 시세 갱신만, 화면 깨짐/빈화면 없음 | V6 (T-VM7) | **pass** |
| 6 | loadFailed 배너 "다시 시도" → refresh() 호출, 캐시값 유지 회귀 없음 | V5 (T-VM6) | **pass** |
| 7 | P2 자동 복구 시 P1과 동일 진행 표시 노출 | V11~V13 (라이브 게이트) | **이월** |
| 8 | [KIS 후] 외부망 wifi 전환/sleep-wake 후 자동 새로고침 | V18 (KIS 후) | **이월** |

수용 기준 4번(NWPathMonitor 어댑터) = T8(NetworkPathReachabilityTests) 소관 — 이미 done. 수용 기준 7·8번 = 라이브/KIS 검증 이월(아래 §4 참조).

## 2. 검증 항목 매핑 (V1~V9)

| 검증 ID | 테스트 함수 | 상태·이벤트 계약 행 | 실행 결과 |
|---|---|---|---|
| V1 (T-VM1) | testV1_authFailedThenRefresh_setsLoadingAndIsRefreshing | 행1: authFailed→refresh→state==.loading && isRefreshing | **pass** (0.014s) |
| V2 (T-VM2) | testV2_afterRefresh_quoteApply_returnsNormal | 행2: authFailed→refresh→.quote→state==.normal && !isRefreshing | **pass** (0.019s) |
| V3 (T-VM3) | testV3_afterRefresh_errorAuthFailed_resetsIsRefreshing | 행3: authFailed→refresh→.error(.authFailed)→state==.authFailed && !isRefreshing | **pass** (0.020s) |
| V4 (T-VM4) | testV4_wsDisconnectedThenRefresh_setsLoading | 행4: wsDisconnected→refresh→state==.loading | **pass** (0.020s) |
| V4 (T-VM5) ★ | testV5_connectionTrueAlone_closesRefreshingSpinner | 행5: wsDisconnected→refresh→.connection(true) 단독→state==.normal && !isRefreshing | **pass** (0.026s) |
| V5 (T-VM6) | testV6_loadFailedRetry_clearsBannerAndPreservesCache | 행6: loadFailed→refresh→loadFailed==false && quotes 불변 | **pass** (0.027s) |
| V6 (T-VM7) | testV7_normalRefresh_stateUnchangedAndCachePreserved | 행7: normal→refresh→state==.normal && quotes 불변 | **pass** (0.021s) |
| V7 (T-VM8) | testV8_loadingStateRefresh_setsIsRefreshingSafely | 행8: loading→refresh→isRefreshing set, 크래시 없음 | **pass** (0.008s) |
| V8 (T-VM9) | testV9_tripleRefresh_serviceStartCalledOnce | 행9: refresh×3→service.start count==1 | **pass** (0.015s) |
| V9 (T-VM10) | testV10_emptySymbols_refreshDoesNotTriggerServiceStart | 행10: symbols 0건→refresh→service.start count==0 | **pass** (0.015s) |

## 3. 테스트 실행 결과

### PMCore SPM (swift test — 회귀 확인)

```
Executed 46 tests, with 0 failures (0 unexpected) in 0.039 seconds
```

PMCoreTests 46/46 전원 통과. NetworkPathReachabilityTests(T-NW1/T-NW2) 포함.

### Xcode 앱 타깃 (xcodebuild — fresh derivedDataPath)

```
xcodebuild test -scheme PARAGON-MB \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/pmb-t4-qa-dd
```

```
Test Suite 'WatchlistViewModelRefreshTests' passed
  Executed 10 tests, with 0 failures in 0.183 seconds

Test Suite 'All tests' passed
  Executed 11 tests, with 0 failures in 0.184 seconds

** TEST SUCCEEDED **
```

로그 경로: `/tmp/pmb-t4-qa-1780363394.log` (142,135 bytes, mtime 2026-06-02 10:27:01)

### ★V5 (T-VM5) 단독 복귀 확인

`testV5_connectionTrueAlone_closesRefreshingSpinner` — wsDisconnected→refresh→`.connection(true)` 단독(`.quote` 미도착)→`state==.normal && !isRefreshing` 단언 **통과** (0.026s). 행5 회귀 잠금 확인.

## 4. 라이브 검증 이월 (범위 밖 명시)

아래 항목은 코드(T4·T5) 완료 후 오너 수동 Xcode 실행 게이트이며, 본 태스크(T9 단위 테스트) 범위 밖이다. sprint 자동 루프 밖 — conductor는 이월로 처리.

- **V11**: authFailed 유도 → 헤더 새로고침 버튼 → 앱 재시작 없이 .normal 복귀 (수용기준 1)
- **V12**: 진행 중 스피너 노출 + 연타 무반응 가시 확인 (수용기준 3)
- **V13**: wifi off→on → NWPathMonitor 자동 refresh + 스피너 노출 (수용기준 4·7)
- **V14**: normal에서 새로고침 → 빈화면·깜빡임 없음 (수용기준 5)
- **V15**: loadFailed 배너 "다시 시도" → 캐시 유지 회귀 없음 (수용기준 6)
- **V16**: 320pt 헤더 레이아웃 회귀 + EmptyState·isAdding 버튼 숨김
- **V17**: .transient 팝오버 닫힘 → 재오픈 시 스피너 즉시 복원
- **V18**: [KIS 후] 외부망 wifi 전환/sleep-wake → 자동 새로고침 (수용기준 8)

## 5. V10 (어댑터 transition-edge) 범위 확인

V10 (T-NW1/T-NW2) = T8(NetworkPathReachabilityTests) 소관 — 이미 done. `swift test` 실행에서 NetworkPathReachabilityTests 포함 46/46 통과 확인. 본 태스크 범위 아님.

## 6. Units & Signs Audit

tasks.md §Units & Signs Audit 기준:

| 대상 | 입력 | 출력 | 불변식 | 검증 |
|---|---|---|---|---|
| refresh() 중복 가드 | 연속 호출 N회 | service.start 트리거 횟수 | N≥1 → 정확히 1회 | T-VM9 (pass) |
| isRefreshing 생명주기 | refresh 시작 → 결과 도착 | true→false 전이 | .quote·.error 양쪽에서 false 복귀 | T-VM2·T-VM3 (pass) |
| NWPath transition-edge | path status 시퀀스 | onRecovered 콜백 횟수 | satisfied edge당 1회, 최초 satisfied 0회 | T-NW1·T-NW2 (T8 소관, pass) |

수치 변환(ms↔s·스케일·부호) 없음 — Audit 항목 전원 검증 통과.

## 7. 브라우저 검증

본 앱 = macOS 네이티브 메뉴바 앱(NSPopover 기반 SwiftUI). 웹 UI 없음 → 브라우저 검증 부적용. 변경 파일에 `.tsx`/`.jsx`/`.css` 없음 — MCP 브라우저 검증 게이트 해당 없음.
