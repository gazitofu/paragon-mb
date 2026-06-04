# API Spec — PARAGON-MB

> 갱신: 2026-06-04 (KIS 전환 [2] 필드 실측 완료 — 문서를 KIS 기준으로 재작성).
> **Provider = 한국투자증권(KIS) Open API** — 키움 완전 대체 결정(`Vault/.../decisions/2026-05-30-migrate-kiwoom-to-kis.md`).
> **Scope = 시세 전용** (사용자 확정 2026-06-01) — 계좌/잔고 TR 보류, holdings-pnl 재개 시 재검토.
> ⚠️ **앱 본체는 아직 키움 코드 경로** — 본 문서 KIS 스펙은 전환 체크리스트 [3](watchlist-realtime KIS 이식)의 목표 스펙이다. 현행 앱이 의존하는 키움 스펙은 §부록(legacy) 참조.

## ✅ KIS 실측 확정 (2026-06-03~04 PoC)

도구: `tools/kis-auth-poc.swift`(REST 3종) + `tools/kis-ws-poc.swift`(WS 체결). 전부 실전 도메인·외부망에서 HTTP 200 — **지정단말기(8050)류 IP 제약 부재 최종 확인**(전환 핵심 가설 ✅).

### 인증

| 항목 | 실측 확정값 | 비고 |
|---|---|---|
| REST base(실전) | `https://openapi.koreainvestment.com:9443` | 모의 `openapivts:29443`은 🟡 미실측 |
| 토큰 발급 | `POST /oauth2/tokenP` body `{grant_type:"client_credentials", appkey, appsecret}` | JSON body. 키움(`/oauth2/token`·`secretkey`)과 경로·키 이름 다름 |
| 토큰 응답 | `access_token`(JWT 346자) · `token_type:"Bearer"` · `expires_in:86400`(=24h) · `access_token_token_expired:"YYYY-MM-DD HH:mm:ss"`(KST) | 2026-06-04 실측: `2026-06-05 09:36:42` 정확히 24h |
| 재발급 제한 | **분당 1회**(공식 고지) — 위반 시 EGW 오류 | TokenManager 토큰 캐시 필수. 만료 임박/401 시만 재발급 |
| WS 접속키 | `POST /oauth2/Approval` body `{grant_type:"client_credentials", appkey, **secretkey**}` → `approval_key`(36자) | ⚠️ body 키가 `appsecret` 아닌 `secretkey` — tokenP와 다름(실측). 호출마다 새 키 발급, 별도 제한 미관측 |
| 자격증명 로드(tools) | env 파일(`~/.config/secrets/api.env`의 `KIS_APP_KEY`/`KIS_APP_SECRET`, override=`PARAGON_SECRETS_ENV`) 우선 → Keychain `kr.co.koreainvestment.paragon.{appkey,appsecret}` 폴백 | 결정 `decisions/2026-06-03-kis-credentials-from-env.md`. **앱 본체 로드 정책은 [3]에서 결정**(평문 env 보안 리스크 — 앱은 Keychain 정석 권장) |

### 현재가 REST — `FHKST01010100` (주식현재가 시세)

- `GET /uapi/domestic-stock/v1/quotations/inquire-price`
- headers: `authorization: Bearer {token}` · `appkey` · `appsecret` · `tr_id: FHKST01010100` · `custtype: P`
- query: `FID_COND_MRKT_DIV_CODE=J`(주식) · `FID_INPUT_ISCD={6자리 종목코드}`
- 응답: `rt_cd:"0"`(성공) · `msg_cd:"MCA00000"` · `output{...}` — 전 필드 **plain 문자열, 원 단위 정수, 스케일·zero-padding 없음**

**v1 사용 필드 화이트리스트** (2026-06-04 실측, 005930):

| 필드 | 의미 | 실측값 | 비고 |
|---|---|---|---|
| `stck_prpr` | 현재가(원) | `"363500"` | |
| `prdy_vrss` | 전일대비(원) | `"3000"` | 하락 시 음수 포함 여부 🟡(아래 §부호 규칙) |
| `prdy_vrss_sign` | 전일대비부호 | `"2"` | 2=상승·5=하락 실측. 1상한/3보합/4하한 🟡 |
| `prdy_ctrt` | 등락률(%) | `"0.83"` | plain decimal |
| `stck_sdpr` | 기준가(=전일종가, 원) | `"360500"` | WS 역산 전일종가와 일치(3중 교차검증) |
| `stck_shrn_iscd` | 종목코드 | `"005930"` | 6자리 순수(A접두 없음) |

- ⚠️ **종목명 미포함** — 키움 ka10001과 달리 inquire-price 응답에 종목명 필드가 없다(`bstp_kor_isnm`은 업종명, `rprs_mrkt_kor_name`은 시장명). → **✅ 해소: 주식기본조회 `CTPF1002R`로 확보**(아래 §종목명 조회).
- 기타 가용 필드(참고, v1 미사용): `stck_oprc`(시가)·`stck_hgpr`(고가)·`stck_lwpr`(저가)·`acml_vol`(누적거래량)·`acml_tr_pbmn`(누적거래대금)·`wghn_avrg_stck_prc`(가중평균가)·`aspr_unit`(호가단위, 005930=500)·`per`/`pbr`/`eps`/`bps` 등 약 80필드.

### 종목명 조회 REST — `CTPF1002R` (주식기본조회 [v1_국내주식-067]) — 2026-06-04 실측 ✅

> watchlist 등록 플로우(코드 입력 → 종목명 표시)용. inquire-price의 종목명 부재 갭 해소. 출처: 공식 GitHub 샘플(1차) + `tools/kis-name-poc.swift` 실측(005930 주식 + 069500 ETF 2/2).

- `GET /uapi/domestic-stock/v1/quotations/search-stock-info`
- headers: inquire-price와 동일 패턴(`authorization` Bearer · `appkey` · `appsecret` · `tr_id: CTPF1002R` · `custtype: P`)
- query: `PRDT_TYPE_CD=300`(주식·ETF·ETN·ELW 공통 — ETF도 동일 값으로 조회됨 실측) · `PDNO={6자리 종목코드}`
- 응답: `rt_cd:"0"` · `msg_cd:"KIOK0530"` · `output{...}` (⚠️ `msg1`은 trailing 공백 패딩 — trim 필요)

**v1 사용 필드** (실측):

| 필드 | 의미 | 실측값(005930 / 069500) | 비고 |
|---|---|---|---|
| `prdt_abrv_name` | 상품약어명 — **앱 표시명** | `"삼성전자"` / `"KODEX 200"` | 키움 `stk_nm` 동등. `prdt_name`(정식명: "삼성전자보통주"·긴 펀드명)은 표시 부적합 |
| `pdno` | 상품번호 | `"00000A005930"` | ⚠️ **요청은 6자리, 응답은 12자리 zero-pad+A접두** — 코드 키로 쓰려면 suffix 6자리 추출 또는 입력 코드 그대로 사용 |
| `std_pdno` | 표준코드(ISIN) | `"KR7005930003"` | v1 미사용 |
| `bfdy_clpr` | 전일종가 | `"360500"` | `stck_sdpr`와 일치(교차검증) — 등록 시 초기 시세에 활용 가능 |

- 미존재/잘못된 코드 응답 형태 🟡 미실측 — 등록 실패 분기 구현 시 실측(예상: `rt_cd != "0"` 또는 빈 `output`).
- ⚠️ **REST 연속 호출 제한 실측: `EGW00201` "초당 거래건수를 초과하였습니다"** — search-stock-info 직후 연속 호출(간격 ~0ms)에서 HTTP 500 + EGW00201 발생, **600ms 간격으로 회피 확인**. 정확한 초당 한도는 🟡 미확정. → 앱 REST 클라이언트에 호출 간 최소 간격(또는 직렬 큐 스로틀) 필요.

### WS 실시간 체결 — `H0STCNT0` (2026-06-04 장중 09:23 KST 실측 ✅)

| 항목 | 실측 확정값 |
|---|---|
| URL(실전) | `ws://ops.koreainvestment.com:21000` — **평문 ws 전용**(wss는 TLS -1200 실패). 모의 `:31000` 🟡 미실측 |
| 구독 송신 | `{"header":{"approval_key","custtype":"P","tr_type":"1","content-type":"utf-8"},"body":{"input":{"tr_id":"H0STCNT0","tr_key":"{6자리}"}}}` |
| 구독 응답 | JSON `{"header":{"tr_id":"H0STCNT0","tr_key","encrypt":"N"},"body":{"rt_cd":"0","msg_cd":"OPSP0000","msg1":"SUBSCRIBE SUCCESS"}}` — **encrypt:"N" = 체결가 평문, AES 복호 불필요** |
| keep-alive | `tr_id:"PINGPONG"` JSON 약 10초 간격 — **동일 메시지 echo 회신**(미회신 시 절단 추정) |
| 체결 raw 형식 | `암호화flag|tr_id|건수|본문` — flag `0`=평문, 본문은 `^` 구분 |
| ★ 멀티 레코드 번들 | **`건수`=N이면 본문 = N틱 × 46필드 연결**(실측: 건수 011 → 총 506필드 = 46×11, 건수 009 메시지도 수신). **파서는 46필드 단위 청킹 필수** — 키움 0B(FID 키-값)와 전혀 다른 위치 기반 구조 |

**체결 raw 필드맵** (per-record 46필드, 실측 005930 `005930^092341^356000^5^-4500^-1.25^…`):

| index | 의미 | 실측값 | 교차검증 |
|---|---|---|---|
| [0] | 종목코드(6자리) | `005930` | ✅ |
| [1] | 체결시간 HHMMSS | `092341` | ✅ 실행 시각 일치 |
| [2] | 현재가(원 정수) | `356000` | ✅ |
| [3] | 전일대비부호 | `5`(하락) | ✅ REST sign 체계와 동일 |
| [4] | 전일대비(원) — **signed** | `-4500` | ✅ 356000+4500=360500=`stck_sdpr` 일치 |
| [5] | 등락률(%) — **signed** | `-1.25` | ✅ -4500/360500=-1.248% 산술 일치 |
| [6] | 가중평균가 | `350683.11` | REST `wghn_avrg_stck_prc` 동일 계열 |
| [7] | 시가 | `349000` | ✅ REST `stck_oprc` 일치 |
| [8] | 고가 | `357000` | 시점상 정합(이후 364250까지 상승) |
| [9] | 저가 | `348000` | ✅ REST `stck_lwpr` 일치 |
| [10] | 매도호가1 | `356000` | 호가단위 500 정합 |
| [11] | 매수호가1 | `355500` | 〃 |
| [12] | 체결거래량(주) | `1` | |
| [13] | 누적거래량(주) | `8026989` | ✅ 13분 뒤 REST `acml_vol` 9944273과 증가 정합 |
| [14] | 누적거래대금(원) | `2814936279750` | REST `acml_tr_pbmn` 증가 정합 |
| [24] | 시가 시간 HHMMSS | `090025` | 장 시작 직후 정합 |

- v1 파서 사용 = **[0][1][2][3][4][5]**(+필요 시 [13]). 나머지 index는 공식 H0STCNT0 명세 대조로 보충 가능(시세 전용 v1엔 불요).
- ★ **부호 규칙(Units & Signs Audit 대상)**: WS는 [4][5]에 **음수 부호가 값에 직접 포함**(부호필드 [3]과 중복 제공). REST `prdy_vrss`는 하락 시 음수 포함 여부 직접 실측 못 함(실측 시점 상승 전환) — 단 동일 응답 내 `pgtr_ntby_qty:"-2048088"` 등 음수 표기 실측으로 **signed 추정 강함** 🟡. 파서는 부호필드 의존 대신 **signed 값 직접 파싱 + sign 필드는 검증용**으로 설계하면 양쪽 표현에 안전. `QuoteParsingTests`(KIS 재작성)로 잠금.

### 부호·스케일 요약 (파서 잠금 기준)

| 항목 | 확정값 |
|---|---|
| 가격 단위 | 원, 정수 문자열, 스케일 없음 (REST·WS 동일) |
| 등락률 | %, plain decimal 문자열 (`-1.25`, `0.83`) |
| 부호 체계 | sign 필드: 2=상승·5=하락(실측) / 1·3·4 🟡. WS 대비·등락률 값 자체 signed(실측) |
| 종목코드 | REST·WS 모두 6자리 순수 — 키움 잔고 A접두 이슈 없음(시세 전용 scope에선 `normalize6` 불요) |
| 체결시간 | HHMMSS(KST) — MarketClock은 `Asia/Seoul` 고정 필수(로컬TZ 오판 방지, s14 교훈) |

## [3] watchlist-realtime KIS 이식 체크리스트 (앱 영향)

1. **Info.plist ATS 예외** — `ops.koreainvestment.com` 평문 ws 허용(NSExceptionDomains).
2. **TokenManager**: 발급 호출만 tokenP로 교체(actor 구조 유지). 분당 1회 제한 → 캐시 + 재발급 margin. 만료 = `expires_in` 또는 `access_token_token_expired` 파싱.
3. **WS 클라이언트**: approval_key 발급 단계 추가 → 구독 envelope 교체 → PINGPONG echo → **46필드 청킹 파서**(멀티 레코드 번들 처리 필수).
4. **파서 재작성**: `KiwoomQuoteParser` → KIS 파서. signed 값 직접 파싱 + sign 필드 검증용. `QuoteParsingTests` KIS 기준 재잠금(Units & Signs Audit).
5. **✅ 종목명 확보 = `CTPF1002R`**(§종목명 조회) — 등록 플로우: 코드 입력 → search-stock-info(`prdt_abrv_name`) + inquire-price(초기 시세) 2콜, **사이 간격 600ms+ 스로틀**(EGW00201 실측).
6. 자격증명: 앱 로드 정책 결정(env 직접 vs Keychain 정석 — 보안·휴대성 트레이드오프, `decisions/2026-06-03-kis-credentials-from-env.md` §앱 본체).
7. **REST 스로틀**: 연속 호출 EGW00201 실측(§종목명 조회) — REST 클라이언트에 호출 간 최소 간격 또는 직렬 큐.

### 미실측/미확정 잔여

- 🟡 REST `prdy_vrss` 하락 표현(다음 하락 시점 실측 1건이면 종결).
- 🟡 REST 초당 호출 한도 정확값(EGW00201 회피 간격 600ms만 실측) + 미존재 종목코드 응답 형태.
- 🟡 WS 동시 등록 한도(커뮤니티 41건 설) — 다종목 구독 시 실측.
- 🟡 모의(VTS) 도메인 전 흐름 — 실전 검증 완료라 v1 불요.
- 🟡 토큰 만료/401·EGW 오류 응답 형태 — 이식 후 에러 분기 시 실측.

## ⏸️ 보류 — 계좌/잔고 (holdings-pnl)

KIS = **시세 전용**(2026-06-01 scope 확정, 계좌 정보 불필요)이라 잔고 TR은 미실측·미사용. holdings-pnl 재개 시:
- KIS 국내주식 잔고조회 TR 실측(🟡 추정 TTTC8434R 계열 — 단정 금지) + 필드 매핑 재도출.
- **결정 A**(`decisions/2026-05-29-holdings-pnl-display-policy.md`, 단순 평가손익 산식)는 산식·캡션 정책 자체는 provider 무관 생존 — 입력 필드만 KIS 기준 재도출.
- 키움 kt00018 실측(§부록)은 필드 시맨틱 참고용 보존.

## 부록 — 키움 legacy (현행 앱 코드 의존분, [3] 완료 시 삭제)

> 2026-05-29 실측 확정분 압축. 키움은 **지정단말기(8050) 제약**(외부망 토큰 발급 거부, 2026-05-30 실측)으로 폐기 결정. 상세 이력은 git history(2026-05-28~29 본 문서) 참조.

| 항목 | 실측 확정값(키움) |
|---|---|
| REST base | `https://api.kiwoom.com` / 토큰 `POST /oauth2/token`(`secretkey`) → `{token, expires_dt(KST yyyyMMddHHmmss), return_code}` 24h |
| WS | `wss://api.kiwoom.com:10000/api/dostk/websocket` — LOGIN→REG(`data[item,type=0B]`)→PING echo→REAL |
| WS 0B FID | 10 현재가(부호=방향·abs) / 11 전일대비(부호) / 12 등락률% / 13 누적거래량 / 15 체결량 / 16·17·18 시·고·저 / 20 체결시각 / 27·28 호가 — 원 단위, 스케일 없음 |
| 종목조회 | `POST /api/dostk/stkinfo` header `api-id: ka10001`, body `{stk_cd}` → `stk_nm`·`cur_prc`(부호)·`base_pric`·`pred_pre`·`flu_rt` — **종목명 포함**(KIS와 차이) |
| 잔고 | `POST /api/dostk/acnt` header `api-id: kt00018` → `acnt_evlt_remn_indv_tot[]`: `stk_cd`(**A접두**)·`stk_nm`·`rmnd_qty`·`pur_pric`(표시용)·`pur_amt`(authoritative)·`cur_prc`·`evltv_prft`(수수료·세금 차감)·`prft_rt` + 합산 `tot_*`. zero-padded 문자열·원/주 정수 |
| 잔고 핵심 발견 | `evltv_prft = evlt_amt − pur_amt − sum_cmsn − tax` → PRD 단순식과 수수료+세금만큼 불일치 → **결정 A**(단순식+캡션)의 실측 근거 |
| 파서 잠금 | `KiwoomQuoteParser` + `QuoteParsingTests` — price=abs·change 부호 보존·prevClose=base_pric(REST) 또는 price−change(WS) |

- 키움 자격증명 Keychain `kr.co.kiwoom.paragon.{appkey,appsecret}` — 앱 조립 루트(`AppDelegate`)가 현재 이를 읽음. KIS 이식 시 교체.
- 미실측 잔여였던 키움 Premise #2(모의 실시간)·#3(슬롯 한도)·REMOVE 동작은 폐기로 무의미.
