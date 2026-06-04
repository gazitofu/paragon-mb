# 코드 리뷰 리포트 — kis-migration Task 1 (KIS 기반 레이어)

- 리뷰 모드: 모드 1 (코드 리뷰) / 모드 등급: Standard (DB·auth 직접 변경 없는 상수·식별자 추가)
- 일자: 2026-06-04
- 브랜치: `feat/kis-migration` (미스테이징 working tree)
- 대상 (이 태스크 변경분만):
  - `Sources/PMCore/Network/KISEnvironment.swift` (신규, 19줄)
  - `Sources/PMCore/Auth/KeychainStore.swift` (KISCredential enum 추가 Edit, +8줄)
  - `docs/OPERATIONAL_NOTES.md` (+1 항목)
- SSOT: `docs/API_SPEC.md` §KIS 실측 확정 (URL·식별자 교차검증)
- 산출물 경로 주의: 요청 경로 `docs/reviews/task-1-review.md`는 **다른 스프린트(refresh-recovery Task 1, 2026-06-01)** 리뷰가 이미 점유 중 — 덮어쓰면 기존 기록 소실(global §8.2)이라 충돌 회피용 네임스페이스 파일명으로 산출. (참고 항목 [참고-3] 참조)

## 전체 평가

KISEnvironment 4종 URL과 KISCredential 2종 식별자가 모두 API_SPEC.md 실측 확정값과 **문자 단위로 정확히 일치**한다(오타 0). KiwoomCredential·CRUD 로직은 diff상 단 한 글자도 변경되지 않았고(순수 additive), 키움 legacy 병존 전략(design.md:80)을 정확히 따른다. 숨겨진 auth/검증 로직 삽입 없음(KISEnvironment는 상수만, KeychainStore CRUD 무변경 — Floor 4 충족). 테스트 파일 수정·삭제 없음. 치명적 이슈는 없다. 단 KiwoomEnvironment 패턴과의 형식 일관성에서 권장 1건(enum 형태 불일치), 추가 검증 권고 1건(연결성 — 현 태스크에서는 호출처 부재가 의도된 것)이 있다.

## 변경 파일별 코멘트

### KISEnvironment.swift (신규)

**값 교차검증 — API_SPEC.md 대비 (중점 체크 1):**

| 상수 | 코드 값 | API_SPEC.md 실측값 | 출처 | 결과 |
|---|---|---|---|---|
| `restBaseURL` | `https://openapi.koreainvestment.com:9443` | `https://openapi.koreainvestment.com:9443` | L16 | ✅ 일치 |
| `tokenURL` | `https://openapi.koreainvestment.com:9443/oauth2/tokenP` | `POST /oauth2/tokenP` | L17 | ✅ 일치 (대문자 P 포함) |
| `approvalURL` | `https://openapi.koreainvestment.com:9443/oauth2/Approval` | `POST /oauth2/Approval` | L20 | ✅ 일치 (대문자 A 포함) |
| `webSocketURL` | `ws://ops.koreainvestment.com:21000` | `ws://ops.koreainvestment.com:21000` | L69 | ✅ 일치 (평문 ws, 포트 21000) |

- 4종 전부 정확. 특히 오타 시 자격증명/연결 실패로 직결되는 `tokenP`(대문자 P)·`Approval`(대문자 A)·평문 `ws`(wss 아님)·포트 9443/21000 모두 정확. force-unwrap(`URL(string:)!`)은 컴파일 타임 리터럴 상수라 안전(KiwoomEnvironment와 동일 관용).
- 주석 품질 우수: approvalURL의 body key가 `secretkey`(tokenP의 `appsecret`과 다름)라는 함정을 docstring(L13)에 명시 — API_SPEC.md L20 ⚠️ 경고와 정합. Task 5/9 후속 작업 포인터(ATS 예외, AppDelegate 조립)도 명시.

### KeychainStore.swift (KISCredential 추가)

**무변경 검증 — git diff (중점 체크 2):**

- diff는 파일 끝(L67 이후)에 `KISCredential` enum 8줄만 추가. `KeychainStore` struct(get/set/delete CRUD)·`KiwoomCredential` enum은 **단 한 글자도 변경 없음** — 순수 additive 확인.
- 식별자 교차검증:
  - `KISCredential.appKey` = `kr.co.koreainvestment.paragon.appkey` — API_SPEC.md L21 일치 ✅
  - `KISCredential.appSecret` = `kr.co.koreainvestment.paragon.appsecret` — API_SPEC.md L21 일치 ✅
  - `KiwoomCredential` 2종 = `kr.co.kiwoom.paragon.{appkey,appsecret}` — 무변경, API_SPEC.md L149 일치 ✅ (병존 유지)
- Floor 4(숨겨진 auth/검증 로직) 점검: CRUD 메서드 무변경, KISCredential은 식별자 문자열 상수만 — auth/검증 로직 삽입 0건 ✅. 값을 로그·예외에 노출하지 않는 기존 정책(L5)도 무변경.

### OPERATIONAL_NOTES.md (+1)

- `## 주의사항` 섹션에 1줄 추가(L14). KISEnvironment/KISCredential 병존, AppDelegate Task 10 전환 시점, "swift test 46 Suite passed, 회귀 0" 기록. 형식(`- [날짜] 내용 (에이전트)`) 준수. 50항목 한도 내. 적절.

## 발견된 이슈

### [권장] KISEnvironment가 KiwoomEnvironment의 enum-with-cases 패턴과 형식 불일치 (중점 체크 5)
- 위치: `KISEnvironment.swift:6-19` vs `KiwoomEnvironment.swift:5-24`
- 현재: `KiwoomEnvironment`는 `case real / case mock`를 가진 **인스턴스 enum**으로, URL을 computed property(`var restBaseURL: URL { switch self ... }`)로 real/mock 분기한다. 반면 `KISEnvironment`는 case 없는 **네임스페이스 enum**으로 `static let` 상수만 노출한다.
- 문제: 두 파일이 같은 디렉토리(`Network/`)·같은 역할(증권사 URL 상수)인데 구조가 다르다. 단순 스타일 차이로 보일 수 있으나, API_SPEC.md L16("모의 `openapivts:29443`은 🟡 미실측")·L69("모의 `:31000` 🟡 미실측")가 모의(VTS) 도메인을 **미래 확장 여지**로 남겨둔다. 현재 KISEnvironment는 실전 전용 평면 상수라 모의 추가 시 KiwoomEnvironment처럼 case 기반으로 리팩터링하거나 별도 상수를 늘려야 한다.
- 판단: API_SPEC.md L125가 "실전 검증 완료라 v1 불요"로 모의를 명시 배제했으므로 **현 시점 실전 전용 평면 enum은 scope상 정당**하다(over-engineering 회피 측면에선 오히려 적절). 단 주변 코드 일관성 관점에서 (a) 현 형태 유지 + "실전 전용, 모의는 scope 외(API_SPEC L125)" 1줄 주석 추가, 또는 (b) KiwoomEnvironment와 동일하게 `case real` 단일 case로 맞춰 패턴 통일 중 택1 권장. v1 차단 사유 아님.
- 수정 제안 (최소, 옵션 a):
  ```swift
  /// KIS(한국투자증권) Open API URL 상수 레이어. 실전 전용 — 모의(VTS) 도메인은 scope 외(API_SPEC §미실측 잔여, 실전 검증 완료로 v1 불요).
  /// KiwoomEnvironment(real/mock case enum)와 구조가 다른 이유: 모의 미사용으로 분기 불필요.
  public enum KISEnvironment {
  ```

### [참고] KISEnvironment·KISCredential 호출처 0건 — 이 태스크에서는 의도된 dead component
- 위치: 전 리포지토리 grep 결과 — `Sources`/`Tests` 어디에서도 `KISEnvironment`·`KISCredential` 참조 없음(정의 라인 제외).
- 내용: Floor 2(reachability) 관점에서 통상 "import 0 / 미연결"은 치명적이나, **이 태스크는 design.md:80 전략상 기반 레이어 선(先)배치이고 배선은 Task 5(TokenManager/WS)·Task 10(AppDelegate 조립)에서 수행**한다고 명시됐다. 즉 현 단계 미연결은 설계상 예정된 상태이며 치명 분류 대상 아님. OPERATIONAL_NOTES도 "Task 10에서 전환"으로 기록 정합.
- 후속 게이트 권고: **Task 10(AppDelegate 조립) 리뷰 시 KISCredential·KISEnvironment가 실제 호출 경로에 연결됐는지(import≠0, 키움→KIS 치환 완료)를 반드시 reachability 게이트로 검증**할 것. 기반 레이어가 끝까지 미연결로 남으면 그때는 치명(EYWA 라이브 미반영형 사고). 현 태스크에서는 PASS, 추적 항목으로만 등록.

### [참고] 산출물 경로 충돌 — task-1-review.md는 refresh-recovery 스프린트가 점유
- 위치: `docs/reviews/task-1-review.md` (기존 — refresh-recovery Task 1 / NetworkPathReachability / 2026-06-01)
- 내용: 요청된 산출 경로가 다른 기능의 스프린트 리뷰로 이미 사용 중. 덮어쓰면 기존 리뷰 기록이 소실되므로(global §8.2 — 원본 보존) 본 리뷰는 `docs/reviews/kis-migration-task-1-review.md`로 산출했다. 향후 스프린트 간 리뷰 파일명 충돌 방지를 위해 `{기능}-task-{N}-review.md` 네이밍 컨벤션 채택 권고(기존 refresh-recovery 파일들도 점진 리네임 검토).

## 정합성 점검 (중점 체크 요약)

| # | 중점 체크 | 결과 |
|---|---|---|
| 1 | URL 4종·식별자 2종 = API_SPEC.md 실측값 정확 일치 | ✅ PASS (오타 0, 위 교차검증표) |
| 2 | KiwoomCredential·CRUD 무변경 (diff 흔적 없음) | ✅ PASS (순수 additive, 변경 0) |
| 3 | 숨겨진 auth/검증 로직 삽입 없음 (Floor 4) | ✅ PASS (상수만, CRUD 무변경) |
| 4 | 기존 테스트 수정·삭제 없음 | ✅ PASS (diff에 test 파일 0) |
| 5 | 네이밍·스타일 주변 코드 일관 | △ 권장 (enum 형태 KiwoomEnvironment와 불일치 — scope상 정당하나 주석 권고) |

## 요약

| 심각도 | 건수 |
|--------|------|
| 치명적 | 0건 |
| 권장 | 1건 (KISEnvironment enum 형태 일관성 — 주석 또는 case 통일) |
| 참고 | 2건 (호출처 0건=의도된 선배치·Task 10 게이트 추적 / 산출 경로 충돌) |

## 최종 verdict

**치명 이슈 없음 — PASS.** URL 4종·Keychain 식별자 2종이 API_SPEC.md 실측 확정값과 문자 단위로 정확 일치하고(오타 0 — 자격증명/연결 실패 리스크 차단), KiwoomCredential·CRUD·테스트 모두 무변경(순수 additive)이며 숨겨진 auth/검증 로직 삽입이 없다. 키움 legacy 병존 전략을 정확히 준수했다. 권장 1건(enum 형식 일관성)은 scope상 현 평면 enum이 정당하므로 주석 보완 수준의 선택 사항이다.

## 다음 단계

1. (권장) KISEnvironment에 "실전 전용 / 모의 scope 외 / KiwoomEnvironment와 구조 상이 사유" 1줄 주석 추가 — 주변 코드 일관성·미래 모의 확장 의도 명문화.
2. (추적) Task 10(AppDelegate 조립) 리뷰에서 KISEnvironment·KISCredential의 실제 연결성(import≠0, 키움→KIS 치환)을 reachability 게이트로 검증 — 기반 레이어 미연결 잔존 방지.
3. (참고) `docs/reviews/` 스프린트 간 파일명 충돌 — `{기능}-task-{N}-review.md` 컨벤션 채택 검토.
