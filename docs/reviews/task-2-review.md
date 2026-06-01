# 코드 리뷰 리포트 — refresh-recovery Task 2 (Xcode unit test 타겟 신설, 인프라)

- 리뷰 모드: 모드 1 (코드 리뷰), 인프라 태스크 / 가벼운 리뷰
- 일자: 2026-06-01
- 대상: `project.yml` (PARAGON-MBTests 타겟 + scheme test action) · `Tests/AppTests/AppSmokeTests.swift` (신규)
- 의도: App 타겟(`WatchlistViewModel` 소재) `@testable import` 가능한 Xcode unit test 타겟 신설 — Task 4 VM 단위 테스트의 전제 인프라

## 전체 평가

인프라 목적에 정확히 부합한다. `bundle.unit-test` + `BUNDLE_LOADER`/`TEST_HOST` 배선으로 App 타겟을 호스트하는 표준 macOS host-based unit test 구성이며, 스킴 test action도 `TestableReference`로 정상 연결되어 `xcodebuild test -scheme PARAGON-MB`가 동작하는 구조다. 스모크 테스트는 실제 App 타겟 심볼(`WatchlistViewModel.ScreenState.empty`)에 `@testable` 접근해 파이프라인이 라이브로 연결됨을 입증한다 — Floor 2(도달성) 충족. PMCore SwiftPM(`swift test`) 경로는 침범하지 않았고, 기존 App/PMCore 타겟 설정도 변경 없이 보존됐다. 치명 이슈 없음.

## 발견된 이슈

### [참고] TEST_HOST 경로의 실행 파일명 하드코딩
- 위치: `project.yml:52`
- 현재 코드:
  ```yaml
  TEST_HOST: "$(BUILT_PRODUCTS_DIR)/PARAGON-MB.app/Contents/MacOS/PARAGON-MB"
  ```
- 내용: `.app` 번들명과 MachO 실행 파일명을 `PARAGON-MB`로 문자열 하드코딩했다. 현재 App 타겟명과 일치하므로 동작에 문제 없다. 다만 App 타겟명이 바뀌면 두 곳을 동시에 고쳐야 한다. XcodeGen은 `dependencies: [target: PARAGON-MB]`로 의존을 인지하므로 `$(TEST_HOST)`가 이미 BUNDLE_LOADER에 연결돼 있다. 인프라 1회성 설정이라 즉시 조치 불요 — 타겟명 변경 시 이 라인을 같이 갱신해야 한다는 점만 인지하면 된다.
- 조치: 불요 (참고).

### [참고] macOS 13.0 배포 대상 vs XCTest dylib ld warning
- 위치: `project.yml:6-7` (deploymentTarget macOS "13.0") + OPERATIONAL_NOTES 기록
- 내용: XCTest dylib이 macOS 14.0 기준이라 13.0 배포 대상에서 `ld` warning이 발생하나 테스트 실행에는 무해함이 OPERATIONAL_NOTES에 이미 기록됨. 테스트 타겟에 별도 `MACOSX_DEPLOYMENT_TARGET` 상향을 두지 않은 선택은 App 배포 대상(13.0)과의 정합을 우선한 합리적 판단. warning은 노이즈일 뿐 실패 신호가 아님이 문서화되어 있어 추가 조치 불요.
- 조치: 불요 (참고). 추후 warning이 거슬리면 테스트 타겟 한정 `MACOSX_DEPLOYMENT_TARGET: "14.0"` 가능하나 현재 불필요.

### [참고] 스모크 테스트의 단언이 토톨로지에 가까움
- 위치: `Tests/AppTests/AppSmokeTests.swift:8-9`
- 현재 코드:
  ```swift
  let state = WatchlistViewModel.ScreenState.empty
  XCTAssertEqual(state, .empty)
  ```
- 내용: `.empty == .empty` 단언 자체는 검증 가치가 낮다(항상 참). 그러나 이 테스트의 목적은 로직 검증이 아니라 **컴파일·링크·@testable 접근 가능성 입증**이며, 그 목적은 심볼 참조만으로 충족된다. 인프라 스모크로서 의도에 부합하므로 의도된 형태로 본다. Task 4가 실제 VM 동작 테스트를 채우면 이 스모크는 역할을 다한다.
- 조치: 불요 (참고). Task 4 완료 후 이 스모크 파일을 유지할지/제거할지는 그때 판단 가능(현재는 유일한 AppTests 검증이라 유지 권장).

## 정합성 확인 (PASS 항목)

| 검사 | 결과 | 근거 |
|---|---|---|
| 타겟 type `bundle.unit-test` | PASS | `project.yml:43` |
| platform macOS | PASS | `project.yml:44` |
| sources `Tests/AppTests` | PASS | `project.yml:45-46`, 실제 디렉토리 존재 |
| App 타겟 의존 | PASS | `project.yml:47-48` `dependencies: [target: PARAGON-MB]` |
| TEST_HOST / BUNDLE_LOADER 배선 | PASS | `project.yml:51-52` BUNDLE_LOADER=`$(TEST_HOST)`, TEST_HOST→App MachO |
| 서명 일관성 (Manual / "-" / hardened off) | PASS | `project.yml:54-56` = App 타겟 `:37-39`과 동일 ad-hoc 패턴 |
| 스킴 test action 배선 | PASS | 생성된 `PARAGON-MB.xcscheme` TestAction에 PARAGON-MBTests TestableReference 존재 |
| 모듈명 매핑 (`PARAGON-MB`→`PARAGON_MB`) | PASS | 스모크 `@testable import PARAGON_MB` — XcodeGen 모듈명 규칙(하이픈→언더스코어)과 일치 |
| @testable 심볼 실접근 (도달성) | PASS | `WatchlistViewModel.ScreenState.empty` 실존(`WatchlistViewModel.swift:9,12,13`), Equatable |
| 기존 App/PMCore 타겟 회귀 | PASS | git diff: App 타겟·Package.swift 무변경, project.yml은 추가분만(+21줄) |
| PMCore `swift test` 경로 비침범 | PASS | `Package.swift:14` testTarget path는 `Tests/PMCoreTests`만, AppTests 미참조 |
| 변경 범위 정합 | PASS | git diff = project.yml + Tests/AppTests(신규) + meta(OPERATIONAL_NOTES/SPRINT_PLAN). 선언 산출물과 일치 |

## 요약
| 심각도 | 건수 |
|--------|------|
| 치명적 | 0건 |
| 권장 | 0건 |
| 참고 | 3건 |

## 다음 단계
1. 추가 수정 없이 통과. Task 2 산출물은 의도(테스트 인프라 동작 입증)를 충족한다.
2. `xcodebuild test -scheme PARAGON-MB` 스모크 PASS가 OPERATIONAL_NOTES에 기록되어 검증 기준 충족 — 별도 재실행 불요.
3. Task 3(VM 상태기계) → Task 4(VM 단위 테스트, 이 타겟 사용)로 진행 가능.

## Verdict
**PASS** — 치명/권장 0건, 참고 3건(모두 조치 불요). 인프라 정합·회귀 없음·도달성 충족. Task 3 진행 가능.
