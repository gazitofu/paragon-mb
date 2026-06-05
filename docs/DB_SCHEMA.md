# Data / Storage Schema — PARAGON-MB

> 갱신: 2026-06-05 (KIS 전환 [3] 완료 — 앱 본체 KIS 코드 경로 전환·키움 legacy 삭제. 키움 → KIS 결정: `decisions/2026-05-30-migrate-kiwoom-to-kis.md`).

조회 전용 앱 — 서버 DB 없음. 로컬 영속만:

- 관심종목 목록 (종목코드 + 순서) → JSON 파일
- 사용자 설정 (표시 옵션 등) → 본 슬라이스 범위 밖(v1 미사용, 향후)
- **자격증명(app key/secret/access token)은 macOS Keychain — 파일/평문 저장 금지**

## 관심종목 영속 — JSON 파일

| 항목 | 값 |
|---|---|
| 경로 | `~/Library/Application Support/PARAGON-MB/watchlist.json` |
| 형식 | UTF-8 JSON, `Codable` 직렬화 |
| 쓰기 | atomic write(임시 파일 → rename). 부분 쓰기로 인한 손상 방지 |
| 손상 처리 | 디코딩 실패 시 빈 목록으로 폴백(앱 크래시 금지) |
| 소유 | `PMCore/Store/WatchlistStore` |

### 스키마 (v1)

```jsonc
{
  "version": 1,                  // 스키마 버전(향후 마이그레이션 키)
  "symbols": [                   // 순서 = 화면 표시 순서
    { "code": "005930", "name": "삼성전자" }
  ]
}
```

| 필드 | 타입 | 설명 | 제약 |
|---|---|---|---|
| version | Int | 스키마 버전 | 현재 1. 증가 시 마이그레이션 |
| symbols | Array | 관심종목 목록(순서 = 표시 순서) | 최대 `Policy.maxWatchlistCount`(현재 20). 한도 검사는 도메인 로직 |
| symbols[].code | String | 종목코드 6자리 | unique(중복 등록 차단). 등록 시 시세 REST(KIS `inquire-price`)로 유효성 검증 |
| symbols[].name | String | 종목명(REST 조회로 자동 채움) | 등록 시점 캐시. 표시용. KIS는 `inquire-price`가 종목명 미반환 → 주식기본조회 `CTPF1002R`의 `prdt_abrv_name` 사용(2026-06-04 실측, `API_SPEC.md` §종목명 조회) |

- **시세 값(현재가·등락액·등락률·기준종가)은 영속하지 않는다** — 휘발성 런타임 상태(REST 초기값 + WS 갱신)로만 보유. 재실행 시 코드로 재조회. 영속 대상은 종목코드+이름+순서뿐.
- `name`은 등록 시 캐시이며 SSOT가 아니다. 재조회 시 최신값으로 갱신 가능(향후).

## ⏸️ 보유종목 스냅샷 — 보류 (KIS 전환 + 시세 전용 scope, 2026-06-01)

> **KIS = 시세 전용 scope 확정으로 holdings-pnl 보류** — 아래는 키움 kt00018 기준 설계로, 재개 시 KIS 잔고 TR 실측 후 필드 출처를 재도출한다(`API_SPEC.md` §보류). 모델 형태·휘발성 원칙·결정 A 산식은 provider 무관 생존.

보유종목은 **디스크 영속 대상이 아니다**(watchlist JSON과 대비). 실계좌가 SSOT이며, 앱은 잔고 REST를 주기 조회해 런타임 메모리에만 보유한다. 재실행 시 잔고 재조회로 복원.

| 모델 | 필드 | 출처(키움 legacy — KIS 재도출 대상) | 비고 |
|---|---|---|---|
| `Holding`(PMCore/Domain) | `code`(정규형 6자리) | 잔고 `stk_cd` → `SymbolCode.normalize6` | 키움 "A" 접두 제거 (KIS 시세는 6자리 순수 — 잔고 TR 형식은 미실측) |
| | `name` | 잔고 `stk_nm` | |
| | `quantity`(주, Int) | 잔고 `rmnd_qty` | |
| | `purchasePrice`(원, Int) | 잔고 `pur_pric` | 매입단가(표시용 반올림) — 종목별 손익 계산 기준 |
| | `purchaseAmount`(원, Int) | 잔고 `pur_amt` | authoritative — 수익률 분모·합산 기준선(역산 금지, Premise #5) |

- 현재가(`cur_prc`)는 `Holding`에 넣지 않는다 — WS 가격 캐시(`HoldingsViewModel.quotes`) 경유(잔고 `cur_prc`는 WS 도착 전 초기값으로만).
- 키움 `evltv_prft·sum_cmsn·tax·prft_rt`는 저장·사용하지 않는다(결정 A — 단순식 자체 계산).

## 자격증명

| 항목 | 값 |
|---|---|
| KIS Keychain 서비스 | `kr.co.koreainvestment.paragon.{appkey,appsecret}` (`kSecClassGenericPassword`) |
| KIS env 파일(tools 한정) | `~/.config/secrets/api.env`의 `KIS_APP_KEY`/`KIS_APP_SECRET` (override=`PARAGON_SECRETS_ENV`) — PoC 도구는 **env 우선 → Keychain 폴백**(결정 `decisions/2026-06-03-kis-credentials-from-env.md`) |
| 앱 본체 로드 정책 | Keychain 정석 (s23 결정) — env 직접 읽기는 평문 보안 약화·절대경로 비휴대성 리스크로 tools 한정. 키움 legacy 항목(`kr.co.kiwoom.paragon.*`)은 cleanup으로 삭제(2026-06-05) |
| 소유 | `PMCore/Auth/KeychainStore` |
| 평문 금지 | git·UserDefaults·로그 평문 저장 금지(Premise #7). env 파일은 사용자 관리 영역(`~/.config/secrets/`, git 밖) |

- access token은 메모리 보관(만료 시각과 함께, TokenManager actor). 재발급으로 갱신. **secret·token은 로그·git 어디에도 남기지 않는다.**

## 마이그레이션

- 신규 앱 → 기존 데이터 없음. 첫 실행 시 빈 `watchlist.json` 생성.
- 향후 스키마 변경은 `version` 필드 분기로 처리(예: v1→v2 시 변환 후 재저장).
