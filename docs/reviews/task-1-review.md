# 코드 리뷰 리포트 — refresh-recovery Task 1 (NetworkPathReachability)

- 일자: 2026-06-01
- 대상: `Sources/PMCore/Network/NetworkPathReachability.swift` (신규), `Tests/PMCoreTests/NetworkPathReachabilityTests.swift` (신규)
- SSOT: `Vault/appdev/PARAGON-MB/prd/refresh-recovery/design.md` §③ / §상태·이벤트 계약 경계 계약 (T-NW1/T-NW2)
- 빌드/테스트: `swift build` 성공(경고 0), `swift test --filter NetworkPathReachabilityTests` 7/7 PASS, 0.001s (실네트워크 의존 없음)

## 전체 평가

design.md §③의 `NetworkReachability` protocol 시그니처(`onRecovered`/`start`/`stop`)와 transition-edge 의미론(최초 satisfied 발화 금지 / unsatisfied→satisfied만 1회 발화)을 정확히 구현했다. 핵심 결함 수정 지점인 "최초 satisfied 오발화 방지(R1)"가 `_lastStatus == nil` 가드로 명확히 구현됐고, 테스트가 결정론적(NWPathMonitor 실물 미사용, `handleStatusUpdate` 직접 주입)이며 핵심 두 케이스(T-NW1/T-NW2)와 경계 케이스(requiresConnection, 복구 사이클 2회, 핸들러 미등록, satisfied→unsatisfied)를 모두 커버한다. 락 외부에서 핸들러를 호출해 재진입 데드락도 회피했다. 다만 생명주기(deinit·재시작·중복 start) 측면에 design.md 명세 대비 누락이 있어 권장 등급으로 정리한다. **치명적 이슈는 없다.**

## 발견된 이슈

### [권장] deinit에서 monitor.cancel() 미보장 — 어댑터 자체 생명주기 안전망 부재
- 위치: `NetworkPathReachability.swift:20-47` (클래스 전체에 deinit 없음)
- 현재: `stop()`이 `monitor.cancel()`을 호출하지만, deinit이 없어 호출자가 `stop()`을 누락하면 NWPathMonitor가 cancel되지 않은 채 인스턴스가 사라질 수 있다.
- 문제: design.md §③는 "VM은 `deinit`에서 `reachability.stop()`"라고 VM 책임으로 명시하므로 현재 동작이 설계 위반은 아니다. 그러나 어댑터가 자기 자원(NWPathMonitor)의 정리를 외부 계약에만 의존하면, Task 2에서 VM 배선이 어긋나거나 테스트에서 `stop()` 없이 인스턴스를 버릴 때 모니터가 누수될 수 있다. NWPathMonitor는 시스템 리소스(경로 관찰 콜백)를 잡으므로 자체 deinit 안전망이 방어적이다.
- 수정 제안: 어댑터에 deinit 추가하여 idempotent cancel 보장.
  ```swift
  deinit {
      monitor.cancel()  // NWPathMonitor.cancel은 idempotent — 중복 호출/미start 모두 안전
  }
  ```
  (`stop()`과 중복 호출돼도 NWPathMonitor.cancel은 안전. design.md의 VM-stop 계약과 병존 가능.)

### [권장] start() 멱등성·재시작 미정의 — 중복 start 시 핸들러 덮어쓰기로 NWPathMonitor 재사용 위험
- 위치: `NetworkPathReachability.swift:38-47`
- 현재: `start()`는 매 호출 시 `monitor.pathUpdateHandler`를 재설정하고 `monitor.start(queue:)`를 호출한다. `stop()`은 `monitor.cancel()`만 한다.
- 문제: NWPathMonitor는 cancel된 후 재start할 수 없다(Apple 문서: cancel된 monitor는 재사용 불가, 새 인스턴스가 필요). 현재 구조에서 `stop()` 후 `start()`를 다시 부르면 이미 cancel된 monitor를 start하려다 무동작/비정상이 된다. 또한 `start()`를 두 번 부르면 같은 monitor에 start가 중복된다. design.md는 VM `start()`(파이프라인 부트) 1회 + `deinit` stop만 가정하므로 현재 사용 시나리오에서는 문제가 드러나지 않으나, `.transient` 팝오버 재오픈/앱 재기동 경로(design R3 영역)에서 재시작이 필요해지면 잠복 결함이 된다.
- 수정 제안: (a) 최소 — 재시작 비지원을 주석으로 명시(현 사용범위에선 충분), 또는 (b) 방어 — `start()`에 이미 시작됨 가드(`private var isStarted` lock 보호)를 두고, 재시작이 필요하면 monitor를 재생성하는 정책을 명문화. v1 범위상 (a)로 충분하나 한 줄 주석 권장.
  ```swift
  /// 1회 start 전제. stop()(=cancel) 후 재start는 NWPathMonitor 제약상 미지원 —
  /// 재시작이 필요하면 새 인스턴스를 생성할 것.
  public func start() { ... }
  ```

### [참고] onRecovered 핸들러 교체 시 직전 상태 미초기화 — 의미상 무해하나 계약 모호
- 위치: `NetworkPathReachability.swift:34-36`
- 현재: `onRecovered`를 여러 번 부르면 `_handler`만 교체되고 `_lastStatus`는 유지된다.
- 문제: design.md는 `onRecovered`를 VM `start()` 1회 등록만 가정하므로 실사용 영향 없음. 다만 protocol 계약상 "핸들러 재등록 시 transition 추적이 리셋되는가"가 불명확하다. 참고로만 등록 — 현재 단일 등록 사용에서는 문제 아님.

### [참고] Swift 6 @Sendable 클로저의 var 캡처 — 현재(5.9) 비차단, 마이그레이션 시 테스트가 먼저 깨짐
- 위치: 테스트 `NetworkPathReachabilityTests.swift:17,29,...` (`reachability.onRecovered { callCount += 1 }`) 및 OPERATIONAL_NOTES 기록(2026-06-01)
- 현재: `onRecovered`의 파라미터는 `@escaping @Sendable () -> Void`. 테스트 클로저가 지역 `var callCount`를 캡처해 증가시킨다. Package.swift는 `swift-tools-version:5.9`, 빌드 경고 0건으로 확인됨.
- 판단(요청 항목): **현재 5.9 모드에서는 실제 위험 아님** — 빌드·테스트 모두 깨끗(경고 0, 7/7 PASS). 단 Swift 6 언어모드로 올리면 `@Sendable` 클로저의 가변 캡처는 에러가 된다. 가장 먼저 깨지는 곳은 프로덕션 코드가 아니라 **이 테스트 6곳**이다(프로덕션 `_handler` 보관은 lock 보호 + `@unchecked Sendable`로 이미 안전 처리됨). 즉 developer 보고대로 non-blocking이 맞고, Swift 6 전환 시 테스트를 `actor`/`NSLock`/`os_unfair_lock` 기반 카운터 또는 `XCTestExpectation`으로 바꾸면 된다. v1 차단 사유 아님 — Swift 6 마이그레이션 백로그로 등록 권장.
- 참고 수정 방향(전환 시):
  ```swift
  let counter = LockedCounter()           // NSLock 보호 카운터
  reachability.onRecovered { counter.increment() }
  XCTAssertEqual(counter.value, 1)
  ```

### [참고] requiresConnection→satisfied를 복구로 간주 — 의도된 동작, 명세와 정합
- 위치: `NetworkPathReachability.swift:66` (`isRecovery = (prev != .satisfied) && (current == .satisfied)`)
- 내용: `prev != .satisfied` 조건이라 `.unsatisfied`뿐 아니라 `.requiresConnection`에서 satisfied로 가도 발화한다. design.md 주석(`unsatisfied(또는 .requiresConnection)`)과 일치하고 테스트(`testRequiresConnectionToSatisfiedFiresOnce`)가 이를 고정한다. 올바른 설계 — 참고로만 기록.

## 정합성 점검 (design.md 대비)

| 항목 | 명세 | 구현 | 결과 |
|---|---|---|---|
| protocol 시그니처 | `onRecovered`/`start`/`stop`, `Sendable` | 동일 | 일치 |
| 최초 satisfied 발화 금지 (R1) | 발화 안 함 | `_lastStatus==nil → isRecovery=false` | 일치 (T-NW1) |
| transition-edge 1회 발화 | unsatisfied→satisfied 1회 | `(prev != .satisfied)&&(current==.satisfied)` | 일치 (T-NW2) |
| 역전이 미발화 | satisfied→unsatisfied 0회 | 조건 false | 일치 (testSatisfiedToUnsatisfiedDoesNotFire) |
| 스레드 안전 | (콜백 디스패치 큐) | NSLock + 전용 queue, 핸들러는 락 외부 호출 | 양호 |
| cancel 처리 | VM deinit에서 stop | stop=cancel 구현, 어댑터 deinit 없음 | 권장 보완 |
| retain cycle | — | `pathUpdateHandler`에 `[weak self]` | 양호 (사이클 없음) |
| 테스트 결정론 | mock path 시퀀스 | handleStatusUpdate 직접 주입, 실네트워크 0 | 양호 |

## 요약

| 심각도 | 건수 |
|--------|------|
| 치명적 | 0건 |
| 권장 | 2건 (deinit cancel, start 멱등성/재시작) |
| 참고 | 3건 (handler 재등록, Swift6 var캡처, requiresConnection) |

## 최종 verdict

**치명 이슈 없음 — PASS.** design.md §③ 및 상태·이벤트 계약 경계 계약(T-NW1/T-NW2)에 정합하며, 빌드·테스트 모두 통과하고 테스트가 결정론적이다. 권장 2건(어댑터 deinit cancel 안전망, start 재시작 정책 주석)은 Task 2 VM 배선 전에 반영하면 잠복 결함을 예방할 수 있으나 v1 차단 사유는 아니다. Swift 6 var 캡처는 테스트 6곳 한정 잠재 이슈로 마이그레이션 백로그 등록 권장.

## 다음 단계
1. (권장) 어댑터에 `deinit { monitor.cancel() }` 추가 — 자체 생명주기 안전망.
2. (권장) `start()` 재시작 미지원 1줄 주석 — `.transient` 재오픈/재기동 경로 잠복 결함 예방.
3. (참고) Swift 6 마이그레이션 시 테스트 카운터를 lock 기반으로 교체하는 백로그 등록.
