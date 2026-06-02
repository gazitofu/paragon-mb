# 코드 리뷰 리포트 — refresh-recovery Task 3 (WatchlistViewModel 상태기계 T2~T6)

- 리뷰어: reviewer (모드 1)
- 일자: 2026-06-01
- 대상 commit 범위: Task 3 (in-progress)
- SSOT: `Vault/appdev/PARAGON-MB/prd/refresh-recovery/design.md` §상태·이벤트 계약 / `~/Vault/appdev/CLAUDE.md §4`
- 빌드: `swift build`(PMCore) PASS. `WatchlistViewModel`/`MarketStatusHeader`는 App(Xcode) 타겟이라 SwiftPM 빌드 범위 밖 — OPERATIONAL_NOTES 기준 developer가 xcodebuild 컴파일 확인.

## 전체 평가

Task 3 의도(T2~T6)가 design.md 핵심 결정 ①~⑤와 정확히 일치한다. state 선리셋(`if state != .normal { state = .loading }`)·복귀조건 확장(`.loading||.authFailed||.wsDisconnected`)·중복 가드(`isRefreshing`)·에러 양분기 `isRefreshing=false`·`retry()` 흡수·reachability init/start/deinit 배선이 모두 코드에 명시적으로 반영됐다. Floor 4(은닉 안전로직) 위반 없음, 생명주기(`[weak self]`·deinit stop)·DI(default-injected protocol)·메모리 처리 모두 건전. 치명적 이슈 없음. 단, 계약 매트릭스 **행 5(`wsDisconnected` → `.connection(true)`)** 의 emit 기술이 선리셋 도입으로 코드와 어긋나며, refresh가 `.quote` 없이 `.connection(true)`만 받는 경로에서 `isRefreshing`이 안 풀리는 좁은 틈이 존재한다(권장 1건). Task 3은 "빌드 통과"가 검증 게이트이고 전이 단언은 Task 4 단위 테스트로 잠그도록 SPRINT_PLAN에 설계돼 있어, 본 태스크의 PASS 자체는 막지 않는다.

## 계약 매트릭스 정합 표 (design.md §상태·이벤트 계약 11행 × 코드)

| # | 매트릭스 행 | 코드 위치 | emit/action 정합 | 판정 |
|---|---|---|---|------|
| 1 | authFailed →(버튼/NWPath) refresh | VM:198-207 | isRefreshing=true·state=.loading(선리셋)·loadFailed=false·service.start 1회 | ✅ 정합 |
| 2 | authFailed →(refresh후) .quote | VM:109-115 | state=.normal(확장조건 .authFailed 포함)·isRefreshing=false·quotes·lastUpdated | ✅ 정합 |
| 3 | authFailed →(refresh후) .error(.authFailed) | VM:125-128 | state=.authFailed·isRefreshing=false(switch 전 해제) | ✅ 정합 |
| 4 | wsDisconnected →(버튼/NWPath) refresh | VM:198-207 | isRefreshing=true·state=.loading(선리셋)·service.start 1회 | ✅ 정합 |
| 5 | wsDisconnected →(refresh후) .quote 또는 .connection(true) | VM:109-115 / VM:119-124 | `.quote`경로 ✅. **`.connection(true)`경로 불일치** — 매트릭스는 "기존 `if state==.wsDisconnected{state=.normal}`(VM:121)로 .normal 도달"이라 기술하나, refresh 선리셋이 state를 이미 `.loading`으로 내려서 VM:121 조건(`state==.wsDisconnected`)이 false. `.connection(true)`만으로는 `.loading`에서 못 빠져나오고 isRefreshing도 유지 | ⚠️ 부분 불일치 (권장1) |
| 6 | loadFailed →(배너 "다시 시도") refresh | VM:198-207 + Header:15 | loadFailed=false·isRefreshing=true·선리셋(.normal이면 유지)·service.start 1회·AlertBanner onRetry→refresh() 배선 | ✅ 정합 |
| 7 | normal →(버튼) refresh | VM:204 | state 유지(`!=.normal` false → 미변경)·isRefreshing=true·service.start 1회 | ✅ 정합 |
| 8 | normal →(refresh후) .quote | VM:109-115 | isRefreshing=false·quotes 갱신·state 이미 .normal | ✅ 정합 |
| 9 | loading →(버튼) refresh | VM:204 | `.loading`은 선리셋 무영향(`!=.normal` true → .loading 재대입, no-op)·isRefreshing=true·service.start | ✅ 정합 |
| 10 | refreshing(isRefreshing==true) → 추가 refresh | VM:199 | `guard !isRefreshing` early return, service.start 미호출 | ✅ 정합 |
| 11 | empty(symbols 0건) → refresh | VM:200 | `guard !symbols.isEmpty` early return | ✅ 정합 |
| 경계 | NWPath transition-edge만 1회 발화(최초 satisfied 금지) | NetworkPathReachability:57-77 | previous==nil → isRecovery=false, (prev != .satisfied && current==.satisfied)만 발화. T-NW1/2 테스트 통과 | ✅ 정합 |
| 경계 | AlertBanner는 onRetry emit만, refresh 배선은 parent(헤더) | Header:15, AlertBanner:138/147 | child는 onRetry 콜백만 emit, 헤더가 `{ viewModel.refresh() }` 배선 | ✅ 정합 |

빈 셀·미구현 행 없음. deferred(R2 완전 무응답·WS 백오프 표시 v2)도 매트릭스에 명시 등록됨.

## 발견된 이슈

### [권장] 1. `wsDisconnected` refresh 후 `.connection(true)`-만-도착 경로에서 isRefreshing 미해제 (매트릭스 행 5 불일치)
- 위치: `WatchlistViewModel.swift:119-124` (apply `.connection`) + `:204` (refresh 선리셋)
- 현재 코드:
  ```swift
  // refresh(): if state != .normal { state = .loading }   // wsDisconnected → .loading
  case let .connection(connected):
      if connected {
          if state == .wsDisconnected { state = .normal }  // ← refresh 후엔 state==.loading 이라 false
      } else if state == .normal {
          state = .wsDisconnected
      }
  ```
- 문제: design.md 매트릭스 행 5는 wsDisconnected refresh 후 복귀 경로로 `.quote` **또는** `.connection(true)` 두 가지를 명시하고, `.connection(true)`이 VM:121로 `.normal` 도달한다고 기술한다. 그러나 refresh()의 선리셋이 state를 `.loading`으로 내리므로, 재구독 후 데이터(`.quote`)보다 `.connection(true)`이 먼저(그리고 단독으로) 도착하면 VM:121 조건이 false가 되어 `.loading`에 머물고 `isRefreshing`도 계속 true(스피너 회전). 실무상 WS 재구독은 곧이어 `.quote`를 흘려 자연 해소되지만, 장 외 시간(체결 0건) 등 `.connection(true)` 후 `.quote`가 안 오는 구간에서는 R2(무한 회전) 좁은 변형이 된다. 매트릭스가 명시한 두 복귀 경로 중 하나가 코드에서 보장되지 않는다.
- 영향: 정상 장중에는 거의 드러나지 않음(곧 quote 도착). 장 외/저빈도 종목에서 스피너 잔류 가능 — 사용자 가시.
- 수정 제안(택1, **코드 수정은 developer 몫**):
  - (a) `.connection`의 복귀 조건을 선리셋 상태까지 포함: `if connected { if state == .wsDisconnected || (isRefreshing && state == .loading) { state = .normal }; isRefreshing = false }` — 단 `.loading`은 초기 부트와 겹치므로 `isRefreshing` 가드 필수.
  - (b) 또는 design.md 매트릭스 행 5의 `.connection(true)` 복귀 경로 기술을 "refresh 경유 시 .quote가 종결 이벤트"로 정정(설계 정정 — architect 영역). Task 4 단위 테스트(T-VM5)가 `.connection(true)` 단독 케이스를 단언하면 이 틈이 강제로 드러난다.
- 비고: R2(완전 무응답)는 v1 비목표로 인지하나, 본 건은 "이벤트가 오긴 오는데(connection) 종결이 안 되는" 별개 경로라 R2 면책에 그대로 포섭되지 않음 — 최소한 Task 4 단언 또는 매트릭스 정정 중 하나로 닫을 것을 권장.

### [참고] 2. `MarketStatusHeader` onRetry 배선은 Task 3 범위 외이나 T6(retry 삭제)이 강제 — 정합
- 위치: `MarketStatusHeader.swift:15`
- 내용: `AlertBanner(... onRetry: { viewModel.refresh() })`. SPRINT_PLAN상 onRetry→refresh 배선·문구 변경은 Task 5 산출물이나, Task 3의 `retry()` 삭제(T6)가 컴파일을 위해 이 한 줄 교체를 불가피하게 만든다. 빌드 유지용 최소 변경으로 적절. authFailed 배너 문구(VM 영역 아님, AlertBanner:167 "앱을 재시작해 주세요" 유지)와 refreshButton 본체는 Task 5로 남아 있음 — 범위 누수 아님.
- 조치: 없음(정상). Task 5에서 문구 변경(이슈1 해소)·refreshButton 추가 진행.

### [참고] 3. reachability `@unchecked Sendable` + NSLock — 동시성 처리 적절
- 위치: `NetworkPathReachability.swift:20-77`
- 내용: `@unchecked Sendable` 선언 + `_handler`/`_lastStatus` 가변 상태를 NSLock으로 보호, 핸들러 발화는 lock 밖에서 수행(재진입 데드락 회피). NWPathMonitor 콜백이 전용 큐에서 오므로 적절. deinit stop()은 OPERATIONAL_NOTES에 @MainActor deinit에서 Sendable 호출 안전 기록 있음. retain cycle 없음(`onRecovered { [weak self] ... }` VM:73).
- 조치: 없음.

### [참고] 4. DI 주입 가능성 — Task 4 mock 전제 충족
- 위치: `WatchlistViewModel.swift:50-60`
- 내용: `service: QuoteServicing`·`reachability: NetworkReachability = NetworkPathReachability()` 모두 protocol 주입. Task 4가 mock NetworkReachability/mock QuoteServicing 주입으로 T-VM1~10을 결정론적으로 검증할 수 있는 구조. (현재 Tests에 mock·`WatchlistViewModelRefreshTests.swift` 부재는 SPRINT_PLAN상 **Task 4 산출물**이라 Task 3 결함 아님.)
- 조치: 없음.

## 회귀 점검

| 기존 동작 | 영향 | 판정 |
|---|---|---|
| ScreenState enum 라우팅(empty/loading/normal/wsDisconnected/authFailed) | enum 불변, 케이스 추가/삭제 없음 | ✅ 무파손 |
| 빈 상태(V1) / loadFailed 배너 / 삭제 undo | refresh가 `!symbols.isEmpty` 가드·`loadFailed=false`만 손댐, remove/undo/commitAdd 미변경 | ✅ 무파손 |
| 캐시값 유지(수용기준 6) | refresh는 quotes 비우지 않음·선리셋이 .loading이어도 WatchlistView showSkeleton=`state==.loading && quotes.isEmpty`라 캐시 있으면 스켈레톤 안 뜸(R5 정합) | ✅ 보존 |
| 장 상태 폴링·KRX 전환(M3) | pollMarketStatus 미변경 | ✅ 무파손 |
| `.connection(false)` 끊김 경고 | `else if state == .normal` 유지 | ✅ 무파손 |

## Units & Signs Audit (Task 3 해당분)

| function | input | output | 규칙 | 증명 테스트 |
|---|---|---|---|---|
| `refresh()` 중복 가드 | 연속 호출 N회 | service.start 1회 | count==1 불변식 | T-VM9 (Task 4 예정) |
| reachability transition-edge | NWPath.Status 시퀀스 | 콜백 0/1/2회 | prev≠satisfied && cur==satisfied만 | T-NW1/T-NW2 (구현·통과) |
| 선리셋 경계 | state | .normal이면 유지/그 외 .loading | `state != .normal` | T-VM7(normal 유지)·T-VM1(.loading) (Task 4 예정) |

수치 변환(ms/scaling/sign) 해당 없음. 가드 count 단언은 Task 4 단위 테스트로 잠금(SPRINT_PLAN 설계).

## 요약

| 심각도 | 건수 |
|--------|------|
| 치명적 | 0건 |
| 권장 | 1건 (매트릭스 행5 `.connection(true)` 단독 복귀 + isRefreshing 미해제) |
| 참고 | 3건 |

## 최종 Verdict

**PASS (조건부 — 권장 1건 인지)**

Task 3(T2~T6)은 design.md 핵심 결정 ①~⑤ 및 계약 매트릭스 11행 중 10행에 완전 정합하며, 치명적 이슈·Floor 위반·회귀 없음. 본 태스크의 게이트("빌드 통과", 전이 단언은 Task 4 위임)를 충족하므로 진행 차단 사유 아님.

단, **권장 1건(매트릭스 행 5)** 은 Task 4 진입 전 닫을 것:
- Task 4의 T-VM5가 `wsDisconnected → refresh → .connection(true)` **단독**(quote 미도착) 케이스를 단언하도록 명시 → 코드 수정(option a) 또는 매트릭스 정정(option b, architect)을 강제.
- 그 외 경로는 Task 4 단위 테스트(T-VM1~10) 통과로 잠금 확인 후 최종 종결.

## 다음 단계
1. (권장1) developer: `.connection(true)`-단독-복귀 경로 보강 또는 architect: 매트릭스 행5 정정. Task 4 T-VM5에 해당 단언 추가.
2. Task 4 단위 테스트(`Tests/AppTests/WatchlistViewModelRefreshTests.swift`)로 T-VM1~10 잠금 — 본 리뷰 정합표가 코드 단언으로 확정됨.
3. Task 5에서 refreshButton 본체 + authFailed 문구 변경(이슈1) 진행.

---

## 보강 재확인 (행5)

- 일자: 2026-06-02
- 범위: 권장 1건(계약 매트릭스 행5 `wsDisconnected` 복귀 경로 불일치)이 닫혔는지만 좁게 재확인. 전체 재리뷰 아님.
- 대상 변경분: `WatchlistViewModel.swift:119-126` `apply(.connection)` 블록 + `:200-209` `refresh()` 선리셋.

### 검증 결과 (확인 항목 1~4)

현재 코드(VM:119-126):
```swift
case let .connection(connected):
    if connected {
        // wsDisconnected 직접 복귀 또는 refresh 선리셋(.loading)으로 진입한 경로 양쪽 처리(행5)
        if state == .wsDisconnected || (isRefreshing && state == .loading) { state = .normal }
        isRefreshing = false    // .connection(true) = 재구독 성공 → 스피너 해제(행5 기대 UI)
    } else if state == .normal {
        state = .wsDisconnected
    }
```

| # | 확인 항목 | 결과 | 근거 |
|---|---|------|------|
| 1 | refresh 선리셋(`.loading`) 경유 경로에서도 `.connection(true)` 단독 도착 시 `state=.normal` + `isRefreshing=false` 복귀 | ✅ 닫힘 | 이전 리뷰 수정 제안 option (a)와 정확히 일치하는 가드 `(isRefreshing && state == .loading)`가 VM:122에 추가됨. wsDisconnected→refresh(선리셋 `.loading`, VM:206)→`.connection(true)` 단독 도착 시 가드 true → `state=.normal`, 직후 VM:123 `isRefreshing=false`. 행5가 명시한 `.quote`/`.connection(true)` **양쪽** 복귀 경로가 코드에서 보장됨. `.quote` 경로(VM:115)도 그대로 유지. |
| 2 | 초기 부트(`isRefreshing==false`) 중 `.connection(true)` 도착 시 가드 false → state 미변경(기존 동작 보존) | ✅ 회귀 없음 | 부트 중 `isRefreshing==false`이므로 `(isRefreshing && state == .loading)` = false, 동시에 부트 상태는 `.loading`이라 `state == .wsDisconnected`도 false → state 미변경. 오발화 없음. (VM:123 `isRefreshing=false`는 무조건 실행되나 이미 false라 무해 no-op — 항목4와 동일 성격.) |
| 3 | 기존 경로 회귀(`.connection(false)→wsDisconnected`·`.quote` 복귀·`.error` isRefreshing 해제) | ✅ 무파손 | `.connection(false)`: VM:124-125 `else if state == .normal { state = .wsDisconnected }` 불변. `.quote`: VM:109-115 복귀조건 확장+`isRefreshing=false` 불변. `.error`: VM:127-128 switch 전 `isRefreshing=false` 불변. 이번 변경은 `connected==true` 분기 내부에만 국한. |
| 4 | `.connection(true)` 후 `.quote` 연속 도착 시 idempotent 무해성 | ✅ 무해 | `.connection(true)`에서 이미 `state=.normal`·`isRefreshing=false` 도달. 후속 `.quote`(VM:109-115): `isRefreshing=false` 재대입(no-op), 복귀조건 `state==.loading\|\|.authFailed\|\|.wsDisconnected` 모두 false라 state 재전환 없음, `quotes`/`lastUpdated`만 정상 갱신. 멱등. |

### 잔여 이슈

- **신규 치명/권장 0건.** 이번 변경분은 `connected==true` 분기에 국한되어 매트릭스 행5만 닫고 다른 행에 부작용을 만들지 않음.
- 미세 관찰(조치 불요): VM:123 `isRefreshing = false`가 `connected==true`의 모든 경로에서 무조건 실행됨 — refresh 미진행 중 들어온 stray `.connection(true)`에서도 false 재대입이 일어나나, 이미 false인 상태의 no-op이며 행5 기대 UI("스피너 해제")와 의미상 정합. design.md 매트릭스 행5의 `.connection(true)` 기대 UI("스피너→아이콘")와 일치하므로 정정 불요 — 이전 리뷰가 제시한 두 닫힘 옵션 중 (a)[코드 보강]가 선택되어 행5 매트릭스 본문은 코드와 이미 정합(별도 architect 정정 불필요).
- Task 4 T-VM5는 여전히 `wsDisconnected → refresh → .connection(true)` **단독**(quote 미도착) 케이스를 단언으로 잠글 것을 권고 — 이번 코드 보강이 회귀하지 않도록 강제하는 안전망(닫힘 확인이지 미해결 항목 아님).

### 최종 verdict (보강 재확인)

**행5 닫힘 — PASS.** 권장 1건이 이전 리뷰 수정 제안 option (a)대로 코드 보강되어 닫혔다. 행5 양쪽 복귀 경로(`.quote` / `.connection(true)` 단독) 모두 `state=.normal`+`isRefreshing=false` 보장. 오발화 회귀(항목2)·기존 경로 회귀(항목3)·멱등성(항목4) 모두 통과. **신규 치명적 이슈 0건.** Task 3 최종 Verdict는 무조건 PASS로 격상(이전의 "조건부 — 권장1 인지" 해소).
