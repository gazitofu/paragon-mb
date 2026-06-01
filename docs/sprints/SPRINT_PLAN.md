# Sprint Plan

## Meta
- 생성일: 2026-06-01
- 기능: refresh-recovery (새로고침 / 자동복구)
- PRD: /Users/gazitofu/Vault/appdev/PARAGON-MB/prd/refresh-recovery/
- 모드: Standard  (Auto-Strict 트리거 전무 — schema/auth-logic/destructive/deploy/dependency 없음. authFailed "복구 트리거" 변경이지 auth 로직 변경 아님)
- 상태: in-progress
- 승인된 Spec 편차 (사용자 게이트 2026-06-01):
  - ① VM 테스트 위치: tasks.md T9 `Tests/PMCoreTests/WatchlistViewModelRefreshTests.swift` → **`Tests/AppTests/WatchlistViewModelRefreshTests.swift`**. 이유: `WatchlistViewModel`은 App 타겟(PMCore 모듈 아님)이라 PMCoreTests가 `@testable import` 불가. → Xcode App용 unit test 타겟 신설로 해소.
  - ② `project.yml`에 Xcode unit test 타겟 `PARAGON-MBTests` 신설 (design.md affects 외 — 빌드 인프라). 실행 = `xcodebuild test -scheme PARAGON-MB`.
- Phase 2 docs 갱신(표준): 마무리에서 architecture.md 1줄(WatchlistViewModel refresh + NetworkPathReachability 컴포넌트) 갱신 예정.

## Tasks

### Task 1: NetworkPathReachability 어댑터 + 단위 테스트 (T1+T8)
- 유형: implement
- 상태: done
- 담당: developer
- 의존: 없음
- 시도: 1
- 산출물: Sources/PMCore/Network/NetworkPathReachability.swift (신규) · Tests/PMCoreTests/NetworkPathReachabilityTests.swift (신규)
- 검증: V10 (T-NW1 최초 satisfied 콜백 0회 / T-NW2 unsatisfied→satisfied 1회), `swift test`
- commit: (미정)

### Task 2: Xcode unit test 타겟 신설 (인프라 — 편차②)
- 유형: implement
- 상태: pending
- 담당: developer
- 의존: 없음
- 시도: 1
- 산출물: project.yml (PARAGON-MBTests 타겟 + 스킴 test action) · Tests/AppTests/ 디렉토리 + 스모크 테스트 1건
- 검증: `xcodegen generate` 성공 + `xcodebuild test -scheme PARAGON-MB` 스모크 PASS (새 테스트 파이프라인 동작 입증)
- commit: (미정)

### Task 3: WatchlistViewModel refresh 상태기계 (T2~T6)
- 유형: implement
- 상태: pending
- 담당: developer
- 의존: task-1 (NetworkReachability protocol)
- 시도: 1
- 산출물: App/ViewModels/WatchlistViewModel.swift
- 내용: isRefreshing 플래그(T2) · refresh()(T3) · reachability init/start/deinit 배선(T4) · apply 복귀조건·error isRefreshing=false(T5) · retry() 삭제(T6)
- 검증: Task 4 단위 테스트로 잠금 (빌드 통과는 본 태스크)
- commit: (미정)

### Task 4: WatchlistViewModel refresh 단위 테스트 (T9, 편차①)
- 유형: implement
- 상태: pending
- 담당: developer
- 의존: task-2 (test 타겟) · task-3 (VM 로직)
- 시도: 1
- 산출물: Tests/AppTests/WatchlistViewModelRefreshTests.swift (신규) — mock NetworkReachability · mock QuoteServicing 주입
- 검증: V1~V9 (T-VM1~10), `xcodebuild test -scheme PARAGON-MB`. Units&Signs Audit 3행(중복가드/생명주기/edge)
- commit: (미정)

### Task 5: MarketStatusHeader 새로고침 버튼 배선 (T7)
- 유형: implement
- 상태: pending
- 담당: developer
- 의존: task-3 (refresh()/isRefreshing)
- 시도: 1
- 산출물: App/Views/MarketStatusHeader.swift
- 내용: refreshButton(arrow.clockwise↔ProgressView, disabled(isRefreshing), ⌘R, 조건부 표시) · headerRow 삽입 · AlertBanner onRetry→refresh() · authFailed 문구 변경
- 검증: 빌드 통과 + V16 헤더 1줄 레이아웃 정성 확인. V11~V17 라이브 QA는 코드 완료 후 오너 Xcode 수동 게이트
- commit: (미정)

## 라이브/수동 검증 (코드 완료 후 오너 Xcode 게이트 — sprint 자동 루프 밖)
- V11 authFailed→새로고침 버튼→재시작 없이 복귀 (수용 1)
- V12 진행 중 스피너+disabled+연타 무반응 (수용 3)
- V13 동일망 wifi off→on→자동 refresh+스피너 (수용 4·7)
- V14 normal 새로고침 화면 안깨짐 캐시 유지 (수용 5)
- V15 loadFailed 배너 재시도 캐시 유지 (수용 6)
- V16 320pt 헤더 1줄 수용 + V1/isAdding 시 버튼 숨김
- V17 .transient 닫힘→재오픈 스피너 복원
- V18 [KIS 후] 외부망 전환 IP 변경 자동 복귀 (수용 8) — 보류
