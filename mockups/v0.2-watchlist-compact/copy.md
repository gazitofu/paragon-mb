# copy.md — 카피 SSOT
# PARAGON-MB watchlist-realtime v0.2 · compact variant
# v0.1 carry-over + 헤더 레이아웃 변경 반영 (오너 오버라이드 2)
# Plan §6 카피 가이드라인 정합. UI 텍스트 하드코딩 0건 — app.js COPY 객체로 centralize.

---

## 원칙 (Plan §6.1)

- 톤: 차분한, 신뢰감, 정밀, 무광(non-flashy)
- 기능 나열형 금지: "실시간 시세를 확인하고..." 패턴 금지
- 감탄사·이모지 0건
- 영어 혼용 불필요: 핵심 UI 카피 한국어 단독
- 불확실 표현 금지: "~일 수 있습니다" 패턴 금지

---

## 헤더 (Z1) — 오너 정제 2: 1줄 통합 레이아웃

통합 상태텍스트 렌더 패턴: `{market.open} {header.updated(time)}` = "장중 14:32:05 기준"
장마감: `{market.closed} {header.closingRef}` = "장마감 종가 기준"

| key | 카피 | 렌더 예시 |
|---|---|---|
| `market.preOpen` | `장전` | "장전 14:32:05 기준" |
| `market.open` | `장중` | "장중 14:32:05 기준" |
| `market.closed` | `장마감` | "장마감 종가 기준" |
| `header.updated` | `{time} 기준` | time = HH:MM:SS |
| `header.closingRef` | `종가 기준` | 장마감 상태 전용 |
| `header.wordmark` | `PARAGON` | 워드마크 텍스트 (보석 포함 렌더링) |

---

## 연결 상태 (W2 헤더 인라인)

| key | 카피 | 용도 |
|---|---|---|
| `status.wsDisconnected` | `실시간 연결 끊김 — 재연결 중` | ws-disconnected 헤더 경고 |
| `status.tokenRefreshing` | `인증 갱신 중` | token-refreshing 인디케이터 |
| `status.authFailed` | `인증이 만료되었습니다 — 앱을 재시작해 주세요` | auth-failed 배너 |
| `status.networkError` | `네트워크 연결을 확인해 주세요` | network-error 배너 |
| `status.networkRetry` | `다시 시도` | network-error 재시도 버튼 |

---

## 빈 상태 (W1)

| key | 카피 | 용도 |
|---|---|---|
| `empty.message` | `아직 등록된 종목이 없습니다` | W1 메시지 |
| `empty.cta` | `+ 종목 추가` | W1 CTA 버튼 |

---

## 목록 (W2)

| key | 카피 | 용도 |
|---|---|---|
| `list.closingBadge` | `종가` | 장외 행 종가 배지 |
| `list.addButton` | `+` | 헤더 우측 추가 버튼 (compact) |
| `list.deleteTooltip` | `삭제` | 호버 삭제 아이콘 aria-label |

---

## 삭제 토스트

| key | 카피 | 용도 |
|---|---|---|
| `toast.deleted` | `삭제됨` | 토스트 메인 텍스트 |
| `toast.undo` | `되돌리기` | 토스트 되돌리기 버튼 |

---

## 종목 등록 (W3)

| key | 카피 | 용도 |
|---|---|---|
| `addForm.title` | `종목 추가` | W3 헤더 제목 |
| `addForm.placeholder` | `예: 005930` | 입력 필드 placeholder |
| `addForm.submit` | `등록` | 등록 버튼 |
| `addForm.cancel` | `취소` | 취소 버튼 |

---

## 인라인 에러 (W3 — Plan §6.4 SSOT)

| key | 카피 | 트리거 |
|---|---|---|
| `error.invalidCode` | `등록할 수 없는 종목코드입니다` | 잘못된 종목코드 |
| `error.duplicate` | `이미 등록된 종목입니다` | 중복 등록 시도 |
| `error.limitExceeded` | `관심종목은 최대 20개까지 등록할 수 있습니다` | 20개 한도 초과 |
| `error.network` | `네트워크 연결을 확인해 주세요` | 네트워크 오류 |

---

## 스켈레톤 접근성 (aria)

| key | 카피 | 용도 |
|---|---|---|
| `a11y.loading` | `시세 불러오는 중` | 스켈레톤 행 aria-label |
| `a11y.addSymbol` | `종목 추가` | 헤더 + 버튼 aria-label |
| `a11y.deleteSymbol` | `{name} 삭제` | 삭제 버튼 aria-label |
