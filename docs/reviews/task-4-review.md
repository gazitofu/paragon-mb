# 코드 리뷰 리포트 — Task 4 (VM refresh 단위 테스트, tasks.md T9 / V1~V9)

## 전체 평가

PASS. `WatchlistViewModelRefreshTests.swift`의 testV1~testV10 9개 메서드가 design.md 상태·이벤트 계약 행1~10을 실제 VM `apply()`/`refresh()` 경로를 통해 단언하며, 가짜 통과(fake green) 없음. mock `QuoteServicing`이 실제 `AsyncStream` continuation을 통해 이벤트를 주입하고 VM의 `subscribeUpdates()`→`apply()`가 이를 소비하므로 단언이 진짜 상태기계를 검증한다. ★V5(connection(true) 단독)는 quote 동시 주입 없이 행5 가드를 정확히 잠근다. 중복 가드 V9는 MainActor 동기 guard flip에 의존하므로 타이밍 비의존(non-flaky). 빌드·테스트 4회 연속 0 실패. Floor 3(기존 테스트 약화) 위반 0건. 치명 이슈 없음. 권장 1·참고 2건만 존재 — 별도 cleanup으로 분리.

## 발견된 이슈

### [참고] 1. 테스트 파일 경로가 design.md/tasks.md 선언과 불일치 (실제 배치가 옳음)
- 위치: `Tests/AppTests/WatchlistViewModelRefreshTests.swift` (실제) vs design.md:416 / tasks.md:22 선언 `Tests/PMCoreTests/WatchlistViewModelRefreshTests.swift`
- 문제: 문서는 PMCoreTests에 두라고 했으나, `WatchlistViewModel`은 App 타겟 소속(Module Map design.md:348 = Hook 레이어, App/ViewModels/)이고 테스트가 `@testable import PARAGON_MB`(line 3)를 쓰므로 PMCoreTests에서는 import 불가. 따라서 **AppTests 배치가 기술적으로 정확**하고 문서 경로가 틀렸다.
- 수정 제안: 코드 수정 불요. design.md frontmatter `affects`(line 10) 및 Spec Patch(line 416)·tasks.md T9의 경로를 `Tests/AppTests/`로 정정. 이는 architect 영역 문서 수정이므로 reviewer가 직접 고치지 않고 conductor에 정정 권고로 전달. (계약 정합성 검증 자체는 영향 없음 — 단언 내용은 모두 충족.)

### [권장] 2. sleep 기반 drainTasks 동기화 — 현재 안정적이나 잠재적 취약점
- 위치: `WatchlistViewModelRefreshTests.swift:88-92` (`drainTasks()`), OPERATIONAL_NOTES.md:18 패턴 기록
- 현재 코드: `Task.yield()×20 + Task.sleep(5ms) + Task.yield()×10`
- 문제: MainActor for-await 스트림 소비 Task의 hop을 고정 5ms sleep으로 대기한다. 4회 연속 실행에서 0 실패였고, 핵심 단언(상태 전이)은 동기 MainActor 코드라 race 없음 — 따라서 **치명적 아님(권장 수준)**. 다만 sleep 기반 동기화는 CI 부하·느린 머신에서 이론적 flaky 여지가 있다(이벤트가 5ms 내 소비 안 되면 단언이 빈 상태를 봄). 실측 race는 관측되지 않았다.
- 수정 제안(후속 cleanup, 이번 PASS 차단 아님): continuation 소비 완료를 결정론적으로 알리는 신호(예: VM의 `@Published` 변화 await, 또는 expectation/AsyncStream 종료 신호)로 대체하면 sleep 의존 제거 가능. 현재 릴리스에서는 4회 안정 + 동기 단언 특성상 유지 허용.

### [참고] 3. 주석 라벨 오기 — `★V4` 표기
- 위치: `WatchlistViewModelRefreshTests.swift:197` MARK 주석 `// MARK: - ★V4 (T-VM5)`
- 문제: 메서드는 testV5(T-VM5)인데 MARK 주석 헤더가 `★V4`로 적힘. 코드 동작 무관, 가독성만 영향.
- 수정 제안: `★V5 (T-VM5)`로 정정(별도 cleanup). 단언·로직 영향 0.

## 중점 검토 항목 판정

1. **계약 정합 (행1~10)**: 충족. testV1↔행1, V2↔행2, V3↔행3, V4↔행4, V5↔행5, V6↔행6, V7↔행7, V8↔행8, V9↔행9, V10↔행10 모두 매핑. mock이 실제 `AsyncStream`/`apply()` 경로를 타므로 fake green 아님.
2. **★V5(T-VM5) 단독 케이스**: 충족(엄격 확인 통과). testV5는 setup 단계에서만 quote를 주입(line 210, wsDisconnected 진입용), refresh 이후에는 `.connection(true)` 단독(line 220)만 주입. quote 동시 주입 우회 없음. VM:122 가드 `(isRefreshing && state == .loading)`이 선리셋(.loading)+isRefreshing 경로를 통해 .normal 복귀시키고 isRefreshing 해제 — T3 reviewer 보강 행5 가드의 회귀 잠금이 진짜로 검증됨.
3. **중복 가드 V9 flaky 여부**: 비-flaky. 3회 `vm.refresh()`는 MainActor 동기 호출이고 첫 호출이 `isRefreshing=true`(line 203)를 동기 set한 뒤 2·3번째가 동기 guard로 early return. `service.start` Task 스케줄 전에 guard가 닫히므로 count==1은 타이밍 비의존. 실측 4회 0 실패.
4. **테스트 신뢰성 (sleep+actor+@unchecked Sendable)**: 권장(개선 여지), 치명 아님. continuation.yield는 thread-safe하여 nonisolated emit/@unchecked Sendable 정당. 핵심 단언은 동기 MainActor라 race 없음. sleep 의존만 후속 개선 권장(이슈 2).
5. **Floor 3 (기존 테스트 삭제·약화)**: 위반 0건. `git diff --stat -- Tests/` 결과 추적 테스트 파일 변경 0, 신규 untracked 파일 1개(WatchlistViewModelRefreshTests.swift)만 추가.
6. **Units & Signs Audit**: 적정. 본 태스크는 수치 변환 없음. tasks.md §Units & Signs Audit 표의 3개 불변식(중복가드 N→1 / isRefreshing 생명주기 true→false / NWPath edge) 중 본 태스크 담당분(중복가드 T-VM9, isRefreshing T-VM2·T-VM3)이 해당 테스트로 증명됨. NWPath edge는 T-NW(Task 3 별 태스크) 소관.

## 요약
| 심각도 | 건수 |
|--------|------|
| 치명적 | 0건 |
| 권장 | 1건 (sleep 기반 동기화) |
| 참고 | 2건 (문서 경로 정정, MARK 오기) |

## 다음 단계
1. PASS — Step 3 qa(라이브 V11~V18) 진행 가능.
2. 후속 cleanup(이번 PASS 차단 아님): ① design/tasks 경로를 Tests/AppTests로 정정(architect/conductor), ② MARK ★V4→★V5 오기 수정, ③ (선택) drainTasks sleep 의존 결정론적 신호로 대체.
