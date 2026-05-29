# Design System — PARAGON-MB

> 코드 토큰 SSOT. 구현 = `App/DesignTokens.swift`(SwiftUI). **디자인 결정 SSOT는 Vault `appdev/PARAGON-MB/design/design-language.md`** — 본 문서는 그 결정의 코드 매핑이다. 값 변경 시 design-language.md를 먼저 갱신하고 본 문서·`DesignTokens.swift`를 동기화한다.
>
> 색은 시스템 Appearance를 따르는 라이트/다크 동적 쌍(`NSColor` dynamicProvider, macOS 13+). 메뉴바 아이콘만 예외 — non-template 고정(`StatusBarController.gemIcon()`, design-language §2.5).

## 색 토큰 (`PMColor`)

| 토큰 | 라이트 | 다크 | 용도 |
|---|---|---|---|
| `panel` | `#FFFFFF` | `#0F2044` | 패널 컨테이너 배경 |
| `header` / `sunken` | `#EFEEE8` | `#0F2044` | 헤더·입력창 배경 |
| `hover` | `#FAFAFA` | `#142952` | 행 hover·토스트 배경 (라이트 중립 — 데이터색 AA) |
| `textPrimary` | `#0B1729` | `#E8EDF5` | 주 텍스트 |
| `textSecondary` | `#475569` | `#94A3B8` | 보조 텍스트 |
| `wordmark` | `#0B1729` | `#F5F5F0` | 워드마크 글자 |
| `border` | `#D6D3C8` | `rgba(100,116,139,.25)` | 기본 테두리 |
| `borderMuted` | `#E7E5DC` | `rgba(100,116,139,.12)` | 행 구분선 |
| `sapphire` | `#3B82F6` | `#3B82F6` | accent·focus·링크·"+" |
| `primaryButtonBg` / `primaryButtonText` | `#0B1729` / `#FFFFFF` | `#3B82F6` / `#0B1729` | CTA·등록 버튼 |

### 데이터 3색 — ★ 부호 잠금 (절대 변경 금지, KR 관례 §2.4)

| 토큰 | 라이트 | 다크 | 의미 |
|---|---|---|---|
| `dataUpText` | `#DC2626` | `#F87171` | 상승 (red ▲ +) |
| `dataDownText` | `#2563EB` | `#60A5FA` | 하락 (blue ▼ −) |
| `dataNeutralText` | `#64748B` | `#94A3B8` | 보합 (slate) |

green 금지, red↔blue 역전 금지, sapphire를 데이터 셀에 사용 금지. **3중 인코딩**: 색 + 부호(`+`/`−`, U+2212) + 심볼(`▲`/`▼`) 병행.

### 상태·배너·하이라이트

| 토큰 | 라이트 | 다크 | 용도 |
|---|---|---|---|
| `badgeWarning` / `badgeError` | `#F59E0B` / `#DC2626` | 동일 | ws-disconnected / auth·network 배지 |
| `alertWarningText` | `#92400E` | `#F59E0B` | warning 배너 텍스트 |
| `alertErrorText` | `#991B1B` | `#F87171` | error/network 배너 텍스트 |
| `alertWarningBg` / `alertErrorBg` | amber/red α.08~.10 | α.10 | 배너 배경 tint |
| `highlightUp` / `highlightDown` | red α.12 / blue α.12 | α.15 | 실시간 갱신 0.3s fade-out tint |
| `skeletonBase` / `skeletonHighlight` | black α.06/.10 | white α.06/.12 | 스켈레톤 |

### 컬러 보석 4면 (`GemMark`, 로고 전용 — UI 미사용)

TL `#7DB7FB`(수광) / TR `#3B82F6` / BL `#2563EB` / BR `#1E40AF`(그림자). 중심 분할 4 삼각형, 비율 10:14. 그라데이션·외곽선·글로우 금지.

## 폰트 (`PMFont`, tabular-nums 필수)

| 토큰 | 크기/굵기 | 용도 |
|---|---|---|
| `t2` | 13 / semibold | 헤더 라벨·워드마크 |
| `name` | 13 / medium | 종목명·삭제 글리프 |
| `price` | 12 / mono | 현재가·토스트 |
| `changePct` | 12 / medium·mono | 등락률(2단 상단) |
| `changeAmt` | 10 / mono | 방향심볼+등락액(2단 하단) |
| `caption` | 11 | 갱신시각·인라인에러·배너 |
| `status` | 10 / mono | 헤더 상태텍스트·배지 |
| `iconPlus` | 16 | "+" 글리프 |

## 공간·모션

`panelX 12` · `rowY 6` · `headerY 8` · `panelWidth 320`. 패널 고정 높이 360.
`highlightDuration 0.30s`(단방향 fade-out, 깜빡임 금지) · `viewTransition 0.18s` · `toastAutoDismiss 3.0s`.

## 등락 매핑 (`PriceDirection` 확장, M4)

- `displayColor`: up→dataUpText / down→dataDownText / flat→dataNeutralText (등락률·등락액).
- `priceColor`: up→dataUpText / down→dataDownText / **flat→textPrimary** (§6.2 오너 오버라이드 — compact 현재가 등락색, 보합만 중립 아닌 주 텍스트).
- `spokenWord`: 상승/하락/보합 (VoiceOver Q20).

## 숫자 포맷 (`PMFormat`)

- `price(Int)` → ko-KR 천단위 콤마 `"75,400"`.
- `pct(Double,dir)` → up `"+1.89%"` / down `"−2.14%"`(U+2212) / flat `"0.00%"`. 입력은 `Quote.changeRate`(% 단위, PMCore에서 ×100 잠금).
- `amountAbs(Int)` → 절대값 콤마 `"1,400"` (부호는 방향심볼이 표현).

## 컴포넌트 (watchlist-realtime v0.2 compact)

- 패널: 320pt 단일 컬럼, 헤더(sticky) → 콘텐츠 → 토스트 오버레이(bottom).
- 종목 행 ≈49px: `[종목명]―[현재가]―[등락 2단 스택]`, hover 삭제버튼(width 0→20), 장외 opacity 0.75 + "종가" 배지.
- 시안: `mockups/v0.2-watchlist-compact/`(dark+light). HTML→SwiftUI 번역 시 본 문서가 코드 SSOT.
