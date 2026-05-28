# tokens.md — 시안 단위 토큰 차분
# PARAGON-MB watchlist-realtime v0.1 · comfortable variant
# Phase 5 게이트 통과 후 conductor가 design-language.md SSOT 누적

## 출처 우선순위
1. Paragon design-language.md §1~§4 — 브랜드 기반 SSOT (상속원)
2. design-plan-v0.1.md §3.1 — 상속 토큰 enumerate
3. 시안 단위 신규 제안 — 아래 §B 항목 (Plan §10 예고 4종)

---

## §A — 상속 Paragon 토큰 (design-language.md §1~§4 SSOT, 읽기 전용)

### 브랜드 4색 (잠금)
| 토큰명 | 값 | 용도 |
|---|---|---|
| `--color-midnight` | `#0B1729` | 다크 배경 primary |
| `--color-sapphire` | `#3B82F6` | CTA·focus ring·활성 상태 |
| `--color-pearl` | `#F8F7F2` | 라이트 모드 배경 |
| `--color-slate` | `#64748B` | 보조 텍스트·비활성·격자선 |

### Surface 레이어 (다크)
| 토큰명 | 값 | 용도 |
|---|---|---|
| `--color-surface-0` | `#0B1729` | 최하 배경 (= `--color-midnight` ALIAS) |
| `--color-surface-1` | `#0F2044` | 패널 컨테이너 배경 |
| `--color-surface-2` | `#142952` | hover·활성 행 배경 |

### 보더
| 토큰명 | 값 | 용도 |
|---|---|---|
| `--color-border` | `rgba(100,116,139,0.25)` | 기본 테두리 |
| `--color-border-muted` | `rgba(100,116,139,0.12)` | 서브 구분선 |

### 텍스트 (다크 배경 위, WCAG AA)
| 토큰명 | 값 | 용도 |
|---|---|---|
| `--color-text-primary` | `#E8EDF5` | 주 텍스트 (~15:1) |
| `--color-text-secondary` | `#94A3B8` | 보조 텍스트 (~4.8:1+) |

### 데이터 3단 색 — 부호 잠금 (★ 절대 변경 금지)
| 토큰명 | 값 | 의미 | 용도 |
|---|---|---|---|
| `--data-up` | `#DC2626` | 상승·매수 red ▲+ | fill·도트·범례·테두리 |
| `--data-neutral` | `#64748B` | 보합 slate - | 〃 |
| `--data-down` | `#2563EB` | 하락·매도 blue ▼− | 〃 |
| `--data-up-text` | `#F87171` | 상승 텍스트 변형 (다크 위 AA) | 텍스트 전용 |
| `--data-neutral-text` | `#94A3B8` | 보합 텍스트 변형 | 텍스트 전용 |
| `--data-down-text` | `#60A5FA` | 하락 텍스트 변형 (다크 위 AA) | 텍스트 전용 |

> ★ 절대 금지: green 사용 / red↔blue 역전 / `--color-sapphire`를 데이터 셀 컬러로 사용

### 모션 (Paragon 상속)
| 토큰명 | 값 | 출처 |
|---|---|---|
| `--motion-enter-duration` | `0.24s` | Paragon design-language §3 |
| `--motion-enter-ease` | `ease-out` | 〃 |
| `--motion-tab-duration` | `0.18s` | 〃 |
| `--motion-toast-duration` | `0.22s` | 〃 |
| `--motion-skeleton-period` | `1.6s` | 〃 |

### 타이포 스케일 (Paragon 상속)
| 토큰명 | 값 | PARAGON-MB 적용 |
|---|---|---|
| `--font-sans` | `ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif` | 전체 |
| `--font-size-t2` | `13px` | 헤더 장 상태 라벨 (L1) |
| `--font-size-t3` | `13px` | 종목명 (L2) |
| `--font-size-t4` | `12px` | 현재가·등락률·등락액 (L2, tabular-nums) |
| `--font-size-t5` | `11px` | 캡션·갱신 시각·에러 (L3) |

---

## §B — 시안 단위 신규 제안 토큰 (Plan §10 예고 4종, Phase 5 게이트 통과 후 conductor 채택 결정)

### light-mode-tokens (라이트 모드 전용 재정의)
| 토큰명 | 제안값 | 용도 | 채택 권고 |
|---|---|---|---|
| `--lt-text-primary` | `#1E293B` | 라이트 배경 위 주 텍스트 (WCAG AA 확보) | 신규 등록 |
| `--lt-text-secondary` | `#475569` | 라이트 배경 위 보조 텍스트 | 신규 등록 |
| `--lt-surface-1` | `#FFFFFF` | 라이트 패널 배경 | 신규 등록 |
| `--lt-surface-2` | `#F1F5F9` | 라이트 hover 행 배경 | 신규 등록 |
| `--lt-pearl-bg` | `#F8F7F2` | 라이트 전체 배경 (= `--color-pearl` ALIAS) | ALIAS 권고 |
| `--lt-border` | `rgba(30,41,59,0.12)` | 라이트 보더 | 신규 등록 |
| `--lt-data-up-text` | `#DC2626` | 라이트 위 상승 텍스트 (AA 확보) | 신규 등록 |
| `--lt-data-down-text` | `#1D4ED8` | 라이트 위 하락 텍스트 (AA 확보) | 신규 등록 |
| `--lt-data-neutral-text` | `#475569` | 라이트 위 보합 텍스트 | 신규 등록 |

### highlight-tokens (실시간 갱신 하이라이트)
| 토큰명 | 제안값 | 용도 | 출처 |
|---|---|---|---|
| `--motion-highlight-duration` | `0.30s` | 하이라이트 fade-out 지속 | design-plan §5.1 OQ-4 확정 |
| `--motion-highlight-ease` | `ease-out` | 하이라이트 easing | 〃 |
| `--color-highlight-up` | `rgba(220,38,38,0.15)` | 상승 행 배경 tint | design-plan §5.1 확정값 |
| `--color-highlight-down` | `rgba(37,99,235,0.15)` | 하락 행 배경 tint | 〃 |

### badge-warning-token (헤더 상태 배지)
| 토큰명 | 제안값 | 용도 | 비고 |
|---|---|---|---|
| `--color-badge-warning` | `#F59E0B` | ws-disconnected amber 배지 | data-up red와 혼동 없음 |
| `--color-badge-error` | `#DC2626` | auth-failed 빨간 배지 | `= --data-up` ALIAS 권고 |

> **on-color 텍스트 결정 (Refine Phase 4 확정)**: `--color-badge-warning` (`#F59E0B`) 위 텍스트 = `--color-midnight` (`#0B1729`). 대비 ≈ 8.4:1 (WCAG AA 통과). `--color-pearl` (`#F8F7F2`) 위 amber는 ≈ 2.0:1로 미달 — pearl 사용 금지. compact variant와 동일 정책으로 두 variant 일관성 확보.

### rgba-alias-tokens (직접 rgba 우회 제거 — parity compact)
| 토큰명 | 제안값 | 용도 | 비고 |
|---|---|---|---|
| `--color-sapphire-tint-10` | `rgba(59,130,246,0.10)` | sapphire 10% 반투명 tint — 인디케이터 배경 등 | compact §B 정합 |
| `--color-skeleton-base` | `rgba(255,255,255,0.06)` | 스켈레톤 shimmer base (다크) | compact §B 정합 |
| `--color-skeleton-highlight` | `rgba(255,255,255,0.12)` | 스켈레톤 shimmer highlight (다크) | compact §B 정합 |
| `--color-skeleton-base` (라이트 오버라이드) | `rgba(0,0,0,0.06)` | 라이트 모드 skeleton base — `:root` light 블록 재정의 | FAIL-C 수정, compact §B 정합 |
| `--color-skeleton-highlight` (라이트 오버라이드) | `rgba(0,0,0,0.10)` | 라이트 모드 skeleton highlight — `:root` light 블록 재정의 | FAIL-C 수정, compact §B 정합 |
| `--color-midnight-alpha-30` | `rgba(11,23,41,0.30)` | btn-spinner border 반투명 — midnight 30% alpha | compact §B 정합 |
| `--color-badge-warning-tint` | `rgba(245,158,11,0.15)` | ws-warn 배너 배경 amber tint (comfortable 기준) | Refine 4 alert-tint 토큰화 |
| `--color-badge-warning-border` | `rgba(245,158,11,0.3)` | ws-warn 배너 보더 amber (comfortable 기준) | Refine 4 alert-tint 토큰화 |
| `--color-data-up-tint` | `rgba(220,38,38,0.12)` | auth-fail / network-err 배너 배경 red tint (comfortable 기준) | Refine 4 alert-tint 토큰화 |
| `--color-data-up-border` | `rgba(220,38,38,0.25)` | auth-fail / network-err 배너 보더 red (comfortable 기준) | Refine 4 alert-tint 토큰화 |

### space-tokens (comfortable variant 공간 스케일)
| 토큰명 | 제안값 | 용도 | 비고 |
|---|---|---|---|
| `--space-panel-x` | `12px` | 패널 수평 패딩 | Plan §4.4 |
| `--space-row-y-comfortable` | `10px` | comfortable 행 내부 수직 패딩 | Plan §4.4 |
| `--space-header-y` | `8px` | 헤더 수직 패딩 | Plan §4.4 |
| `--space-action-y` | `12px` | Z3 하단 액션 수직 패딩 | Plan §4.4 |

---

## §C — 블루 3종 영역 격리 (Paragon 정책 상속)

| 블루 종류 | 값 | 허용 영역 | 위반 영역 |
|---|---|---|---|
| Sapphire (brand) | `#3B82F6` | CTA 버튼·focus ring·spinner (token-refreshing) | 데이터 셀 직접 색상 |
| 데이터 blue (하락) | `#2563EB` (fill), `#60A5FA` (text, dark) / `#1D4ED8` (text, light) | 하락·매도 데이터 표시 | brand accent 용도 |
| Gem facet | `#7DB7FB`/`#3B82F6`/`#2563EB`/`#1E40AF` | 로고 SVG 내부만 | 컴포넌트 스타일 |

---

## §D — [SPEC_GAP] 항목

| 식별자 | 내용 | 상태 |
|---|---|---|
| `[SPEC_GAP: light-mode-tokens]` | 라이트 모드 토큰(`--lt-*`)이 Paragon design-language.md 미등재 — §B에서 propose, Phase 5 채택 시 conductor SSOT 갱신 | Phase 5 대기 |
| `[SPEC_GAP: badge-warning-token]` | `--color-badge-warning` (#F59E0B) Paragon SSOT 미등재 — §B propose | Phase 5 대기 |
| `[SPEC_GAP: space-tokens]` | `--space-panel-x` 등 spacer 토큰 Paragon SSOT 미등재 — §B propose | Phase 5 대기 |
| `[SPEC_GAP: highlight-tokens]` | `--motion-highlight-duration`, `--color-highlight-up/down` Paragon SSOT 미등재 — §B propose | Phase 5 대기 |

---

_이 파일은 시안 단위 토큰 차분 propose 전용. design-language.md SSOT 누적은 Phase 5 게이트 통과 후 conductor 단독 수행._
