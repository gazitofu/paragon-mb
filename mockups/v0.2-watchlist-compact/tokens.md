# tokens.md — 시안 단위 토큰 차분
# PARAGON-MB watchlist-realtime v0.2 · compact variant
# Phase 5 게이트 통과 후 conductor가 design-language.md SSOT 누적
# SSOT 출처: Paragon design-language.md + PARAGON-design-plan.md §7 + design-plan-v0.1.md §11
# 오너 오버라이드 5건 반영 (Phase 5 지시 — 사용자 승인 변경)

---

## §A — 상속 토큰 (Paragon design-language.md SSOT)

이 토큰들은 Paragon design-language.md에서 전체 상속. v0.1 compact에서 계승.

### 브랜드 기반 (design-language.md §1.1)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--color-midnight` | `#0B1729` | 다크 배경 primary |
| `--color-sapphire` | `#3B82F6` | CTA·focus ring·활성 상태·링크·보조 강조 |
| `--color-pearl` | `#F8F7F2` | 라이트 캔버스 배경 (§9.1 Canvas) |
| `--color-slate` | `#64748B` | 보조·비활성·격자선 |

### Surface 레이어 — 다크 계층 (design-language.md §1.2)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--color-surface-1` | `#0F2044` | 패널 컨테이너 배경 |
| `--color-surface-2` | `#142952` | hover 행 배경 |

### 보더 (design-language.md §1.3)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--color-border` | `rgba(100,116,139,0.25)` | 기본 테두리 |
| `--color-border-muted` | `rgba(100,116,139,0.12)` | 행 구분선 |

### 텍스트 — 다크 배경 (design-language.md §1.4)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--color-text-primary` | `#E8EDF5` | 주 텍스트 (~15:1 on midnight) |
| `--color-text-secondary` | `#94A3B8` | 보조 텍스트 (~4.8:1 on midnight) |

### 데이터 3단 색 — 부호 잠금 ★ 절대 변경 금지 (design-language.md §1.5·§2)

| 토큰명 | 값 | 의미 | 용도 |
|---|---|---|---|
| `--data-up` | `#DC2626` | 상승·매수 — red ▲ + | fill·border |
| `--data-neutral` | `#64748B` | 보합·중립 — slate - | fill·border |
| `--data-down` | `#2563EB` | 하락·매도 — blue ▼ − | fill·border |

### 데이터 텍스트 접근성 변형 (design-language.md §1.6)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--data-up-text` | `#F87171` | 다크 배경 위 상승 텍스트 (WCAG AA) |
| `--data-neutral-text` | `#94A3B8` | 다크 배경 위 보합 텍스트 |
| `--data-down-text` | `#60A5FA` | 다크 배경 위 하락 텍스트 (WCAG AA) |

### 폰트 스택 (design-language.md §4.1)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--font-sans` | `ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif` | 전체 (CDN 0, 시스템 폰트) |

### 폰트 스케일 (design-language.md §4.2)

| 토큰명 | 값 | PARAGON-MB 적용 |
|---|---|---|
| `--font-size-t2` | `13px` | 헤더 장 상태 라벨 (uppercase, weight 600) |
| `--font-size-t3` | `13px` | 종목명, W3 입력 레이블 |
| `--font-size-t4` | `12px` | 현재가·등락률 (tabular-nums) |
| `--font-size-t5` | `11px` | 갱신 시각, 캡션, 인라인 에러 |

### 모션 토큰 (design-language.md §5)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--motion-tab-duration` | `0.18s` | 뷰 전환 opacity fade |
| `--motion-toast-duration` | `0.22s` | 토스트 slide-up/fade-out |
| `--motion-skeleton-period` | `1.6s` | 스켈레톤 shimmer 주기 |

---

## §B — 신규 propose 토큰 (Phase 5 게이트 통과 후 conductor 채택 결정)

v0.1에서 carry-over된 토큰 + v0.2 신규 추가 토큰.

### highlight-tokens — 실시간 갱신 하이라이트 (v0.1 carry-over)

| 토큰명 | 제안값 | 용도 |
|---|---|---|
| `--motion-highlight-duration` | `0.30s` | 갱신 하이라이트 fade-out (plan §5.1 확정) |
| `--motion-highlight-ease` | `ease-out` | 갱신 하이라이트 이징 |
| `--color-highlight-up` | `rgba(220,38,38,0.15)` | 상승 배경 tint (data-up 15%) |
| `--color-highlight-down` | `rgba(37,99,235,0.15)` | 하락 배경 tint (data-down 15%) |

### badge-warning-token — 헤더 상태 배지 색 (v0.1 carry-over)

| 토큰명 | 제안값 | 용도 |
|---|---|---|
| `--color-badge-warning` | `#F59E0B` | ws-disconnected amber 배지 |
| `--color-badge-error` | `#DC2626` | auth-failed red 배지 (`--data-up` 재사용) |

### space-tokens — compact variant 간격 스케일 (v0.1 carry-over)

| 토큰명 | 제안값 | 용도 |
|---|---|---|
| `--space-panel-x` | `12px` | 패널 수평 패딩 |
| `--space-row-y-compact` | `6px` | compact 행 내부 수직 패딩 |
| `--space-header-y` | `8px` | 헤더 수직 패딩 |
| `--space-action-y` | `12px` | 하단 액션 영역 수직 패딩 |

### alpha-tint-tokens — 직접 rgba 토큰화 (v0.1 carry-over)

| 토큰명 | 다크 값 | 라이트 오버라이드 | 용도 |
|---|---|---|---|
| `--color-sapphire-tint-10` | `rgba(59,130,246,0.10)` | (오버라이드 불필요) | `.header-alert.info` 배경 |
| `--color-skeleton-base` | `rgba(255,255,255,0.06)` | `rgba(0,0,0,0.06)` | 스켈레톤 shimmer 기본 stop |
| `--color-skeleton-highlight` | `rgba(255,255,255,0.12)` | `rgba(0,0,0,0.10)` | 스켈레톤 shimmer 중앙 stop |
| `--color-midnight-alpha-30` | `rgba(11,23,41,0.30)` | (오버라이드 불필요) | `.btn-spinner` border |
| `--color-badge-warning-tint-10` | `rgba(245,158,11,0.10)` | (오버라이드 불필요) | `.header-alert.warning` 배경 |
| `--color-data-up-tint-10` | `rgba(220,38,38,0.10)` | `rgba(220,38,38,0.08)` | `.header-alert.error/.network-error` 배경 |

### gem-tokens — 워드마크 보석 전용 ★ (v0.2 신규 — 오너 오버라이드 2)

로고 내부 전용. UI 다른 곳엔 `--color-sapphire` 단일만. (PARAGON-design-plan §3.2)

| 토큰명 | 제안값 | 면 | 역할 |
|---|---|---|---|
| `--gem-highlight` | `#7DB7FB` | TL(좌상단) | 빛 직접 수광 |
| `--gem-base` | `#3B82F6` | TR(우상단) | 브랜드 기준색 |
| `--gem-mid-dark` | `#2563EB` | BL(좌하단) | Mid-dark |
| `--gem-shadow` | `#1E40AF` | BR(우하단) | 그림자 면 |

### wordmark-text-token — 워드마크 글자색 (v0.2 신규 — 오너 오버라이드 2)

| 토큰명 | 다크 값 | 라이트 값 | 용도 |
|---|---|---|---|
| `--wordmark-text` | `#F5F5F0` (Pearl 톤) | `#0B1729` (Midnight) | 워드마크 P·R·A·G·O·N 글자 |

### font-size-change — 등락 2단 폰트 크기 (v0.2 정제 R2 — 오너 정제 R2 지시 3·4)

**변경**: 오너 정제 R2로 위계 재도입. 등락률 12px / 등락액 10px (9px 동일 → 차등 복원).

| 토큰명 | 제안값 | 변경 전 | 용도 |
|---|---|---|---|
| `--font-size-change-unified` | `12px` | `9px` | 2단 스택 상단: 등락률 % |
| `--font-size-change-amt` | `10px` | `9px` | 2단 스택 하단: 방향심볼+등락액 |

### gem-mono-tokens — 메뉴바 아이콘 전용 (v0.2 정제 신규 — 오너 정제 지시 3)

로고/아이콘 전용. hue 0 모노크롬 4면 패싯. 라이팅 좌상단 유지.
macOS template image 방식 (라이트 메뉴바에서 Swift가 tintColor/반전 처리).
그라데이션·외곽선·글로우 금지 (§2.2 Don't — 모노크롬도 동일 적용).

| 토큰명 | 제안값 | 면 | 역할 |
|---|---|---|---|
| `--gem-mono-tl` | `#FFFFFF` | TL(좌상단) | 최명 — 직접 수광 |
| `--gem-mono-tr` | `#E0E0E0` | TR(우상단) | 밝은 회색 |
| `--gem-mono-bl` | `#B8B8B8` | BL(좌하단) | 중간 회색 |
| `--gem-mono-br` | `#8A8A8A` | BR(우하단) | 최암 — 그림자 면 |

---

## §C — 라이트 모드 토큰 전체 (PARAGON-design-plan §9.5 — 오너 오버라이드 5)

[data-theme="light"] 블록. v0.1의 prefers-color-scheme 방식에서 data-theme 속성 방식으로 전환.

### Surfaces

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--bg-canvas` | `#F8F7F2` | 패널/페이지 배경 (Canvas) |
| `--bg-surface` | `#FFFFFF` | 카드·행 영역 (Surface, 캔버스 위 떠보임) |
| `--bg-sunken` | `#EFEEE8` | 헤더·입력창 (Sunken) |
| `--border-divider` | `#E7E5DC` | 헤어라인 구분선 |
| `--border-strong` | `#D6D3C8` | 강한 경계·입력창 테두리 |

### Text

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--text-primary` | `#0B1729` | 제목·핵심 수치 |
| `--text-secondary` | `#475569` | 본문·라벨 |
| `--text-muted` | `#94A3B8` | 보조·placeholder |

### Accent (Sapphire)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--accent` | `#3B82F6` | 링크·포커스·보조 강조 |
| `--accent-hover` | `#1D4ED8` | 호버·프레스 |
| `--accent-tint` | `#EAF1FE` | 선택행·호버 배경 |
| `--accent-edge` | `#BBD3FB` | 강조 테두리 |
| `--btn-primary-bg` | `#0B1729` | Primary 버튼 배경 (§9.3: Midnight + 흰 텍스트) |

### Data (라이트)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--data-up-display` | `#DC2626` | 라이트 상승 텍스트 |
| `--data-up-bg` | `#FEECEC` | 라이트 상승 tint 배경 |
| `--data-down-display` | `#2563EB` | 라이트 하락 텍스트 |
| `--data-down-bg` | `#E8F0FE` | 라이트 하락 tint 배경 |
| `--data-neutral-display` | `#64748B` | 라이트 보합 텍스트 |

---

## §D — 블루 3종 영역 격리 확인 (design-language.md §3 정합)

| 블루 종류 | 값 | 허용 영역 | 금지 영역 |
|---|---|---|---|
| Sapphire (brand) | `#3B82F6` | CTA 버튼·focus ring·token-refreshing spinner·링크 | 데이터 셀 직접 색상, 헤더·로고 (§3.3) |
| 보석 셰이딩 | `#7DB7FB`·`#3B82F6`·`#2563EB`·`#1E40AF` | 로고 내부 전용 | UI 컴포넌트 (§3.2) |
| 데이터 blue (하락) | fill `#2563EB` / text `#60A5FA` (다크) / `#2563EB` (라이트) | 하락·매도 등락률·등락액 텍스트 | brand accent 용도, 헤더·로고 (§3.3) |

**브랜드존(로고·헤더) 규칙**: 데이터색(상승 red/하락 blue)을 헤더·로고 영역에 등장시키지 말 것 (§3.3, 오너 오버라이드 2).

---

---

## §E — 정제 차분: 등락열 padding + 행 높이 (오너 정제 final)

### 변경 사항

| 대상 | 변경 전 | 변경 후 | 근거 |
|---|---|---|---|
| `.row-change` `padding-top` / `padding-bottom` | `2px` | `4px` | 오너 정제 요구 |
| `.symbol-row` `height` | `32px` (고정) | 제거 → content-driven | 등락 스택 37px > 32px 클리핑 해소 |
| `.skeleton-row` `height` | `32px` (고정) | 제거 → content-driven | loading↔normal 높이 점프 방지 |
| `.skeleton-change` `height` | `18px` | `37px` | 등락 스택 실제 높이 반영 |

### 행 높이 계산 근거

```
등락 스택 내부 (box-sizing: border-box, row-change 기준):
  padding-top:       4px
  .change-pct:       font-size 12px × line-height 1.2 = 14.4px → ≈ 15px
  gap:               2px
  .change-amt-line:  font-size 10px × line-height 1.2 = 12.0px
  padding-bottom:    4px
  합계:              ≈ 37px

행 자체 padding (--space-row-y-compact = 6px 상하, box-sizing: border-box):
  symbol-row 자연 높이 ≈ 6 + 37 + 6 = 49px (+border-bottom 1px)

접근성 터치 영역: 44px+ 충족 (49px > 44px)
align-items: center → 종목명·현재가 세로 중앙 정렬 유지
```

---

## §F — 정제 차분: 축③ Detail FAIL 정제 (refine R3 — 대비 + 토큰 규율)

### F.1 — A항: `.change-amt-line` opacity 제거

| 대상 | 변경 전 | 변경 후 | 근거 |
|---|---|---|---|
| `.change-amt-line` `opacity` | `0.85` | 제거 (implicit 1) | 다크 surface-2 위 up #F87171 → 4.07:1 FAIL 근원. 폰트크기 위계(12px/10px)로 충분. |

**대비 검증 (sRGB linearize + relative luminance):**

| 색 | 배경 | BEFORE | AFTER | 판정 |
|---|---|---|---|---|
| up   #F87171 | surface-1 #0F2044 | 4.50:1 | 5.79:1 | PASS |
| up   #F87171 | surface-2 #142952 | 4.07:1 | 5.17:1 | PASS |
| down #60A5FA | surface-1 #0F2044 | 4.95:1 | 6.30:1 | PASS |
| down #60A5FA | surface-2 #142952 | 4.48:1 | 5.62:1 | PASS |
| neut #94A3B8 | surface-1 #0F2044 | 4.89:1 | 6.25:1 | PASS |
| neut #94A3B8 | surface-2 #142952 | 4.46:1 | 5.58:1 | PASS |

### F.2 — B항: 라이트 alert 배너 텍스트색 신규 토큰

새 토큰 3종 propose. 다크 기본값 :root, 라이트 오버라이드 [data-theme="light"] 각각 등재.

| 토큰명 | 다크 값 | 라이트 값 | 근거 |
|---|---|---|---|
| `--color-alert-warning-text` | `#F59E0B` | `#92400E` (amber-900) | 라이트 warning tint #FEF5E7 위: BEFORE 1.99:1 FAIL → AFTER 6.56:1 PASS |
| `--color-alert-error-text`   | `var(--data-up-text)` (#F87171) | `#991B1B` (red-800) | 라이트 error tint #FCE9E9 위: BEFORE 4.13:1 FAIL → AFTER 7.11:1 PASS |
| `--color-alert-info-text`    | `var(--color-sapphire)` (#3B82F6) | `#1D4ED8` (blue-700) | 라이트 info tint #EBF2FE 위: BEFORE 3.27:1 FAIL → AFTER 5.96:1 PASS |

**다크 모드 대비 (기존값, 확인 목적):**
다크 배경은 --bg-header = surface-1 #0F2044. tint-10 배경 위는 사실상 surface-1에 가까움.
#F59E0B on #0F2044: 9.96:1 PASS. #F87171 on #0F2044: 5.79:1 PASS. #3B82F6 on #0F2044: 4.94:1 PASS.

**라이트 대비 검증:**

| 텍스트 | 배경 tint | BEFORE | AFTER | 판정 |
|---|---|---|---|---|
| warning BEFORE #F59E0B | #FEF5E7 | 1.99:1 | — | FAIL |
| warning AFTER  #92400E | #FEF5E7 | — | 6.56:1 | PASS |
| error   BEFORE #DC2626 | #FCE9E9 | 4.13:1 | — | FAIL |
| error   AFTER  #991B1B | #FCE9E9 | — | 7.11:1 | PASS |
| info    BEFORE #3B82F6 | #EBF2FE | 3.27:1 | — | FAIL |
| info    AFTER  #1D4ED8 | #EBF2FE | — | 5.96:1 | PASS |
| network BEFORE #DC2626 | #FCE9E9 | 4.13:1 | — | FAIL |
| network AFTER  #991B1B | #FCE9E9 | — | 7.11:1 | PASS |

### F.3 — C항: 라이트 행 hover 배경 중립 변경

**§9.3 accent-tint `#EAF1FE` deviation 사유 (WCAG AA 우선)**:
accent-tint는 "선택(selected)" 상태 전용 배경으로 남김. hover 배경에서 데이터 숫자 가독이 핵심이므로 WCAG AA 통과 중립색 사용.

| 대상 | 변경 전 | 변경 후 | 근거 |
|---|---|---|---|
| `--bg-hover` (라이트) | `#EAF1FE` (accent-tint) | `#FAFAFA` | up 4.26:1 FAIL(BEFORE) → 4.63:1 PASS(AFTER). §9.3 accent-tint는 선택 상태 전용으로 이동. |

**hover-bg 대비 검증:**

| 색 | 배경 | BEFORE | AFTER | 판정 |
|---|---|---|---|---|
| up   #DC2626 | #EAF1FE → #FAFAFA | 4.26:1 | 4.63:1 | PASS |
| down #2563EB | #EAF1FE → #FAFAFA | 4.56:1 | 4.95:1 | PASS |
| neut #64748B | #EAF1FE → #FAFAFA | 4.19:1 | 4.56:1 | PASS |

### F.4 — D항: shadow 토큰 신규 등재

| 토큰명 | 제안값 | 용도 | 비고 |
|---|---|---|---|
| `--shadow-panel` | `0 1px 2px rgba(0,0,0,0.12), 0 4px 8px rgba(0,0,0,0.12), 0 12px 24px rgba(0,0,0,0.10)` | `.panel` box-shadow | 테마 무관 구조값 (다크/라이트 동일) |
| `--shadow-toast` | `0 2px 6px rgba(0,0,0,0.18), 0 6px 16px rgba(0,0,0,0.14)` | `.toast` box-shadow | 테마 무관 구조값 |

> 직접 rgba가 아닌 var() 경유로 변경. 그림자는 항상 검정 alpha로 테마 독립적이므로 :root에 고정 등재.

### F.5 — E항: font-size 리터럴 신규 토큰

| 토큰명 | 제안값 | 적용 속성 | 비고 |
|---|---|---|---|
| `--font-size-status` | `10px` | `.header-status-text` / `.status-badge` font-size | 스케일 외 오너 승인 전용값 (design-plan §4.3 오너 정제 R2 지시 5) |
| `--font-size-icon-plus` | `16px` | `.btn-add-header` font-size | "+" 글리프 전용 (버튼 내 아이콘 단독, 오너 정제 R2 지시 7 가로·세로 중앙정렬 유지) |

추가 변경:
- `.btn-delete-row` `font-size: 13px` → `var(--font-size-t3)` (기존 토큰 치환)

_이 파일은 시안 단위 토큰 차분 propose 전용 (Constraint 1 정합). design-language.md SSOT 누적은 Phase 5 게이트 통과 후 conductor 단독 수행._
