# KIS Migration Task 2 QA Report

**날짜**: 2026-06-04  
**태스크**: KISRESTClient 골격 구현 (264줄)  
**판정**: PASS

---

## 1. 수용 기준 체크리스트

| # | 항목 | 판정 | 근거 |
|---|---|---|---|
| 1 | 회귀 0 — 기존 46개 PASS, 기존 테스트 파일 변경 0 | PASS | `swift test` exit=0, 46 passed (기존) + 19 신규 = 65 총계. 기존 테스트 파일 변경 없음 (`git diff --stat`: `OPERATIONAL_NOTES.md` +1, `SPRINT_PLAN.md` status 업데이트만). |
| 2 | 값 정합 샘플링 — 엔드포인트·tr_id·바디 키·`prdt_abrv_name`·필드명이 API_SPEC.md 실측값과 일치 | PASS | 아래 §2 grep 대조 참조. |
| 3 | scope 잠금 — 변경 diff가 지정 2파일 한정 (docs/sprints·docs/reviews 예외 허용) | PASS | `git status` 확인: 신규 `KISRESTClient.swift` + modified `OPERATIONAL_NOTES.md`. `SPRINT_PLAN.md`(reviewer 업데이트)·`kis-migration-task-2-review.md`(reviewer 산출물)·`KISRESTClientTests.swift`(QA 신규)는 예외 허용 범위. 제품 로직 파일 직접 수정 0건. |
| 4 | 빌드 무경고 회귀 — 신규 파일이 새 Swift 경고를 추가하지 않음 | PASS | `swift build 2>&1 \| grep -i warning` 출력 0건. 기지 노이즈(NetworkPathReachabilityTests Sendable)는 테스트 타깃이므로 `swift build` 미포함, 정상. |

---

## 2. 값 정합 샘플링 (API_SPEC.md 독립 재확인)

### 인증

| 검증 항목 | KISRESTClient.swift 값 | API_SPEC.md 실측값 | 일치 |
|---|---|---|---|
| tokenP 경로 | `/oauth2/tokenP` | `POST /oauth2/tokenP` | O |
| tokenP 바디 키 | `"appsecret"` | body `{..., appsecret}` | O |
| Approval 경로 | `/oauth2/Approval` | `POST /oauth2/Approval` | O |
| Approval 바디 키 | `"secretkey"` | body `{..., secretkey}` (tokenP와 다름 — 실측) | O |

### 현재가 REST — FHKST01010100

| 검증 항목 | KISRESTClient.swift 값 | API_SPEC.md 실측값 | 일치 |
|---|---|---|---|
| 경로 | `/uapi/domestic-stock/v1/quotations/inquire-price` | `GET /uapi/domestic-stock/v1/quotations/inquire-price` | O |
| tr_id | `"FHKST01010100"` | `tr_id: FHKST01010100` | O |
| 쿼리 — 시장구분 | `FID_COND_MRKT_DIV_CODE=J` | `FID_COND_MRKT_DIV_CODE=J` | O |
| 필드 — 현재가 | `stck_prpr` | `stck_prpr` | O |
| 필드 — 전일대비 | `prdy_vrss` | `prdy_vrss` | O |
| 필드 — 전일종가 | `stck_sdpr` | `stck_sdpr` (기준가=전일종가) | O |
| 필드 — 등락률 | `prdy_ctrt` | `prdy_ctrt` | O |
| 필드 — 종목코드 | `stck_shrn_iscd` | `stck_shrn_iscd` | O |

### 종목명 조회 REST — CTPF1002R

| 검증 항목 | KISRESTClient.swift 값 | API_SPEC.md 실측값 | 일치 |
|---|---|---|---|
| 경로 | `/uapi/domestic-stock/v1/quotations/search-stock-info` | `GET /uapi/domestic-stock/v1/quotations/search-stock-info` | O |
| tr_id | `"CTPF1002R"` | `tr_id: CTPF1002R` | O |
| 쿼리 — 상품유형 | `PRDT_TYPE_CD=300` | `PRDT_TYPE_CD=300` (주식·ETF·ETN·ELW) | O |
| 필드 — 상품약어명 | `prdt_abrv_name` | `prdt_abrv_name` (앱 표시명) | O |
| trailing trim | `trimmingCharacters(in: .whitespaces)` | msg1 trailing 공백 패딩 — trim 필요 | O |

---

## 3. 테스트 실행 결과

```
swift test — exit=0
65 tests, 0 failures
  KISRESTClientTests:  19 passed (신규)
  기존 46개:           46 passed (회귀 0)
```

**로그**: `/tmp/qa-kis-task2-final2-1780548222.log` (175줄)

### 신규 테스트 19건 목록

**parseExpiry (5건)**
- `testParseExpiry_ExpiresIn_86400` — expires_in=86400 우선 경로
- `testParseExpiry_ExpiredAt_KST` — KST "yyyy-MM-dd HH:mm:ss" 폴백
- `testParseExpiry_ZeroExpiresIn_FallsBackToExpiredAt` — expires_in=0 → expiredAt 폴백
- `testParseExpiry_BothNil_Returns23hFallback` — 양쪽 nil → 23h 폴백
- `testParseExpiry_EmptyExpiredAt_Returns23hFallback` — 빈 문자열 → 23h 폴백

**issueToken (3건)**
- `testIssueToken_EndpointAndBodyKey` — `/oauth2/tokenP` + `appsecret` 키명
- `testIssueToken_RtCdNonZero_ThrowsTokenRejected` — rt_cd≠"0" → tokenRejected
- `testIssueToken_HTTP401_ThrowsHttp` — HTTP 401 → http(401)

**issueApprovalKey (1건)**
- `testIssueApprovalKey_EndpointAndBodyKey` — `/oauth2/Approval` + `secretkey` 키명

**lookupName (4건)**
- `testLookupName_EndpointTrIdAndQuery` — 경로·CTPF1002R·PRDT_TYPE_CD=300·PDNO
- `testLookupName_TrailingSpaceTrimmed` — prdt_abrv_name trailing 공백 trim
- `testLookupName_RtCdNonZero_ThrowsApiError` — rt_cd≠"0" → apiError
- `testLookupName_EmptyName_ThrowsLookupFailed` — 공백만 → lookupFailed

**lookupPrice (4건)**
- `testLookupPrice_EndpointTrIdAndFields` — 경로·FHKST01010100·FID_COND_MRKT_DIV_CODE=J
- `testLookupPrice_NoSdpr_FallsBackToChange` — stck_sdpr 누락 시 역산
- `testLookupPrice_MissingPrice_ThrowsLookupFailed` — stck_prpr 누락 → lookupFailed
- `testCommonHeaders_LookupName` — authorization Bearer·appkey·appsecret·custtype=P

**Units & Signs Audit (2건)**
- `testLookupPrice_SignedPrdyVrss_NegativeWithSdpr` — prdy_vrss 음수 + stck_sdpr 우선
- `testLookupPrice_SignedPrdyVrss_NegativeNoSdpr` — prdy_vrss 음수 + 역산

---

## 4. Units & Signs Audit (PASS 게이트)

| function | input unit | output unit | sign convention | test proving it |
|---|---|---|---|---|
| `parseExpiry(expiresIn:expiredAt:)` | seconds (Int) / KST string | `Date` | +only (seconds > 0 gate) | `testParseExpiry_ExpiresIn_86400` |
| `lookupPrice` → `Quote.price` | 원 정수 문자열 (`stck_prpr`) | 원 (Int) | 양수만 (0 < price guard) | `testLookupPrice_EndpointTrIdAndFields` |
| `lookupPrice` → `Quote.previousClose` | 원 정수 문자열 (`stck_sdpr`) / 역산 | 원 (Int) | — | `testLookupPrice_SignedPrdyVrss_NegativeWithSdpr` |
| `lookupPrice` → `Quote.change` (파생) | — | 원 (Int) | price − previousClose, signed | `testLookupPrice_SignedPrdyVrss_NegativeWithSdpr` (−4500) |
| `prdy_vrss` signed 직접 파싱 | signed 원 정수 문자열 | Int (flatMap Int()) | 음수 직접, 부호필드 재구성 금지 | `testLookupPrice_SignedPrdyVrss_NegativeNoSdpr` |

---

## 5. scope 검증 상세

`git status` 결과:
- **modified**: `docs/OPERATIONAL_NOTES.md` (+1줄), `docs/sprints/SPRINT_PLAN.md` (reviewer 업데이트, 예외 허용)
- **untracked**: `Sources/PMCore/Network/KISRESTClient.swift` (신규 태스크 대상), `Tests/PMCoreTests/KISRESTClientTests.swift` (QA 신규), `docs/reviews/kis-migration-task-2-review.md` (reviewer 산출물, 예외 허용)
- 제품 로직 기존 파일 수정 0건

---

## 6. 비-UI 변경 확인

변경 파일 목록에 `.tsx/.jsx/.css/.scss/page.*/layout.*` 없음 — 브라우저 검증 비대상 (Network 레이어만).
