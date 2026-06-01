# QA 리포트 — Task 2 (Xcode unit test 타겟 신설, 인프라)

- 일자: 2026-06-01
- 태스크: Task 2
- QA 시도: 2 (attempt 1 FAIL → developer 수정 → attempt 2)
- Verdict: **PASS**

## 1. 수용 기준 표

| # | 검증 기준 | 명령 | 결과 |
|---|---|---|---|
| 1 | `xcodegen generate` 성공 (EXIT=0) | `xcodegen generate` | **PASS** |
| 2 | `xcodebuild test -scheme PARAGON-MB` 스모크 PASS — `@testable import PARAGON_MB` 접근 입증 | `xcodebuild test -scheme PARAGON-MB -derivedDataPath /tmp/qa-task2-attempt2-derived` | **PASS** |
| 3 | PMCore `swift test` 회귀 없음 — 기존 베이스라인 유지 확인 | `swift test` | **PASS** |

## 2. 명령 실행 결과 (attempt 2)

### 기준 1 — `xcodegen generate` (PASS)

```
EXIT=0
⚙️  Generating plists...
⚙️  Generating project...
⚙️  Writing project...
Created project at /Users/gazitofu/Developer/PARAGON-MB/PARAGON-MB.xcodeproj
```

로그: `/tmp/qa-task2-attempt2-xcodegen-1780322645.log` (4줄)

### 기준 2 — `xcodebuild test -scheme PARAGON-MB` (PASS)

전용 `-derivedDataPath /tmp/qa-task2-attempt2-derived` 지정으로 캐시 우회. xcodegen generate 직후 실행.

```
Test Suite 'All tests' started at 2026-06-01 23:09:23.004.
Test Suite 'PARAGON-MBTests.xctest' started at 2026-06-01 23:09:23.005.
Test Suite 'AppSmokeTests' started at 2026-06-01 23:09:23.005.
Test Case '-[PARAGON_MBTests.AppSmokeTests testScreenStateAccessible]' started.
Test Case '-[PARAGON_MBTests.AppSmokeTests testScreenStateAccessible]' passed (0.001 seconds).
Test Suite 'AppSmokeTests' passed at 2026-06-01 23:09:23.006.
     Executed 1 test, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'PARAGON-MBTests.xctest' passed at 2026-06-01 23:09:23.006.
     Executed 1 test, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'All tests' passed at 2026-06-01 23:09:23.006.
     Executed 1 test, with 0 failures (0 unexpected) in 0.001 (0.002) seconds

** TEST SUCCEEDED **
```

로그: `/tmp/qa-task2-attempt2-xcodebuild-1780322941.log` (1099줄)

수정 사항: `project.yml` PARAGON-MBTests settings 블록에 `GENERATE_INFOPLIST_FILE: YES` 추가 (developer 수정, attempt 1 실패 원인 해소).

### 기준 3 — `swift test` (PASS)

```
Test Suite 'All tests' passed at 2026-06-01 23:09:59.378.
     Executed 46 tests, with 0 failures (0 unexpected) in 0.047 (0.049) seconds
```

- 총 테스트 케이스: 46건 PASS, 0건 FAIL
- 포함 스위트: KeychainStoreTests · MarketClockTests · NetworkPathReachabilityTests · PolicyTests · PriceDirectionTests · QuoteParsingTests · TokenManagerTests · WatchlistStoreTests
- 회귀 0건 (attempt 1 대비 동일)

로그: `/tmp/qa-task2-attempt2-swift-test-1780322998.log` (129줄)

## 3. Units & Signs Audit

인프라 태스크 — 수치 변환 없음. 해당 없음.

## 4. attempt 1 실패 이력

`/Users/gazitofu/Developer/PARAGON-MB/docs/sprints/failures/task-2-attempt-1.md` 참조.

실패 원인: `project.yml` PARAGON-MBTests settings에 `GENERATE_INFOPLIST_FILE: YES` 부재 → code sign 차단.
해소: developer가 해당 키 추가 → attempt 2에서 전 기준 PASS 확인.

## 5. Next Step

SPRINT_PLAN Task 2 `done` 마킹 → Task 3 (WatchlistViewModel refresh 상태기계) 진입.
