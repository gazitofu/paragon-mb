---
task: kis-migration / Task 3
qa_date: 2026-06-04
verdict: PASS
---

# QA Report — kis-migration Task 3

## 수용 기준 표

| ID | 항목 | 결과 | 근거 |
|---|---|---|---|
| V-C1 | `swift test` 전체 그린 (83개) | **PASS** | exit=0, 83/83 통과 |
| V-C1 | 건수 011 → 46×11=506필드 청킹 단언 존재·PASS | **PASS** | `testParseExecutionChunked_Count11_Produces11Records` — results.count==11, 전 레코드 price/change/previousClose 일치 |
| V-C1 | per-record [0]~[5] 교차검증 (005930 `356000^5^-4500^-1.25`, previousClose=360500) | **PASS** | `testParseRecord_PoC_005930` — price=356000, change=-4500, previousClose=360500 |
| V-C1 | 멀티 레코드(건수≥2) 명시 단언 | **PASS** | `testParseExecutionChunked_MultiRecord_SecondRecordCorrect` — count=2, results[1].code="000660", change=650, previousClose=73050 |
| V-C2 | Audit 7행 전수 체크 (아래 표 참조) | **PASS** | 7행 모두 실 테스트 존재·PASS |
| 회귀 | 기존 키움 9 케이스 무변경 PASS | **PASS** | `QuoteParsingTests` class 1~9 행 KiwoomQuoteParser/KiwoomRESTClient 호출 — 83개 전체 PASS 안에 포함 |
| 회귀 | KISRESTClientTests 19 + 그 외 무영향 PASS | **PASS** | TokenManagerTests 5·PriceDirectionTests·MarketClockTests·WatchlistStoreTests·KeychainStoreTests·PolicyTests·NetworkPathReachabilityTests 전부 포함 |
| scope 잠금 | 변경 4파일 한정 | **PASS** | `git status` untracked: KISQuoteParser.swift(신규), modified: KISRESTClient.swift / QuoteParsingTests.swift / OPERATIONAL_NOTES.md / SPRINT_PLAN.md (SPRINT_PLAN은 conductor 도메인, 위임 scope 외 — 내용 확인 불요) |

## Units & Signs Audit 7행 전수 체크리스트 (V-C2)

| # | function | input unit | output unit | sign convention | test proving it | 실존·PASS |
|---|---|---|---|---|---|---|
| 1 | `KISQuoteParser.parseRecord` [2]현재가 | 원 정수 문자열(`"356000"`) | `Int`(원) | 부호 없음(항상 양수) | `testParseRecord_PoC_005930` — price==356000 | **PASS** |
| 2 | `KISQuoteParser.parseRecord` [4]전일대비 | signed 문자열(`"-4500"`) | `Int`(원, signed 직접) | 음수=하락 직접 보존(abs 금지·sign 재구성 금지) | `testParseRecord_PoC_005930` — change==-4500, previousClose==360500 | **PASS** |
| 3 | `KISQuoteParser.parseRecord` [5]등락률 | signed 문자열(`"-1.25"`) | `Double`(%, signed) | 음수=하락 직접 | `testParseRecord_ChangeRate_SignedDirect` — changeRate≈-1.2482 (accuracy:0.001) | **PASS** |
| 4 | `KISQuoteParser.parseRecord` [3]sign | `"2"`/`"5"` | 검증 보조(부호 재구성 미사용) | 2=상승·5=하락; signed와 모순 시 signed 채택 | `testParseRecord_SignContradiction_SignedWins` — sign=2(상승 주장), change=-4500 → signed -4500 채택, direction=.down | **PASS** |
| 5 | `Quote.previousClose` (역산) | price − change | `Int`(원) | change 부호 보존 역산(356000−(−4500)=360500) | `testParseRecord_PoC_005930` — previousClose==360500 | **PASS** |
| 6 | `parsePrice` `prdy_vrss`(REST) | signed 추정(P5 🟡) | `Int`(원, signed 직접) | 하락 부호 P5 미실측 → signed 직접 파싱 | `testParsePrice_WithSdpr_005930` — change==-4500, previousClose==360500(stck_sdpr 우선) | **PASS** |
| 7 | `parseStockInfo` `prdt_abrv_name` | 문자열(trailing 공백) | `String`(trim) | N/A(부호 없음) | `testParseStockInfo_TrailingSpaceTrimmed` — "삼성전자   " → "삼성전자" | **PASS** |

## 테스트 실행 결과

```
swift test --parallel
Build complete! (0.09s)
[1/83]...[83/83] 전 케이스 통과
exit=0, 83 passed
```

- 로그: `/tmp/qa-kis-task3-1780550109.log`
- KIS 신규 케이스: `KISQuoteParserTests` 18개 (testParseSignedInt_Formats · testParseSignedDouble_Formats · testParseRecord_PoC_005930 · testParseRecord_ChangeRate_SignedDirect · testParseRecord_UpSign_ChangePositive · testParseRecord_SignContradiction_SignedWins · testParseRecord_Flat · testParseRecord_TooFewFields_ReturnsNil · testParseRecord_BadPrice_ReturnsNil · testParseExecutionChunked_Count11_Produces11Records · testParseExecutionChunked_MultiRecord_SecondRecordCorrect · testParseExecutionChunked_ZeroCount_Empty · testParseExecutionChunked_InsufficientFields_ReturnsEmpty · testParsePrice_WithSdpr_005930 · testParsePrice_NoSdpr_FallsBackToChange · testParsePrice_MissingPrice_ReturnsNil · testParseStockInfo_TrailingSpaceTrimmed · testParseStockInfo_WhitespaceOnlyName_ReturnsNil)
- 기존 키움 9케이스: `QuoteParsingTests` class — KiwoomQuoteParser/KiwoomRESTClient 무변경 PASS

## scope 잠금

`git status` 기준 변경 파일:
- `Sources/PMCore/Network/KISQuoteParser.swift` — 신규(untracked)
- `Sources/PMCore/Network/KISRESTClient.swift` — modified (R1 수렴 3줄: `lookupPrice` 내 KISQuoteParser.parseSignedInt 위임)
- `Tests/PMCoreTests/QuoteParsingTests.swift` — modified (KIS 섹션 추가, 기존 키움 9케이스 삭제·수정 0)
- `docs/OPERATIONAL_NOTES.md` — modified (+1줄)

위임 scope 4파일 내 한정. 제품 로직 `src/` 등 Edit 0건.

## 브라우저 검증

비대상 — UI 변경 없음 (파서 레이어 전용).

## 검증 체크리스트

- [x] 수용 기준 표 전항목 표기 (pass/fail/N/A — 누락 0건)
- [x] 테스트 실행 결과 인용 (로그 경로 포함)
- [x] UI 변경 없음 → 브라우저 검증 비대상
- [x] Units & Signs Audit 7행 전수 PASS
- [x] Write 권한 경계 위반 0건
- [x] 기존 테스트 삭제·수정 0건 (추가만)
- [x] return-contract 7섹션 표기
