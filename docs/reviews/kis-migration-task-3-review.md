# 코드 리뷰 리포트 — kis-migration Task 3 (KISQuoteParser 신규 + R1 수렴)

> 리뷰일: 2026-06-04 / 리뷰어: reviewer (모드 1) / 모드: Strict
> 대상: 부호·청킹 정확성 (스프린트 최대 리스크 — 과거 D7-B 부호 반전·D8 ×10⁶ 사고 맥락)

## 전체 평가

Task 3의 부호·청킹 핵심 로직은 **견고하고 정확하다.** signed 직접 파싱 원칙(경계 규칙 ④)이 코드 전반에서 일관되게 지켜졌고 — `abs()`·`.magnitude`·`max(0,…)`·sign 기반 change 재구성이 **0건** — sign 필드는 교차검증 로그로만 격리됐다. 청킹 오프셋(`base = i*46`)은 정확하며, 멀티 레코드 테스트가 서로 다른 종목·부호 값으로 2번째 레코드를 실제 단언해 "1번째만 검증하는 가짜 테스트" 함정을 피했다. previousClose 역산(`price − change`)은 `Quote.change`(파생 `price − previousClose`)와의 순환에서 부호를 정확히 복원한다. 기존 키움 9케이스·KISRESTClientTests 19케이스 단언 무변경(git diff로 삭제·수정 0 확인), 전체 PMCore 83/83 PASS 회귀 0. R1 수렴 Edit은 동작 무변경·견고성만 강화. 치명적 이슈 없음. 발견된 권장·참고 항목은 모두 Task 3 범위 경계 또는 차기 라이브 검증으로 자연 귀속된다.

## 검증 실행 결과 (리뷰어 실측)

- `swift test --filter KISQuoteParserTests` → **18/18 PASS** (sign 모순 DEBUG 로그 정상 출력 확인)
- `swift test` (PMCore 전체) → **83/83 PASS, 0 failures** (회귀 0 — 개발자 보고치 일치)
- 키움 `QuoteParsingTests` 9케이스 "Executed 9 tests, 0 failures" 보존
- `git diff HEAD` — KiwoomQuoteParser.swift **무변경**, KISRESTClientTests.swift **무변경**, QuoteParsingTests.swift 순수 추가(+210, 삭제 0)

## 중점 체크 결과 (요청 7항목)

| # | 체크 | 결과 | 근거 |
|---|------|------|------|
| 1 | 청킹 오프셋·2번째 레코드 실단언 | PASS | `base=i*46`, `fields[base..<base+46]` 정확. `testParseExecutionChunked_MultiRecord_SecondRecordCorrect`가 rec2(000660, change=650, prevClose=73050, .up)를 별도 단언 — 진짜 테스트 |
| 2 | 부호 보존(abs/sign재구성/max(0) 0건) | PASS | grep 0건. `change=parseSignedInt(fields[4])` 직접. 모순 시 signed 채택을 `testParseRecord_SignContradiction_SignedWins`가 change==-4500·.down 단언으로 증명 |
| 3 | previousClose 역산 부호 | PASS | `356000−(−4500)=360500`. Quote.change가 `price−previousClose`로 -4500 복원. 방향 오류 없음 |
| 4 | Audit 7행 ↔ 테스트 실매핑(성명-실체) | PASS | 7행 전부 실재 테스트·해당 단언 포함(아래 표) |
| 5 | 키움 9 + KISREST 19 단언 무변경 | PASS | git diff 삭제·수정 0, 두 파일 stat 무변경 |
| 6 | R1 수렴이 동작 불변 | PASS | `Int(...)`→`parseSignedInt(...)` 3곳만, 의미 동일. KISRESTClientTests 음수 역산 단언 회귀 통과 |
| 7 | V-C1 건수 011 실측 46×11 단언 | PASS | `testParseExecutionChunked_Count11_Produces11Records` 506필드·11레코드 단언 |

### Units & Signs Audit 표 7행 매핑 (성명-실체 대조)

| Audit row | 매핑 테스트 (실재 확인) | 핵심 단언 |
|---|---|---|
| 1 [2]현재가 원정수 양수 | `testParseRecord_PoC_005930` + `testParseSignedInt_Formats` | price==356000 |
| 2 [4]전일대비 signed | `testParseRecord_PoC_005930` | change==-4500, prevClose==360500 |
| 3 [5]등락률 signed | `testParseRecord_ChangeRate_SignedDirect` | rate≈-1.248 (accuracy 0.001) |
| 4 [3]sign 검증·모순시 signed | `testParseRecord_SignContradiction_SignedWins` | change==-4500, .down |
| 5 previousClose 역산 | `testParseRecord_PoC_005930` | prevClose==360500 (=stck_sdpr) |
| 6 parsePrice prdy_vrss(REST) | `testParsePrice_WithSdpr_005930` + `_NoSdpr_FallsBackToChange` | prevClose==360500 (자동 테스트가 V-A3 라이브 보강) |
| 7 parseStockInfo trim | `testParseStockInfo_TrailingSpaceTrimmed` | name=="삼성전자" |

→ 7행 전부 실재 테스트로 매핑되고 명시 단언을 포함. Audit 게이트 충족.

## 발견된 이슈

### [권장] parseStockInfo가 inquire-price 필드(stck_prpr/stck_sdpr)로 Quote 생성 — CTPF1002R 실측 필드와 불일치 소지
- 위치: `KISQuoteParser.swift:58-76` (`parseStockInfo`)
- 현재: 함수 docstring은 "CTPF1002R(주식기본조회) JSON → (Symbol, Quote)"인데, Quote 생성에 `stck_prpr`·`stck_sdpr`를 읽는다.
- 문제: API_SPEC.md §종목명 조회(CTPF1002R) 실측 필드 화이트리스트는 `prdt_abrv_name`·`pdno`·`std_pdno`·`bfdy_clpr`이다. `stck_prpr`/`stck_sdpr`는 **inquire-price(FHKST01010100)의 필드**이며 CTPF1002R 응답엔 없을 공산이 크다(전일종가는 `bfdy_clpr`). 즉 실 CTPF1002R 페이로드에서는 두 필드가 nil → `return nil`(Quote 없음)로 떨어질 가능성. 테스트는 `stck_*`를 주입해 통과하므로 이 갭이 가려진다. **단, 실 등록 플로우는 `KISRESTClient.lookupName`(자체 디코딩, parseStockInfo 미경유) + `lookupPrice` 2콜 구조이고 parseStockInfo는 현재 호출처가 없다.** 라이브 영향은 없으나 함수 시맨틱과 SSOT가 어긋나 차후 오용 위험.
- 수정 제안: (a) parseStockInfo가 실제로 쓰일 경로가 없다면 도달성 관점에서 제거 검토(아래 참고 이슈), 또는 (b) CTPF1002R 실측 필드 기준으로 전일종가는 `bfdy_clpr`를 읽도록 정정하고 docstring과 일치시킨다. Task 3 범위 밖이면 차기 태스크 또는 ops 노트에 갭으로 등록.

### [권장] lookupPrice의 stck_sdpr는 sdpr>0 가드 없음 — parsePrice와 비대칭
- 위치: `KISRESTClient.swift:216` vs `KISQuoteParser.swift:87`
- 현재: `parsePrice`는 `sdpr > 0`일 때만 sdpr 채택(0/음수면 역산 폴백). `lookupPrice`는 `out.stck_sdpr.flatMap { parseSignedInt($0) } ?? (price - change)` — sdpr가 "0"으로 파싱되면 `previousClose=0` 채택 → `changeRate`가 0 나눗셈 가드로 0 반환되어 등락률 소실.
- 문제: R1 범위(3줄 수렴) 자체는 이 비대칭을 도입하지 않았다(기존 `Int($0) ?? ...`도 동일하게 가드 없었음 — 동작 무변경 확정). 그러나 두 경로의 sdpr 가드 비대칭은 잠재 부호/스케일 함정.
- 수정 제안: lookupPrice에도 `sdpr > 0` 가드 추가로 parsePrice와 동작 정렬. **R1 범위 밖이므로 이번 커밋 강제 아님** — 차기 정합 태스크 또는 ops 노트 등록 권장.

### [참고] parseStockInfo·parseSignedDouble 도달성 — 현재 프로덕션 호출처 0
- 위치: `KISQuoteParser.swift:58`(parseStockInfo), `:106`(parseSignedDouble)
- 현재: 두 함수 모두 테스트에서만 호출되고 Sources 내 프로덕션 호출 경로가 없다(parseSignedDouble는 등락률을 Quote 파생에 맡기므로 파서가 직접 쓰지 않음).
- 문제: Floor 2(도달성) 관점에서 dead component 소지. 단 — Task 3는 파서 유틸 모듈 신규이고, parseStockInfo/parseSignedDouble는 향후 태스크(T5 lookupName 정합·등락률 직접검증)에서 호출될 설계 의도가 design.md에 있을 수 있다. 빌드·타입체크 통과 + 라이브 미반영 위험(EYWA 사고 유형)은 **현 시점 없음**(WS/REST 실경로는 parseExecutionChunked·parseRecord·parsePrice·parseSignedInt를 사용하며 이들은 T6/T8/R1에서 연결). over-engineering 경계 차원의 참고 — 차기 태스크에서 실호출 연결 또는 미사용 확정 시 정리.

### [참고] Count11 테스트는 동일 레코드 11개 — 오프셋 시프트 단독 검출 불가
- 위치: `QuoteParsingTests.swift:193`
- 현재: 11레코드를 모두 동일 005930 값으로 구성. 이 테스트만으로는 청킹이 1필드 밀려도 통과할 수 있다.
- 문제: 단독으로는 약하나, `MultiRecord` 테스트(서로 다른 종목·값)가 오프셋 시프트를 정확히 검출하므로 **두 테스트 조합으로 갭이 메워진다.** Count11은 "건수 011 → 11개 산출"의 개수 검증 목적으로 적절. 회귀 강화를 원하면 Count11도 인덱스별로 약간 다른 값을 넣으면 단독 견고성 향상.

### [참고] sign 모순 로그가 #if DEBUG 격리 — 운영 ops 수집 경로 없음
- 위치: `KISQuoteParser.swift:122-126`
- 현재: 모순 시 `print`만(DEBUG 빌드 한정), 주석엔 "ops 노트 수집 경로"라 표기.
- 문제: 운영 빌드에서 sign vs signed 모순이 발생해도 수집되지 않는다. signed 채택은 정확하므로 표시 정확성엔 무해하나, 부호 체계 미실측 잔여(1/3/4, P5)를 라이브에서 좁히려면 모순 빈도 텔레메트리가 유용. 현 scope(시세 전용·라이브 검증 차기)에선 비-blocking. 차기 라이브 단계에서 ops 카운터 연결 고려.

## 요약

| 심각도 | 건수 |
|--------|------|
| 치명적 | 0건 |
| 권장 | 2건 |
| 참고 | 3건 |

## 다음 단계

1. (권장) parseStockInfo의 CTPF1002R 필드 불일치 — design.md/SSOT 대조 후 정정 또는 제거 결정(차기 태스크 또는 ops 노트 등록). 라이브 영향 없음 → 이번 커밋 비차단.
2. (권장) lookupPrice `sdpr>0` 가드 비대칭 — parsePrice와 정렬(차기 정합 태스크).
3. (참고) parseStockInfo/parseSignedDouble 도달성 — 후속 태스크에서 실호출 연결 확인 또는 미사용 확정.
4. 부호·청킹·역산·Audit 7행·회귀 0 — **PASS.** 커밋 진행 가능.

## 판정: PASS

부호·단위·청킹 정확성 전부 통과, 회귀 0, 기존 단언 무변경. 발견된 권장 2·참고 3은 모두 Task 3 범위 경계 또는 차기 라이브 검증으로 귀속되는 비차단 항목.
