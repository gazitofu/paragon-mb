# 코드 리뷰 리포트 — kis-migration Task 2 (`KISRESTClient.swift` 신규 264줄)

- 일자: 2026-06-04
- 모드: Strict (SPRINT_PLAN Meta — auth 접점 + provider 전면 교체)
- 대상: `Sources/PMCore/Network/KISRESTClient.swift` (신규) · `docs/OPERATIONAL_NOTES.md` (+1줄)
- 매핑: tasks.md T3+T4+T5 / design.md 결정 5·6·7·8 / API_SPEC §인증·§현재가·§종목명
- 검증 환경: `swift build` 성공 · `swift test` 46/46 PASS 회귀 0 · 키움 legacy 파일 git diff 0

## 전체 평가

엔드포인트·헤더·바디 키가 PoC 정답지(`kis-auth-poc.swift`/`kis-name-poc.swift`) 및 API_SPEC SSOT와 **정확히 일치**한다. 가장 혼동하기 쉬운 `appsecret`(tokenP) vs `secretkey`(Approval) 분기가 정확하고, 인라인 ⚠️ 주석으로 회귀 방어까지 했다. 600ms 스로틀이 actor 직렬 큐로 전역 보장되며 등록 2콜(`lookupName`→`lookupPrice`) 사이 EGW00201 회피 경로가 성립한다. `prdy_vrss` signed 직접 파싱 + sign 필드 미사용(경계 ④) 준수, 자격증명 평문 로깅/env 직접 읽기 없음(Floor 4·V-B2) 확인. 치명적 결함은 없다.

다만 두 가지가 Strict 게이트에서 걸린다: (1) 이 클라이언트의 **숫자 파싱 견고성이 같은 리포의 잠긴 SSOT(`KiwoomQuoteParser.parseSignedInt`)보다 약하다** — 콤마·부호 prefix 처리가 빠져 있어, `prdy_vrss` 하락 표현이 미실측(API_SPEC 🟡)인 현 상태에서 회귀 위험이 잠복한다. (2) Strict 모드인데 신규 순수 함수(`parseExpiry`, signed 파싱, `previousClose` 폴백)에 **단위/부호 테스트가 0건**이고 Units & Signs Audit 산출이 없다. 둘 다 Task 3(파서 재잠금)에서 흡수 가능하나 명시적으로 이월·기록되어야 한다.

## 발견된 이슈

### [치명적] 없음

도달성(reachability) 게이트: `KISRESTClient`는 신규 struct로 아직 호출처가 없으나, 이는 의도된 staged 구현이다(Task 5 AppDelegate 조립에서 배선). Task 1 리뷰 이월("Task 5 조립 리뷰에서 reachability 게이트 필수")과 동일 선상 — 본 태스크에서 dead component로 분류하지 않되, **Task 5 조립 리뷰에서 `KISRESTClient` 4개 public 메서드가 실제 호출 경로에 연결됐는지 반드시 검증**해야 한다(미연결 잔존 시 그 시점 치명).

### [권장] R1 — 숫자 파싱이 리포 내 잠긴 SSOT보다 약함 (콤마·부호 prefix 미처리)

- 위치: `KISRESTClient.swift:209,214,215` (`lookupPrice`)
- 현재 코드:
  ```swift
  guard let priceStr = out.stck_prpr, let price = Int(priceStr), price > 0 else { ... }
  let change = out.prdy_vrss.flatMap { Int($0) } ?? 0
  let previousClose = out.stck_sdpr.flatMap { Int($0) } ?? (price - change)
  ```
- 문제: 같은 리포의 **부호·스케일 SSOT**인 `KiwoomQuoteParser.parseSignedInt`(KiwoomQuoteParser.swift:23)는 `"+1,500"`·`"-650"` 같은 콤마/부호 prefix를 명시 처리(`replacingOccurrences(of: ",", with: "")` + `Int`)한다. KIS REST는 현재 "plain 정수, 콤마 없음"이 실측이지만 — API_SPEC §미실측 잔여가 명시하듯 — **`prdy_vrss` 하락 시 음수(`-` prefix) 표현은 직접 실측되지 않은 🟡 가정**이다. 만약 KIS가 `prdy_vrss`에 `-`를 붙여 반환하면 `Int("-3000")`은 통과하지만(Swift Int는 `-` 허용), 향후 어떤 KIS 필드가 콤마 그룹핑을 쓰면 `Int($0)`는 nil → `change=0`으로 **조용히 오역산**된다(throw 아님, 등락 0원으로 표시). 동일 도메인에 이미 견고한 파서가 있는데 신규 경로만 약한 것은 일관성·회귀 측면에서 권장 수정 대상.
- 수정 제안: signed/콤마 처리를 공유 유틸로 경유. Task 3에서 `KISQuoteParser`를 만들 때 REST 경로 숫자 파싱도 그 파서(또는 `parseSignedInt` 동급 유틸)로 수렴시키면 SSOT가 하나로 잠긴다. 최소 조치로는 `lookupPrice` 내 `Int(priceStr)` → `Int(priceStr.replacingOccurrences(of: ",", with: ""))` 동급 정규화.
- 처리: **Task 3(파서 재잠금)으로 이월** 권장 — 단독 수정보다 KIS 파서 SSOT 통합 시점에 함께.

### [권장] R2 — Strict 모드인데 신규 순수 함수 테스트 0건 + Units & Signs Audit 미산출

- 위치: `parseExpiry`(222–235) · `previousClose` 폴백(215) · signed change(214)
- 문제: 모드 = Strict. appdev/CLAUDE.md §4 "Units & Signs audit (mandatory before PASS verdict)"는 모든 수치 변환(ms↔s, 부호, 통화)에 **통과하는 테스트 레퍼런스**를 요구한다. 본 태스크가 새로 도입한 변환은 ⓐ `expires_in`(초) → `Date` ⓑ `access_token_token_expired`(KST 문자열) → `Date` ⓒ `stck_sdpr`/`price−change` → `previousClose`(원, 부호). 그런데 비교 대상인 키움 `parseExpiry`는 **static + 전용 테스트 3건**(QuoteParsingTests.swift:55–67)을 가진 반면, KIS `parseExpiry`는 **instance 메서드 + 테스트 0건**이다. `swift test` 46건은 전부 기존 자산이며 KIS 신규 경로를 한 줄도 커버하지 않는다(`grep` 확인). KST 타임존·`expires_in` 우선순위·폴백 23h 같은 분기는 회귀 시 토큰 만료 오판 → 분당 1회 위반(R6)로 번질 수 있는 지점이라 테스트 부재가 Strict 기준 미달.
- 수정 제안: Task 3에 KIS 시세/만료 테스트 묶을 때 (1) `parseExpiry` expires_in 우선·KST 폴백·둘 다 실패 시 23h 케이스 (2) `previousClose` = `stck_sdpr` 우선 / 폴백 역산 케이스를 Units & Signs Audit 행으로 추가. `parseExpiry`가 instance 메서드라 테스트하려면 `KISRESTClient()` 인스턴스 생성이 필요 — 키움처럼 `static`으로 두는 편이 테스트 용이(아래 R3와 연결).
- 처리: **Task 3으로 이월 + SPRINT_PLAN에 이월 사유 기록** 권장.

### [권장] R3 — `parseExpiry` instance 메서드 (키움은 static, 테스트 용이성·일관성 저하)

- 위치: `KISRESTClient.swift:222` `func parseExpiry(...)` (instance, non-private)
- 현재 코드: `func parseExpiry(expiresIn: Int?, expiredAt: String?) -> Date`
- 문제: 인스턴스 상태(`session`·`throttle`·`environment`)를 전혀 쓰지 않는 순수 함수인데 instance 메서드다. 대응되는 `KiwoomRESTClient.parseExpiry`는 `static`이라 `QuoteParsingTests`가 인스턴스 없이 직접 호출·잠금한다(QuoteParsingTests.swift:55). KIS 쪽만 instance면 (a) 테스트 시 불필요한 `KISRESTClient()` 생성 (b) 두 클라이언트 패턴 불일치. `internal`(non-private) 가시성인 것으로 보아 테스트 노출 의도는 있으나 static이 더 자연스럽다.
- 수정 제안: `static func parseExpiry(...)`로 변경. 호출부 `parseExpiry(...)` → `Self.parseExpiry(...)`(line 127) 한 줄 수정. developer Open Question 1(KISEnvironment 정적 참조)과 같은 결의 일관성 정리.

### [참고] N1 — `prdy_ctrt`·`prdy_vrss_sign`·`pdno` 디코드되나 미사용 (의도된 검증/문서용)

- 위치: DTO `InquirePriceOutput`(65–69) `prdy_ctrt`·`prdy_vrss_sign`·`stck_shrn_iscd` / `StockInfoOutput.pdno`(53)
- 내용: 이 필드들은 `Decodable`에만 있고 산출 로직에서 쓰이지 않는다. `prdy_vrss_sign`은 "검증용만"이라는 주석이 있으나 실제 검증(예: signed change 부호와 sign 필드 일치 assert)은 하지 않는다. dead field는 아니다 — 등락률은 `Quote.changeRate`가 재파생(K8 단일출처)하므로 `prdy_ctrt`를 안 쓰는 것이 오히려 옳고, sign 필드를 재구성에 쓰지 않는 것이 경계 ④ 준수의 핵심이다. 즉 **의도된 비사용**. 다만 향후 라이브에서 sign 일치 검증을 붙이려면 이 필드가 진입점이라는 메모만 남긴다.
- 조치 불요(참고).

### [참고] N2 — `previousClose` 폴백 `price - change`가 Quote.change와 동어반복적

- 위치: `KISRESTClient.swift:215`
- 내용: `Quote.change`는 `price - previousClose`(Quote.swift:15)로 정의된다. 폴백 `previousClose = price - change`를 쓰면 `Quote.change`를 역산하면 정확히 원래 `change`로 환원되어 **등락액은 항상 prdy_vrss와 일치**(자기무모순). 즉 `stck_sdpr` 부재 시 등락액 표시는 정확하지만 등락률 분모(previousClose)가 `prdy_vrss` 기반 역산값이 되어, KIS의 `prdy_ctrt`(실제 등락률)와 미세하게 어긋날 수 있다. 정상 경로(`stck_sdpr` 존재, API_SPEC 실측에서 005930 항상 존재)에서는 무관하고, 키움 WS 파서도 동일 역산 패턴(KiwoomQuoteParser.swift:18)이라 **설계 일관**. 폴백은 stck_sdpr 누락이라는 비정상 응답 방어용이므로 현 구현 합당. 참고로만 기록.

### [참고] N3 — `assertSuccess`: `rt_cd` 부재를 성공 간주 (P6 1차 가정)

- 위치: `KISRESTClient.swift:241` `guard let rc = rt_cd else { return }`
- 내용: `rt_cd`가 응답에 없으면 성공으로 통과시킨다. API_SPEC §종목명/§현재가 실측 응답은 항상 `rt_cd:"0"`을 포함하므로 정상 경로에서 문제없다. 미존재 코드/에러 응답 형태가 🟡 미실측(API_SPEC §미실측 잔여)이라 P6 1차 가정으로 명시돼 있고, output 가드(178–180, 206–211)가 2차 방어선이라 누락 종목은 결국 `lookupFailed`로 잡힌다. 라이브 관측 후 보정 대상이라는 주석도 정확. 현 단계 합당, 라이브 에러 분기 구현 시 재방문.

## Open Questions 회신 (developer 질의 2건)

1. **KISEnvironment 정적 참조 패턴** — 현 혼용(`environment` 인스턴스 필드 보관 + 메서드 내 `KISEnvironment.xxx` 직접 참조)은 **기능상 무해하나 일관성 미흡**. `private let environment: KISEnvironment.Type`(93)을 init에서 보관하지만 실제로는 메서드들이 `KISEnvironment.tokenURL`(107) 등 타입 직접 참조라 `environment` 필드가 사실상 미사용(dead field에 근접). 둘 중 하나로 통일 권장: (a) 필드 제거하고 전부 직접 참조(KISEnvironment가 enum 정적 상수라 주입 불요), 또는 (b) 테스트 시 base URL 교체가 필요하면 필드 경유로 통일. 시세 전용·실전 단일 도메인 scope에선 (a)가 단순. **참고 등급** — 동작 영향 없음.

2. **`issueToken`만 스로틀 미경유 분리** — design.md 결정 5·7과 **정합**. 결정 7(line 175)은 스로틀을 "EGW00201(초당 건수 초과) 회피" 목적의 조회 호출 전역 정책으로 규정하고, 결정 5(line 173)·R6(line 189)는 토큰 **분당 1회** 제한을 별도 메커니즘(TokenManager 캐시 + margin 300s)이 담당한다고 명시 분리한다. 즉 두 제한은 출처가 다르다(초당 거래건수 vs 분당 재발급). `issueToken`을 스로틀 큐에 넣어도 분당 1회를 막지 못하고(600ms ≪ 60s), 막는 주체는 TokenManager 캐시다. 따라서 `issueToken` 스로틀 미경유 + TokenManager 위임은 **설계 의도대로**다. 단 `issueApprovalKey`는 스로틀 경유(134)인데, 이건 REST 초당 한도 공유 가능성 대비 보수적 선택으로 무해. 정합 확인.

## 중점 체크 결과 (프롬프트 6항)

1. 엔드포인트·헤더·바디 키 정확성 — **PASS**. tokenP=`appsecret`(113)·Approval=`secretkey`(141) 분기 정확, tr_id `CTPF1002R`(171)·`FHKST01010100`(199)·`custtype:P`(255)·query(`PRDT_TYPE_CD=300`·`FID_COND_MRKT_DIV_CODE=J`) 전부 PoC·API_SPEC 일치.
2. 600ms 스로틀 전역 보장 — **PASS**. `ThrottleQueue` actor의 last-call 가드(77–88)가 직렬화. `lookupName`(162)·`lookupPrice`(190)·`issueApprovalKey`(134) 모두 `await throttle.waitIfNeeded()` 경유 → 등록 2콜 사이 ≥600ms 보장, EGW00201 회피 성립.
3. signed 직접 파싱 + previousClose 단위·부호 — **PASS(권장 R1·N2 단서)**. `prdy_vrss` signed 직접(214), sign 필드 재구성 없음(경계 ④ 준수). `stck_sdpr` 우선/역산 폴백 부호·단위 정확. 단 콤마/부호 prefix 견고성은 R1 참조.
4. 자격증명 평문 로깅·env 직접 읽기 없음 — **PASS**. `print`/로깅 0건, env 파일 접근 0건. 자격증명은 파라미터 주입만(106·133·161·189), 헤더 setValue만(252–253). Floor 4·V-B2 충족. 단 헤더에 평문 secret이 실리는 것은 API 계약상 불가피(HTTPS 9443 전송).
5. 에러 매핑이 SymbolLookupError 계약 연결 가능 형태 — **PASS(주의)**. `SymbolLookupError`는 **아직 리포에 미존재**(grep 확인 — Sources/Tests 0건). tasks.md T10·design.md:273이 명시하듯 Task 5 AppDelegate가 `KISRESTClient.RESTError → SymbolLookupError`를 매핑 주입할 예정이다. 현 `RESTError`는 `Equatable` + 케이스 분리(`lookupFailed`/`apiError`/`tokenRejected`/`missingToken`/`http`/`decodingFailed`)가 충분히 세분화돼 매핑 가능. Task 5 조립 시 매핑 누락 없는지 확인 필요(이월).
6. 키움 legacy·기존 테스트 무변경 — **PASS**. git diff에 Kiwoom* 파일 0건, `swift test` 46/46 회귀 0, 기존 테스트 무수정 확인.

## 요약

| 심각도 | 건수 |
|--------|------|
| 치명적 | 0건 |
| 권장 | 3건 (R1 파싱 견고성 · R2 테스트/Units&Signs 부재 · R3 parseExpiry static화) |
| 참고 | 5건 (N1 미사용 필드 · N2 폴백 동어반복 · N3 rt_cd 부재 · OQ1 environment 필드 · OQ2 정합 확인) |

## 다음 단계 (우선순위)

1. **(이월·필수)** R2 — Task 3(KIS 파서 재잠금)에서 `parseExpiry`·`previousClose`·signed change에 Units & Signs Audit 행 + 테스트 추가. Strict 모드 PASS 정식 요건. SPRINT_PLAN에 이월 사유 명기.
2. **(이월·권장)** R1 — Task 3 KIS 파서 SSOT 통합 시 REST 숫자 파싱도 콤마/부호 정규화 유틸로 수렴(`parseSignedInt` 동급).
3. **(선택)** R3 — `parseExpiry` static화 + R2 테스트 용이성 확보를 한 번에.
4. **(Task 5 이월·필수)** reachability 게이트 — `KISRESTClient` 4 메서드가 AppDelegate 조립 후 실제 호출 경로 연결 확인 + `RESTError→SymbolLookupError` 매핑 누락 검증.

> 본 태스크 자체에 치명적 결함 없음 — 신규 staged 컴포넌트로서 Task 2 범위 내 PASS. 권장 3건은 Strict 모드 완결을 위해 Task 3에서 흡수하고 이월 기록할 것.
