# Sprint Plan

## Meta
- 생성일: 2026-06-01
- 기능: refresh-recovery (새로고침 / 자동복구)
- PRD: /Users/gazitofu/Vault/appdev/PARAGON-MB/prd/refresh-recovery/
- 모드: Standard  (Auto-Strict 트리거 전무 — schema/auth-logic/destructive/deploy/dependency 없음. authFailed "복구 트리거" 변경이지 auth 로직 변경 아님)
- 상태: done  (전 태스크 T1~T5 done — 2026-06-02 마무리)
- 승인된 Spec 편차 (사용자 게이트 2026-06-01):
  - ① VM 테스트 위치: tasks.md T9 `Tests/PMCoreTests/WatchlistViewModelRefreshTests.swift` → **`Tests/AppTests/WatchlistViewModelRefreshTests.swift`**. 이유: `WatchlistViewModel`은 App 타겟(PMCore 모듈 아님)이라 PMCoreTests가 `@testable import` 불가. → Xcode App용 unit test 타겟 신설로 해소. **(마무리에서 tasks.md/design.md 본문 경로 정정 완료 2026-06-02)**
  - ② `project.yml`에 Xcode unit test 타겟 `PARAGON-MBTests` 신설 (design.md affects 외 — 빌드 인프라). 실행 = `xcodebuild test -scheme PARAGON-MB`.
- Phase 2 docs 갱신(표준): 마무리에서 architecture.md WatchlistViewModel refresh + NetworkPathReachability 컴포넌트 갱신 완료(2026-06-02). API_SPEC/DB_SCHEMA는 change_type=표준이라 영향 없음(SSOT 동기화 검증 통과).
- 라이브/수동 검증 잔여: V11~V17 오너 Xcode 수동 게이트(자동 루프 밖, 장중 09:00–15:30 KST 일부 필요).

## Tasks

### Task 1: NetworkPathReachability 어댑터 + 단위 테스트 (T1+T8)
- 유형: implement
- 상태: done
- 담당: developer
- 의존: 없음
- 시도: 1
- 산출물: Sources/PMCore/Network/NetworkPathReachability.swift (신규) · Tests/PMCoreTests/NetworkPathReachabilityTests.swift (신규)
- 검증: V10 (T-NW1 최초 satisfied 콜백 0회 / T-NW2 unsatisfied→satisfied 1회), `swift test` — PASS 34/34
- commit: 18c432e (feat) + d54f1d2 (docs)

### Task 2: Xcode unit test 타겟 신설 (인프라 — 편차②)
- 유형: implement
- 상태: done
- 담당: developer
- 의존: 없음
- 시도: 2
- 산출물: project.yml (PARAGON-MBTests 타겟 + 스킴 test action) · Tests/AppTests/ 디렉토리 + 스모크 테스트 1건
- 검증: `xcodegen generate` 성공 + `xcodebuild test -scheme PARAGON-MB` 스모크 1/1 PASS (fresh DerivedData 캐시 우회 확인) — attempt 2 PASS (attempt 1: GENERATE_INFOPLIST_FILE 누락으로 FAIL)
- commit: 44f47d2 (feat) + 444f372 (docs)

### Task 3: WatchlistViewModel refresh 상태기계 (T2~T6)
- 유형: implement
- 상태: done
- 담당: developer
- 의존: task-1 (NetworkReachability protocol)
- 시도: 1
- 산출물: App/ViewModels/WatchlistViewModel.swift (+ MarketStatusHeader.swift onRetry→refresh() 1행, 빌드 유지)
- 내용: isRefreshing 플래그(T2) · refresh()(T3) · reachability init/start/deinit 배선(T4) · apply 복귀조건·error isRefreshing=false(T5) · retry() 삭제(T6) + 보강: 행5 .connection(true) 단독 복귀 가드(isRefreshing && .loading)
- 검증: BUILD SUCCEEDED + swift test 46/46 회귀 0 + 계약 매트릭스 11행 반영 (전이 단언은 Task 4). reviewer 행5 닫힘 PASS
- commit: 84df48b (feat) + ef52323 (docs)

### Task 4: WatchlistViewModel refresh 단위 테스트 (T9, 편차①)
- 유형: implement
- 상태: done
- 담당: developer
- 의존: task-2 (test 타겟) · task-3 (VM 로직)
- 시도: 1 (developer inner loop 3회)
- 산출물: Tests/AppTests/WatchlistViewModelRefreshTests.swift (신규, testV1~testV10)
- 검증: V1~V9 (T-VM1~10) PASS — AppTests 10/10 + PMCore 46/46 회귀 0 (`xcodebuild test`/`swift test`, fresh derivedDataPath 캐시 우회). reviewer 치명 0 PASS(★V5 단독복귀 fake-green 아님 확인), qa 독립 재실행 PASS. Units&Signs Audit 3행(중복가드 V9/생명주기 V2·V3/행5 단독복귀 V5)
- 권장 cleanup(후속): drainTasks() sleep 5ms → 결정론적 신호 / line 197 MARK `★V4`→`★V5` 오기 / design·tasks 문서 경로 `Tests/PMCoreTests/`→`Tests/AppTests/` 정정(승인 편차①, 마무리 단계)
- commit: 86f4771 (test) + 1809e1a (docs)

### Task 5: MarketStatusHeader 새로고침 버튼 배선 (T7)
- 유형: implement
- 상태: done
- 담당: developer
- 의존: task-3 (refresh()/isRefreshing)
- 시도: 1
- 산출물: App/Views/MarketStatusHeader.swift (refreshButton 신규 + headerRow addButton 직전 삽입 + AlertBanner .authFailed 문구 변경) · docs/OPERATIONAL_NOTES.md (+1줄)
- 내용: refreshButton(arrow.clockwise↔ProgressView, disabled(isRefreshing), ⌘R, 조건부 표시) · headerRow 삽입 · AlertBanner onRetry→refresh() · authFailed 문구 변경
- 검증: BUILD SUCCEEDED + swift test 46/46 회귀 0 + xcodebuild test AppTests 11/11(fresh derivedDataPath 캐시 우회) 회귀 0. reviewer 치명 0(T7 7속성 7/7, 경계규칙 ⓐ 통과). qa PASS(V16 정적 검증 — EmptyState/isAdding 미렌더 로직). V11~V17 라이브 QA는 오너 Xcode 수동 게이트(자동 루프 밖)
- commit: 1b3a46b (feat) + {docs SHA 마무리 후 기록}

## 라이브/수동 검증 (코드 완료 후 오너 Xcode 게이트 — sprint 자동 루프 밖)
- V11 authFailed→새로고침 버튼→재시작 없이 복귀 (수용 1)
- V12 진행 중 스피너+disabled+연타 무반응 (수용 3)
- V13 동일망 wifi off→on→자동 refresh+스피너 (수용 4·7)
- V14 normal 새로고침 화면 안깨짐 캐시 유지 (수용 5)
- V15 loadFailed 배너 재시도 캐시 유지 (수용 6)
- V16 320pt 헤더 1줄 수용 + V1/isAdding 시 버튼 숨김
- V17 .transient 닫힘→재오픈 스피너 복원
- V18 [KIS 후] 외부망 전환 IP 변경 자동 복귀 (수용 8) — 보류
