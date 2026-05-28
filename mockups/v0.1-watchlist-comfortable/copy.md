# copy.md — UI 카피 SSOT
# PARAGON-MB watchlist-realtime v0.1 · comfortable variant
# Plan §6 카피 가이드라인 정합. app.js COPY 객체의 원본.

---

## 앱 메타
- appName: `PARAGON-MB`

## 헤더 — 장 상태 라벨 (Plan §6.2, 한국 증권 관례)
- marketPre: `장전`
- marketOpen: `장중`
- marketClose: `장마감`
- lastUpdated: `갱신`  ← (갱신 시각 앞 레이블, 예: "갱신 12:34:05")

## 헤더 — 연결 상태 인디케이터
- wsDisconnected: `실시간 연결 끊김 — 재연결 중`
- tokenRefreshing: `인증 갱신 중`
- authFailed: `인증이 만료되었습니다 — 앱을 재시작해 주세요`
- networkError: `네트워크 연결을 확인해 주세요`
- retryButton: `다시 시도`

## W1 — 빈 상태 (Plan §6.2 + wireframe W1 SSOT)
- emptyMessage: `아직 등록된 종목이 없습니다`
- emptyCta: `+ 종목 추가`

## W2 — 목록 뷰
- addButton: `+ 종목 추가`           ← Z3 하단 고정 바 (comfortable variant)
- deleteAriaLabel: `삭제`
- afterHoursLabel: `종가`             ← 장외 행 배지 후보
- deleteToast: `삭제됨`
- undoButton: `되돌리기`
- toastSeparator: `·`                 ← "삭제됨 · 되돌리기" 구분자

## W3 — 종목 추가 폼 (wireframe W3 SSOT)
- formTitle: `종목 추가`
- inputPlaceholder: `예: 005930`
- inputLabel: `종목코드`
- submitButton: `등록`
- cancelButton: `취소`

## W3 — 인라인 에러 카피 (Plan §6.4 SSOT)
- errorInvalidCode: `등록할 수 없는 종목코드입니다`
- errorDuplicate: `이미 등록된 종목입니다`
- errorLimitExceeded: `관심종목은 최대 20개까지 등록할 수 있습니다`
- errorNetwork: `네트워크 연결을 확인해 주세요`

## 금지 패턴 확인 (Plan §6.3)
- 기능 나열형 0건: "실시간 시세를 확인하고..." → 사용 금지
- 영어 혼용 0건 (핵심 UI)
- 감탄사·이모지 0건
- 불확실 표현 0건

---

_이 파일은 mockup 폴더 내 local 카피 모듈 SSOT. production i18n 인프라 변경 0건._
