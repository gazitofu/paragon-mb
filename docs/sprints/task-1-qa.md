# QA 리포트 — refresh-recovery Task 1 (NetworkPathReachability)

- 일자: 2026-06-01
- 검증자: AppDev QA agent
- 대상: `Sources/PMCore/Network/NetworkPathReachability.swift` (신규), `Tests/PMCoreTests/NetworkPathReachabilityTests.swift` (신규)
- SSOT: `Vault/appdev/PARAGON-MB/prd/refresh-recovery/proposal.md` 수용 기준 / `tasks.md` V10
- UI 변경: 없음 (PMCore 순수 로직 + 테스트) → 브라우저 검증 불필요

---

## 1. 수용 기준 표 (V10 범위)

> Task 1 범위는 `NetworkPathReachability` 어댑터 단독 — T-NW1/T-NW2. 나머지 수용 기준(V1~V9, V11~V18)은 미구현 태스크(T2~T7/T9)에 해당하여 현 단계 N/A.

| ID | 수용 기준 | 결과 | 근거 |
|---|---|---|---|
| T-NW1 | 최초 satisfied 상태 → 복구 콜백 0회 | **PASS** | `testInitialSatisfiedDoesNotFireRecovery` PASS, `testConsecutiveSatisfiedDoesNotFireRecovery` PASS |
| T-NW2 | unsatisfied → satisfied 전이 → 복구 콜백 정확히 1회 | **PASS** | `testUnsatisfiedToSatisfiedFiresExactlyOnce` PASS |
| 역전이 발화 금지 | satisfied → unsatisfied → 콜백 0회 | **PASS** | `testSatisfiedToUnsatisfiedDoesNotFire` PASS |
| 복수 사이클 | 복구 2회 → 콜백 2회 | **PASS** | `testMultipleRecoveryCycles` PASS |
| requiresConnection 경계 | requiresConnection → satisfied → 콜백 1회 | **PASS** | `testRequiresConnectionToSatisfiedFiresOnce` PASS |
| 핸들러 미등록 | 핸들러 없을 때 크래시 없음 | **PASS** | `testNoHandlerRegistered` PASS |
| 수용기준 4 (NWPath 복구 감지 메커니즘) | T-NW1/T-NW2로 커버되는 어댑터 경계 계약 검증 | **PASS** | 위 전항 통과 |
| 수용기준 1·2·3·5·6·7·8 | VM/UI/라이브 검증 — Task 2~7/T9 미구현 | **N/A** | 현 단계 범위 밖 |

---

## 2. 테스트 실행 결과

### NetworkPathReachabilityTests (filter 실행)

```
swift test --filter NetworkPathReachabilityTests
LOG: /tmp/qa-task1-1780320144.log
EXIT=0

Test Suite 'NetworkPathReachabilityTests' passed at 2026-06-01 22:22:25.190
  testInitialSatisfiedDoesNotFireRecovery        PASSED (0.000s)
  testConsecutiveSatisfiedDoesNotFireRecovery    PASSED (0.001s)
  testUnsatisfiedToSatisfiedFiresExactlyOnce     PASSED (0.000s)
  testRequiresConnectionToSatisfiedFiresOnce     PASSED (0.000s)
  testMultipleRecoveryCycles                     PASSED (0.000s)
  testNoHandlerRegistered                        PASSED (0.000s)
  testSatisfiedToUnsatisfiedDoesNotFire          PASSED (0.000s)

결과: 7/7 PASS
```

### 전체 스위트 회귀 확인

```
swift test (전체)
LOG: /tmp/qa-task1-all-1780320200.log
EXIT=0

Test Suite 'All tests' passed at 2026-06-01 22:23:21.365
  NetworkPathReachabilityTests   7/7 PASS
  QuoteParsingTests              PASS
  TokenManagerTests              PASS
  WatchlistStoreTests            PASS
  PMCorePackageTests.xctest      PASS

결과: 전체 PASS, 기존 테스트 회귀 없음
```

---

## 3. Units & Signs Audit

tasks.md §Units & Signs Audit 기준:

| 대상 | 불변식 | 검증 케이스 | 결과 |
|---|---|---|---|
| NWPath transition-edge | satisfied edge당 1회, 최초 satisfied 0회 | T-NW1(`testInitialSatisfiedDoesNotFireRecovery`) / T-NW2(`testUnsatisfiedToSatisfiedFiresExactlyOnce`) | PASS |
| 역전이 발화 금지 | satisfied→unsatisfied 0회 | `testSatisfiedToUnsatisfiedDoesNotFire` | PASS |
| 복수 사이클 정확도 | N 사이클 → N회 (N=2) | `testMultipleRecoveryCycles` | PASS |
| requiresConnection 경계 | requiresConnection→satisfied = 복구로 간주 | `testRequiresConnectionToSatisfiedFiresOnce` | PASS |

수치 변환(ms↔s·스케일·부호) 없음 — tasks.md §Units & Signs Audit 동일 확인.
콜백 횟수 0/1/N 경계 전부 테스트로 잠김.

---

## 4. 코드 타당성 확인

reviewer 리포트(`docs/reviews/task-1-review.md`) 대비 QA 추가 검토:

- **역전이 발화 금지 타당성**: `testSatisfiedToUnsatisfiedDoesNotFire`가 명시적으로 커버. reviewer 정합성 표에도 일치로 기록됨.
- **복수 사이클 타당성**: `testMultipleRecoveryCycles`가 2사이클 정확도를 확인. 무한 누적·누락 없음.
- **결정론성**: `handleStatusUpdate` 직접 주입 방식 — 실 NWPathMonitor 의존 없음. CI 환경에서 안정적 실행 가능.
- **치명 이슈**: reviewer 판정대로 0건 확인.

권장 2건(deinit cancel / start 재시작 주석)은 v1 차단 사유 아님 — Task 2 VM 배선 전 반영 권장 유지.

---

## 5. 최종 verdict

**PASS**

- V10 (T-NW1/T-NW2) 통과: 7/7 테스트 PASS, EXIT=0
- 전체 스위트 회귀 없음
- Units & Signs Audit 통과: 콜백 횟수 0/1/N 경계 전부 테스트로 잠김
- UI 변경 없음: 브라우저 검증 해당 없음
- 치명 이슈 없음

---

## 6. 리스크 및 메모

- **권장(Task 2 전)**: 어댑터 `deinit { monitor.cancel() }` 추가(reviewer 권장 1). VM 배선 시 `stop()` 누락 방어.
- **권장(Task 2 전)**: `start()` 재시작 미지원 주석 1줄(reviewer 권장 2). `.transient` 재오픈 경로 잠복 방지.
- **백로그**: Swift 6 마이그레이션 시 테스트 6곳의 `var callCount` 캡처 → lock 기반 카운터 교체 필요. 현재 5.9에서는 비차단.

---

_생성: AppDev QA agent, 2026-06-01_
