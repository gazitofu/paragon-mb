# tokens.md — 시안 단위 토큰 차분
# PARAGON-MB watchlist-realtime v0.1 · compact variant
# Phase 5 게이트 통과 후 conductor가 design-language.md SSOT 누적
# SSOT 출처: Paragon design-language.md + design-plan-v0.1.md §11

---

## §A — 상속 토큰 (Paragon design-language.md SSOT)

이 토큰들은 Paragon design-language.md에서 전체 상속. PARAGON-MB 시안은 값을 그대로 사용.

### 브랜드 기반 (design-language.md §1.1)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--color-midnight` | `#0B1729` | 다크 배경 primary |
| `--color-sapphire` | `#3B82F6` | CTA·focus ring·활성 상태 |
| `--color-pearl` | `#F8F7F2` | 라이트 배경 |
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
| `--data-up` | `#DC2626` | 상승·매수 — **red** ▲ + | fill·border |
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
| `--font-size-t4` | `12px` | 현재가·등락률·등락액 (tabular-nums) |
| `--font-size-t5` | `11px` | 갱신 시각, 캡션, 인라인 에러 |

### 모션 토큰 (design-language.md §5)

| 토큰명 | 값 | 용도 |
|---|---|---|
| `--motion-tab-duration` | `0.18s` | 뷰 전환 opacity fade |
| `--motion-toast-duration` | `0.22s` | 토스트 slide-up/fade-out |
| `--motion-skeleton-period` | `1.6s` | 스켈레톤 shimmer 주기 |

---

## §B — 신규 propose 토큰 (Phase 5 게이트 통과 후 conductor 채택 결정)

### light-mode-tokens — 라이트 모드 텍스트/surface 색값

[SPEC_GAP: light-mode-tokens] — Paragon design-language.md에 라이트 모드 전용 텍스트/surface 토큰 미등재.
PARAGON-MB compact 시안에서 propose.

| 토큰명 | 제안값 | 용도 | WCAG |
|---|---|---|---|
| `--light-text-primary` | `#1E293B` | 라이트 모드 주 텍스트 | ~14:1 on pearl ✓ |
| `--light-text-secondary` | `#475569` | 라이트 모드 보조 텍스트 | ~5.9:1 on pearl ✓ |
| `--light-surface-1` | `#FFFFFF` | 라이트 모드 패널 배경 | — |
| `--light-surface-2` | `#F1F5F9` | 라이트 모드 hover 행 배경 | — |
| `--light-border` | `rgba(30,41,59,0.12)` | 라이트 모드 보더 | — |
| `--light-data-up-text` | `#DC2626` | 라이트 모드 상승 텍스트 | ~4.6:1 on white ✓ |
| `--light-data-down-text` | `#1D4ED8` | 라이트 모드 하락 텍스트 | ~5.9:1 on white ✓ |
| `--light-data-neutral-text` | `#475569` | 라이트 모드 보합 텍스트 | ~5.9:1 on white ✓ |

### highlight-tokens — 실시간 갱신 하이라이트

[SPEC_GAP: highlight-tokens] — Paragon design-language.md 미등재. design-plan-v0.1 §5.1 확정.

| 토큰명 | 제안값 | 용도 |
|---|---|---|
| `--motion-highlight-duration` | `0.30s` | 갱신 하이라이트 fade-out 시간 (plan §5.1 OQ-4 확정) |
| `--motion-highlight-ease` | `ease-out` | 갱신 하이라이트 이징 (plan §5.1) |
| `--color-highlight-up` | `rgba(220,38,38,0.15)` | 상승 배경 tint (data-up 15% — plan §5.1) |
| `--color-highlight-down` | `rgba(37,99,235,0.15)` | 하락 배경 tint (data-down 15% — plan §5.1) |

### badge-warning-token — 헤더 상태 배지 색

[SPEC_GAP: badge-warning-token] — Paragon design-language.md 미등재. design-plan-v0.1 §7 확정.

| 토큰명 | 제안값 | 용도 | 비고 |
|---|---|---|---|
| `--color-badge-warning` | `#F59E0B` | ws-disconnected amber 배지 | data-up red와 혼동 없음 |
| `--color-badge-error` | `#DC2626` | auth-failed red 배지 | `--data-up` 재사용 |

### space-tokens — compact variant 간격 스케일

[SPEC_GAP: space-tokens] — Paragon design-language.md 미등재. design-plan-v0.1 §4.4 propose.

| 토큰명 | 제안값 | 용도 |
|---|---|---|
| `--space-panel-x` | `12px` | 패널 수평 패딩 |
| `--space-row-y-compact` | `6px` | compact 행 내부 수직 패딩 (top/bottom) |
| `--space-header-y` | `8px` | 헤더 수직 패딩 (top/bottom) |
| `--space-action-y` | `12px` | 하단 액션 영역 수직 패딩 |

### alpha-tint-tokens — 직접 rgba 토큰화 (FAIL-C 수정, design-refine Phase 4)

[SPEC_GAP: alpha-tint-tokens] — Paragon design-language.md 미등재. compact 시안 직접 rgba 3종(+라이트 skeleton 1쌍) 토큰화 propose.

| 토큰명 | 다크 값 | 라이트 오버라이드 | 용도 |
|---|---|---|---|
| `--color-sapphire-tint-10` | `rgba(59,130,246,0.10)` | (오버라이드 불필요, 동일 적용) | `.header-alert.info` 배경 |
| `--color-skeleton-base` | `rgba(255,255,255,0.06)` | `rgba(0,0,0,0.06)` | 스켈레톤 shimmer 기본 stop (Plan §5.2) |
| `--color-skeleton-highlight` | `rgba(255,255,255,0.12)` | `rgba(0,0,0,0.10)` | 스켈레톤 shimmer 중앙 stop (Plan §5.2) |
| `--color-midnight-alpha-30` | `rgba(11,23,41,0.30)` | (오버라이드 불필요) | `.btn-spinner` border — sapphire CTA 위 스피너 트랙 |
| `--color-badge-warning-tint-10` | `rgba(245,158,11,0.10)` | (오버라이드 불필요) | `.header-alert.warning` 배경 — ui-reviewer 라운드 2 FAIL 수정 |
| `--color-data-up-tint-10` | `rgba(220,38,38,0.10)` | (오버라이드 불필요) | `.header-alert.error` · `.header-alert.network-error` 배경 — ui-reviewer 라운드 2 FAIL 수정 |

---

## §C — 블루 3종 영역 격리 확인 (design-language.md §3 정합)

| 블루 종류 | 값 | 허용 영역 | 금지 영역 |
|---|---|---|---|
| Sapphire (brand) | `#3B82F6` | CTA 버튼·focus ring·token-refreshing spinner | 데이터 셀 직접 색상 |
| 데이터 blue (하락) | fill `#2563EB` / text `#60A5FA` | 하락·매도 등락률·등락액 텍스트 | brand accent 용도 |
| 라이트 데이터 blue | `#1D4ED8` | 라이트 모드 하락 텍스트 전용 | brand accent 용도 |

---

_이 파일은 시안 단위 토큰 차분 propose 전용 (Constraint 1 정합). design-language.md SSOT 누적은 Phase 5 게이트 통과 후 conductor 단독 수행._
