# 코드 리뷰 리포트 — Task 5 (MarketStatusHeader 새로고침 버튼 배선, tasks.md T7)

리뷰 일자: 2026-06-02 / 모드: 코드 리뷰(모드 1) / 모드 등급: Standard
대상 diff: `App/Views/MarketStatusHeader.swift` (+21), `docs/OPERATIONAL_NOTES.md` (+1)

## 전체 평가

T7 명세 7속성을 모두 충족하는 순수 UI 배선이다. 경계규칙 ⓐ(UI는 `viewModel.refresh()`만 호출 — service/NWPathMonitor 직접 접근 0)를 정확히 지켰고, ⓒ(auth/검증 로직 숨김 금지)도 위반 없음 — 이 파일에 auth 분기가 없고 토큰 재발급은 기존 `QuoteService`가 소유한다. authFailed 문구 변경과 `onRetry → refresh()` 배선은 직전 태스크(T6)에서 이미 반영돼 있어 이 diff에는 문구 1줄만 남았다. **치명(blocking) 이슈 0건.** 표시조건 구현이 명세의 `&&` 평면 조건이 아닌 중첩(`if !isAdding { … if !symbols.isEmpty }`) 구조로 들어간 점이 유일한 논점이나, 동작상 동치이며 기존 `addButton` 묶음 패턴과 정합하여 권장 등급으로 분류한다.

## T7 7속성 체크 표

| # | 명세 속성 | 코드 | 충족 |
|---|---|---|---|
| 1 | `arrow.clockwise` ↔ `ProgressView` 전환 | L54-62 `if viewModel.isRefreshing` 분기 | ✓ |
| 2 | `disabled(viewModel.isRefreshing)` | L66 | ✓ |
| 3 | frame 22×22 | L57(ProgressView)·L61(Image) 양쪽 모두 22×22 | ✓ |
| 4 | `PMColor.sapphire` 전경 + border | L60 `foregroundStyle(PMColor.sapphire)` / L65 `stroke(PMColor.border)` | ✓ |
| 5 | 표시조건 `!symbols.isEmpty && !isAdding` | L26 `if !isAdding` 블록 내부 + L40 `if !viewModel.symbols.isEmpty` (중첩 = 논리곱 동치) | ✓ (구조 주의 — 권장) |
| 6 | accessibilityLabel "새로고침"/"새로고침 중" | L67 삼항 분기 | ✓ |
| 7 | ⌘R | L68 `.keyboardShortcut("r", modifiers: .command)` | ✓ |

7/7 충족.

## 변경 파일별 코멘트

### `App/Views/MarketStatusHeader.swift`

**[참고] 표시조건이 중첩 구조로 구현됨 (L26 + L40)**
- 위치: `headerRow` L26 `if !isAdding { … }` 블록 내부 L40 `if !viewModel.symbols.isEmpty { refreshButton }`
- 내용: 명세 표현은 `!symbols.isEmpty && !isAdding`(평면 논리곱). 코드는 `if !isAdding`(L26) 분기 안에 `if !symbols.isEmpty`(L40)를 중첩했다. 두 표현은 논리적으로 동치이며, 기존 `addButton`도 동일한 `if !isAdding` 블록 안에 있어 design.md §UX가이드라인 "기존 `if !isAdding` 분기 안에 포함"과 정확히 정합한다. ProgressView/Image의 ⓐ`isAdding` 모드에서 버튼이 숨고 ⓑsymbols 0건(V1 EmptyState)에서도 숨는 두 조건 모두 충족. 동작 결함 아님 — 구조 선택 기록 목적의 참고.

**[참고] 삽입 위치 검증 — addButton 직전(좌측) 정합 (L40-43)**
- L40-42 `refreshButton` → L43 `addButton` 순서. design.md §UX가이드라인 `[…][배지?][새로고침버튼][+버튼]` 레이아웃과 일치. `StatusBadge`(L37-39) 다음, `addButton`(L43) 직전 = 명세대로 "+"의 좌측.

**[참고] refreshButton이 viewModel.refresh()만 호출 — 경계규칙 ⓐ 준수 (L51-52)**
- L52 `viewModel.refresh()` 단일 호출. `service`·`NWPathMonitor`·`AsyncStream` 직접 참조 0. VM 측 `refresh()`(WatchlistViewModel:200-209)가 가드 2종(`!isRefreshing`·`!symbols.isEmpty`)·state 선리셋·`service.start`를 모두 소유 → UI는 트리거만. Module Map UI행 책임 기술과 정확히 일치.

**[참고] authFailed 문구 변경 (L191)**
- `"인증이 만료되었습니다 — 새로고침해 주세요"`로 변경 완료. design.md §위험요소 이슈1 해소·Spec Patch `[~]`·tasks.md T7 명세 문자열과 정확히 일치(오타·공백·em-dash 동일).

**[참고] 회귀 안전 — 기존 렌더 경로 무손상**
- `addButton`(L71-81)·`StatusBadge`(L37-39)·`statusText`(L31-36)·`Wordmark`(L24) 모두 미변경. refreshButton은 `addButton`과 동일한 `.buttonStyle(.plain)` + `RoundedRectangle(cornerRadius: 5).stroke(PMColor.border)` 패턴을 그대로 차용 — 신규 디자인 토큰 0(DESIGN_SYSTEM 영향 없음).
- 상태 바인딩: `MarketStatusHeader`는 `@ObservedObject var viewModel` 단일 참조(L7). refreshButton은 `viewModel.isRefreshing`·`viewModel.symbols`만 읽고 추가 `@StateObject`/`@ObservedObject` 도입 없음 → 중복 구독·인스턴스 누수 없음. design.md R3(VM 단일 인스턴스 생명주기) 전제와 정합.

**[참고] AlertBanner onRetry 배선은 이 diff 범위 밖 (L15)**
- L15 `onRetry: { viewModel.refresh() }`는 이미 적용 상태(T6에서 반영, 이 태스크 diff에 미포함). 현 코드 정합 확인 — 잔존 `viewModel.retry()` 호출처 0건(grep 검증). VM 측 `retry()` 삭제(T6)와 호출처 모두 일관.

### `docs/OPERATIONAL_NOTES.md`

**[참고] 운영 노트 1줄 추가 (L19)**
- `[2026-06-02] Task 5 … (developer)` 형식·날짜·서명 규약 준수. BUILD SUCCEEDED + PMCore swift test 46/46 회귀 0 기록. 중첩 구조로 표시조건 구현했음을 명시 — 위 [참고] 항목과 일관. 중복 항목 없음.

## 요약

| 심각도 | 건수 |
|--------|------|
| 치명적(blocking) | 0건 |
| 권장 | 0건 |
| 참고 | 6건 |

## 다음 단계

1. 치명·권장 이슈 0건 → **qa 단계 진행 가능**.
2. QA 라이브 검증 권고 포인트(tasks.md 검증 단계): V11(authFailed→버튼→복귀 골든패스), V12(refreshing 중 스피너+disabled+연타 무반응), V16(320pt 헤더 한 줄 수용 + isAdding/EmptyState 버튼 숨김 시각 확인), V17(.transient 팝오버 닫힘→재오픈 스피너 복원). 표시조건 중첩 구조의 두 분기(isAdding·symbols.isEmpty)는 V16에서 브라우저/실행 시각 확인으로 닫는다.
3. 이 태스크는 순수 UI 배선이라 단위 테스트 직접 대상 아님(T8/T9는 VM·어댑터). 버튼 → `refresh()` → VM 전이는 T-VM1~10(V1~V9)이 커버.

## Units & Signs Audit

본 태스크는 UI 배선 전용 — 수치 변환(ms↔s·스케일·부호·통화) **없음**. refresh 중복 가드·`isRefreshing` 생명주기·NWPath transition-edge 불변식은 VM/어댑터(T2~T9) 소관이며 tasks.md §Units & Signs Audit에 등재됨. 본 파일 변경분에 audit 대상 수치 연산 0건.
