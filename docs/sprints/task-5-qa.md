---
task: 5
title: MarketStatusHeader 새로고침 버튼 배선 (T7)
date: 2026-06-02
verdict: PASS
---

# Task 5 QA 리포트

## 검증 범위 요약

| 범위 | 방법 | 결과 |
|---|---|---|
| 빌드 통과 | xcodebuild build | PASS |
| PMCore 단위 테스트 회귀 | swift test | 46/46 PASS |
| AppTests 회귀 (WatchlistViewModelRefreshTests) | xcodebuild test + fresh derivedDataPath | 11/11 PASS |
| V16 정적 검증 (refreshButton 표시 조건 코드) | 코드 분석 | PASS |
| V11~V15, V17 라이브 검증 | 오너 Xcode 수동 게이트 (자동 루프 밖) | 이관 |
| V18 [KIS 후] 외부망 검증 | KIS 이식 후 보류 | N/A |
| 브라우저 검증 (claude-in-chrome) | macOS 네이티브 앱 — 비대상 | N/A |

## 수용 기준 표 (proposal.md)

| # | 수용 기준 | 판정 | 검증 방법 | 비고 |
|---|---|---|---|---|
| 1 | authFailed 상태에서 헤더 새로고침 버튼 → 앱 재시작 없이 .normal 복귀 | 이관 | V11 오너 수동 | 장중 토큰 실패 유도 필요 |
| 2 | refresh() 호출 시 state 선리셋 → quote 도착 시 막힌 상태에서도 .normal 복귀 | PASS | T-VM1(testV1), T-VM2(testV2) | 코드 + 단위 테스트 확인 |
| 3 | 새로고침 진행 중 스피너/비활성 노출 + 연타해도 service.start 중복 미호출 | PASS (정적+단위) | T-VM9(testV9) 중복 가드 / V12 오너 시각 확인 이관 | 로직 PASS, 시각 이관 |
| 4 | wifi off→on 토글 → NWPathMonitor 복구 감지 → 자동 refresh() + 시세 갱신 | 이관 | V13 오너 수동 | wifi 토글 필요 |
| 5 | .normal에서 새로고침 → 시세 갱신만, 화면 깨짐/빈화면 없음 | PASS | T-VM7(testV7) | 캐시 불변 단언 |
| 6 | loadFailed 배너 "다시 시도" → refresh() 호출 + 캐시 유지 | PASS | T-VM6(testV6) | onRetry→refresh() 배선 코드 + 단위 테스트 |
| 7 | P2 자동 복구 시 P1과 동일한 스피너 노출 | 이관 | V13 오너 수동 | NWPath 자동 경로 시각 확인 |
| 8 | [KIS 후] 외부망 wifi 전환/sleep/wake → 자동 새로고침 복귀 | N/A | V18 — KIS 이식 후 | Premise 5 수용 조건 |

## 빌드 결과

```
xcodegen generate → Created project at PARAGON-MB.xcodeproj
xcodebuild -scheme PARAGON-MB -configuration Debug build ... → ** BUILD SUCCEEDED **
```

로그: `/tmp/qa-task5-build-1780378954.log`

## 테스트 결과

### PMCore — swift test

```
Executed 46 tests, with 0 failures (0 unexpected) in 0.044 seconds
```

로그: `/tmp/qa-task5-swifttest-1780379002.log`

회귀: 0건. T7 UI 변경(MarketStatusHeader)이 PMCore 단위 테스트에 영향 없음 확인.

### AppTests — xcodebuild test (fresh derivedDataPath)

```
derivedDataPath: /tmp/qa-task5-dd-1780379172
Executed 11 tests, with 0 failures (0 unexpected) in 0.180 seconds
** TEST SUCCEEDED **
```

로그: `/tmp/qa-task5-apptest-1780379172.log`

| 테스트 | 결과 | 대응 검증 항목 |
|---|---|---|
| testV1_authFailedThenRefresh_setsLoadingAndIsRefreshing | PASS | V1 (T-VM1) |
| testV2_afterRefresh_quoteApply_returnsNormal | PASS | V2 (T-VM2) |
| testV3_afterRefresh_errorAuthFailed_resetsIsRefreshing | PASS | V3 (T-VM3) |
| testV4_wsDisconnectedThenRefresh_setsLoading | PASS | V4 (T-VM4) |
| testV5_connectionTrueAlone_closesRefreshingSpinner | PASS | V4 (T-VM5, ★행5 단독복귀) |
| testV6_loadFailedRetry_clearsBannerAndPreservesCache | PASS | V5 (T-VM6) |
| testV7_normalRefresh_stateUnchangedAndCachePreserved | PASS | V6 (T-VM7) |
| testV8_loadingStateRefresh_setsIsRefreshingSafely | PASS | V7 (T-VM8) |
| testV9_tripleRefresh_serviceStartCalledOnce | PASS | V8 (T-VM9) |
| testV10_emptySymbols_refreshDoesNotTriggerServiceStart | PASS | V9 (T-VM10) |
| AppSmokeTests (스모크) | PASS | 인프라 |

## V16 정적 검증 — refreshButton 표시 조건

### 검사 결과

**1. headerRow 내 조건부 표시**

```swift
// MarketStatusHeader.swift L26-41
if isAdding {
    // "종목 추가" 텍스트만 — refreshButton 없음
} else {
    // statusText, badge, ...
    if !viewModel.symbols.isEmpty {
        refreshButton          // symbols 1건 이상일 때만 렌더
    }
    addButton
}
```

- `isAdding == true` (addViewModel != nil): else 분기 미진입 → refreshButton 미렌더. **isAdding 조건 충족**.
- `symbols.isEmpty == true` (EmptyState, state == .empty): `if !viewModel.symbols.isEmpty` 불통과 → refreshButton 미렌더. **EmptyState 조건 충족**.

**2. refresh() 내 이중 가드**

```swift
// WatchlistViewModel.swift L202
guard !symbols.isEmpty else { return }
```

UI 미노출과 독립적으로, refresh() 자체도 symbols 0건에서 service.start 미호출. testV10으로 단언됨.

**3. authFailed 문구 변경 확인**

```swift
// MarketStatusHeader.swift L191
case .authFailed: return "인증이 만료되었습니다 — 새로고침해 주세요"
```

구 문구 "앱 재시작" 없음. Spec Patch `[~]` authFailed 문구 적용 확인.

**4. AlertBanner onRetry 배선 확인**

```swift
// MarketStatusHeader.swift L15
AlertBanner(kind: banner, onRetry: { viewModel.refresh() })
```

`viewModel.retry()` → `viewModel.refresh()` 흡수 완료. Spec Patch `[~]` onRetry 적용 확인.

**5. refreshButton 스펙 충족 항목**

| 항목 | 코드 위치 | 확인 |
|---|---|---|
| arrow.clockwise 아이콘 | L59 | 확인 |
| isRefreshing 시 ProgressView 전환 | L54-55 | 확인 |
| frame 22×22 | L57, L61 | 확인 |
| PMColor.sapphire 전경색 | L60 | 확인 |
| border overlay (RoundedRectangle) | L65 | 확인 |
| disabled(viewModel.isRefreshing) | L66 | 확인 |
| accessibilityLabel "새로고침"/"새로고침 중" | L67 | 확인 |
| .keyboardShortcut("r", .command) | L68 | 확인 |
| headerRow addButton 직전 삽입 | L40-43 | 확인 |

**V16 정적 판정**: PASS (320pt 1줄 레이아웃 시각 확인 + isRefreshing 스피너 시각은 오너 게이트 이관).

## 브라우저 검증 — N/A

PARAGON-MB는 macOS 네이티브 메뉴바 앱(SwiftUI/AppKit)이다. 웹/브라우저 대상이 아니며 claude-in-chrome MCP 브라우저 검증은 비대상(N/A). 시각 검증 전체는 오너 Xcode 수동 게이트(V11~V17)로 이관.

## 라이브/수동 검증 이관 항목 (sprint 자동 루프 밖)

아래 항목은 장중 실데이터·authFailed 유도·wifi 토글이 필요해 자동화 불가. 오너 Xcode 수동 게이트 범위.

| 항목 | 내용 | 수용 기준 |
|---|---|---|
| V11 | authFailed 유도 → 헤더 버튼 → 재시작 없이 .normal 복귀 | 1 |
| V12 | 진행 중 스피너+disabled + 연타 무반응 (시각) | 3 |
| V13 | wifi off→on → 자동 refresh + 스피너 노출 | 4, 7 |
| V14 | .normal 에서 새로고침 → 화면 안 깨짐 캐시 유지 (시각) | 5 |
| V15 | loadFailed 배너 "다시 시도" → 배너 사라짐 + 스피너 → 복귀 (시각) | 6 |
| V16 시각 | 320pt 헤더 1줄 수용(상태텍스트 truncation 허용) + isAdding/EmptyState 버튼 숨김 (시각) | — |
| V17 | .transient 닫힘→재오픈 스피너 즉시 복원 | — |

## Units & Signs Audit

본 Task 5 변경(UI 배선)은 수치 변환(ms↔s·스케일·부호·통화·퍼센트) 없음.

| 대상 | 입력 | 출력 | 불변식 | 검증 | N/A 사유 |
|---|---|---|---|---|---|
| 수치 변환 일체 | — | — | — | — | MarketStatusHeader는 순수 UI 배선. 숫자 연산 없음 |
| isRefreshing 생명주기 (Task 3 계승) | refresh 시작 → 결과 | true→false | .quote·.error 양쪽 false 복귀 | testV2, testV3 | Task 3/4 검증 계승, 회귀 확인 |
| 중복 가드 (Task 3 계승) | 연속 호출 N회 | start 1회 | N≥1 → 정확히 1회 | testV9 | Task 3/4 검증 계승 |

**Audit 판정**: N/A (수치 변환 없음) — 기존 불변식 회귀 0 확인.

## 최종 판정

**PASS**

- 빌드: BUILD SUCCEEDED
- PMCore 회귀: 46/46 (0 failures)
- AppTests 회귀: 11/11 (0 failures, fresh derivedDataPath 캐시 우회)
- V16 정적: PASS (refreshButton 표시 조건·스펙 항목 전수 확인)
- 브라우저 검증: N/A (macOS 네이티브 앱)
- 라이브 V11~V17: 오너 Xcode 수동 게이트 이관 (sprint 자동 루프 밖)
- Write 권한 경계 위반: 0건 (제품 로직 파일 수정 없음)
