# QA Report — kis-migration Task 1

> 작성: 2026-06-04  
> 스프린트: kis-migration  
> 태스크 범위: KIS 기반 레이어 — `KISEnvironment.swift` 신규 + `KeychainStore.swift` `KISCredential` additive 추가  
> 빌드/테스트 로그: `/tmp/qa-kis-task1-1780545841.log`

---

## 1. 수용 기준 표

| # | 검증 항목 | 결과 | 근거 |
|---|---|---|---|
| V-1 | 회귀 0: PMCore 기존 테스트 전부 PASS | **PASS** | `swift test` exit=0, 46 tests 0 failures |
| V-2 | 기존 테스트 파일 변경 없음 | **PASS** | `git diff --stat HEAD` — Tests/ 경로 변경 0줄 |
| V-3 | URL 4종 API_SPEC.md 실측 확정값 1:1 일치 | **PASS** | 아래 §2 값 정합 표 참조 |
| V-4 | KISCredential 식별자 2종 API_SPEC.md 확정값 일치 | **PASS** | 아래 §2 값 정합 표 참조 |
| V-5 | KiwoomCredential·CRUD 함수 본문 변경 0줄 (additive only) | **PASS** | `git diff HEAD -- KeychainStore.swift`: 65행 이후 8줄 순 추가, 기존 본문 변경 없음 |
| V-6 | scope 잠금: 변경이 선언 3파일에 한정 | **PASS** | `git diff --stat HEAD` → `KeychainStore.swift` + `OPERATIONAL_NOTES.md` + `SPRINT_PLAN.md` (3파일). `KISEnvironment.swift`는 untracked 신규 파일. `SPRINT_PLAN.md` 변경은 Task 1 상태 업데이트(docs 영역) |

---

## 2. 값 정합 (API_SPEC.md 실측 확정값 vs 코드)

### KISEnvironment URL 4종

| 상수 | API_SPEC.md 실측 확정값 | KISEnvironment.swift 값 | 일치 |
|---|---|---|---|
| `restBaseURL` | `https://openapi.koreainvestment.com:9443` | `https://openapi.koreainvestment.com:9443` | ✓ |
| `tokenURL` | base + `POST /oauth2/tokenP` | `https://openapi.koreainvestment.com:9443/oauth2/tokenP` | ✓ |
| `approvalURL` | base + `POST /oauth2/Approval` | `https://openapi.koreainvestment.com:9443/oauth2/Approval` | ✓ |
| `webSocketURL` | `ws://ops.koreainvestment.com:21000` (평문 ws 전용) | `ws://ops.koreainvestment.com:21000` | ✓ |

### KISCredential 식별자 2종

| 상수 | API_SPEC.md 확정값 | KeychainStore.swift 값 | 일치 |
|---|---|---|---|
| `appKey` | `kr.co.koreainvestment.paragon.appkey` | `kr.co.koreainvestment.paragon.appkey` | ✓ |
| `appSecret` | `kr.co.koreainvestment.paragon.appsecret` | `kr.co.koreainvestment.paragon.appsecret` | ✓ |

---

## 3. 테스트 실행 결과

```
swift test  (non-watch, Build complete 0.07s)
exit=0

KeychainStoreTests        5/5 passed
MarketClockTests          6/6 passed
NetworkPathReachabilityTests  7/7 passed
PolicyTests               1/1 passed
PriceDirectionTests       7/7 passed
QuoteParsingTests         9/9 passed
TokenManagerTests         5/5 passed
WatchlistStoreTests       6/6 passed

Total: 46 tests, 0 failures, 0 unexpected
```

로그: `/tmp/qa-kis-task1-1780545841.log`

---

## 4. 병존 무결성 상세

`git diff HEAD -- Sources/PMCore/Auth/KeychainStore.swift` 결과:

- 변경 위치: 파일 말미(65행 이후) 8줄 순 추가
- `KiwoomCredential` enum 본문: 변경 없음
- `KeychainStore` struct (get/set/delete): 변경 없음
- `KeychainError`: 변경 없음

---

## 5. Units & Signs Audit

Task 1 범위는 URL 상수 + Keychain 식별자 문자열 상수 — 수치 변환(ms↔s, 스케일, 부호) 없음. Units & Signs Audit 대상 없음(N/A).

---

## 6. UI 변경 여부

변경 파일에 `.tsx` / `.jsx` / `.css` / `.swift` UI 컴포넌트 없음 — Swift 모델/상수 레이어 한정. 브라우저 검증 비대상.

---

## 7. Scope 확정

| 파일 | 상태 | Task 1 선언 범위 내 |
|---|---|---|
| `Sources/PMCore/Network/KISEnvironment.swift` | untracked 신규 | ✓ |
| `Sources/PMCore/Auth/KeychainStore.swift` | modified (additive 8줄) | ✓ |
| `docs/OPERATIONAL_NOTES.md` | modified (+2줄) | ✓ |
| `docs/sprints/SPRINT_PLAN.md` | modified (상태 업데이트) | ✓ (docs 영역) |

선언 외 파일 변경 없음.
