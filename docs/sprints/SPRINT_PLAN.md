# Sprint Plan

## Meta
- 생성일: 2026-06-04
- 기능: kis-migration (watchlist-realtime 데이터 프로바이더 KIS 이식)
- PRD: /Users/gazitofu/Vault/appdev/PARAGON-MB/prd/kis-migration/
- 모드: Strict  (Auto-Strict: auth 접점 TokenManager·approval_key·Keychain 식별자 + ATS Info.plist env config + provider 전면 교체)
- 상태: done  (자동화 영역 — Task 1~6 전부 done 2026-06-04. 라이브/수동 검증 섹션은 오너 게이트 잔여)
- SSOT 동기화 검증: architecture.md ✅(architect-design 사전 갱신 5590cd3, T0 정합 확인 완료) / API_SPEC.md ✅(Spec Patch 명시 "현 시점 스펙 변경 0" — §부록 키움 legacy 삭제는 라이브 검증 완료 후 키움 소스 정리와 함께)
- 브랜치: feat/kis-migration (로컬 feature 브랜치 — remote 부재로 PR 생략. 사용자 승인 2026-06-04)
- merge_pending: false  (라이브 골든패스 V-A1~A6 전부 PASS 2026-06-05 장중 — 사용자 승인으로 main ff 머지 진행. V-B1 토큰 24h end-to-end만 비차단 잔여)
- archive_pending: false  (2026-06-05 archive 진행 — SOURCE: Vault prd/kis-migration → DEST: archive/appdev/PARAGON-MB/prd/2026-06-05_kis-migration/)
- 라이브 PASS 후 cleanup 스프린트 후보: 키움 legacy 소스 5파일 삭제 + API_SPEC §부록 키움 legacy 삭제 + AddSymbolViewModel 주석 정리 + 키움 Keychain 항목(kr.co.kiwoom.paragon.*) 정리 검토
- 이전 plan 백업: SPRINT_PLAN-2026-06-02.md (refresh-recovery, done)
- 요구사항 SSOT: git docs/API_SPEC.md §[3] 이식 체크리스트 7항 + §실측 확정. 태스크 정의 SSOT: Vault prd/kis-migration/tasks.md (T0~T10 + V-*).
- closeout 체크리스트: ① API_SPEC §부록 키움 legacy 삭제 ✅(s28 `e32de2f`) ② CHANGELOG ✅(Unreleased → v0.1.0 2026-06-05) ③ release closeout ✅(v0.1.0 태그, .dmg는 사용자 결정으로 백로그 유지 2026-06-05) ④ main 머지 ✅(s27 `af122fa`) — **전 항목 마감, 스프린트 완전 종결**

## Tasks

### Task 1: KIS 기반 레이어 — KISEnvironment 치환 + Keychain 식별자 교체 (+T0 docs 정합 확인)
- 유형: implement
- 매핑: tasks.md T0 + T1 + T2
- 전략: KIS* 신규 병존 — 키움 legacy 즉시 삭제 금지(design.md:80, 검증 완료 후 정리). 매 태스크 종료 시 빌드+기존 테스트 그린.
- 상태: done  (dev 1회 → review PASS 치명0/권장1/참고2 → qa 6/6 PASS, swift test 46개 회귀0)
- 담당: developer
- 의존: 없음
- 시도: 1
- 산출물: Sources/PMCore/Network/KISEnvironment.swift(신규) / Sources/PMCore/Auth/KeychainStore.swift(KISCredential additive) / docs/OPERATIONAL_NOTES.md / 리뷰 docs/reviews/kis-migration-task-1-review.md / QA docs/sprints/kis-migration-task-1-qa.md
- 리뷰 이월: Task 5 조립 리뷰에서 KISEnvironment·KISCredential reachability 게이트 필수 (미연결 잔존 시 치명)
- commit: a8d2440 (feat) + a20f0b2 (sprint docs)

### Task 2: KISRESTClient — 골격+600ms 스로틀 → 인증(tokenP·Approval) → 조회(CTPF1002R·FHKST01010100)
- 유형: implement
- 매핑: tasks.md T3 + T4 + T5 (design.md §구현 분할 계획 — 골격 단일 Write 후 섹션 1~3 staged Edit)
- 상태: done  (dev 1회 → review PASS 치명0/권장3/참고5 → qa 4/4 PASS + 신규 KISRESTClientTests 19케이스, swift test 65개 회귀0)
- 담당: developer
- 의존: task-1
- 시도: 1
- 산출물: Sources/PMCore/Network/KISRESTClient.swift(신규 264줄) / Tests/PMCoreTests/KISRESTClientTests.swift(qa 신규 19케이스) / docs/OPERATIONAL_NOTES.md / 리뷰 docs/reviews/kis-migration-task-2-review.md / QA docs/sprints/kis-migration-task-2-qa.md
- 리뷰 이월 (Task 3 흡수): R1 REST 숫자 파싱 콤마/부호 정규화를 KIS 파서 SSOT로 수렴 · R2 잔여(parseExpiry 케이스 일부는 qa 테스트로 선커버) · R3 parseExpiry static화 검토
- 리뷰 이월 (Task 5 필수): KISRESTClient 4메서드 reachability + RESTError→SymbolLookupError 매핑 검증
- commit: d9d5510 (feat) + 8a290b1 (sprint docs)

### Task 3: KISQuoteParser + 파서 테스트 KIS 재잠금 + Units & Signs Audit
- 유형: implement
- 매핑: tasks.md T6 + V-C1 + V-C2 (signed 직접 파싱 + sign 검증용 — Module Map 경계 규칙 ④ 강제) + Task 2 이월 R1·R2잔여·R3 흡수
- 상태: done  (dev 1회 → review PASS 치명0/권장2/참고3 → qa V-C1·V-C2 PASS, swift test 83개 회귀0, Audit 7행 전수 테스트 잠금)
- 담당: developer
- 의존: 없음
- 시도: 1
- 산출물: Sources/PMCore/Network/KISQuoteParser.swift(신규 ~130줄) / Tests/PMCoreTests/QuoteParsingTests.swift(KIS 18케이스 추가, 기존 9 보존) / Sources/PMCore/Network/KISRESTClient.swift(R1 3줄 수렴) / docs/OPERATIONAL_NOTES.md / 리뷰 docs/reviews/kis-migration-task-3-review.md / QA docs/sprints/kis-migration-task-3-qa.md
- 이월 처리: R1 흡수 완료 / R2 잔여 케이스 테스트 잠금 완료 / R3 static화 스킵 확정(qa 작성 KISRESTClientTests 5케이스 보존 우선 — instance 유지)
- 리뷰 이월 (Task 4/5): parseStockInfo CTPF1002R 필드 불일치(pdno 12자리) 호출처 확정 시 해소 · lookupPrice sdpr>0 가드 비대칭 검토
- commit: f6c9e52 (feat) + 51f4626 (sprint docs)

### Task 4: KISWebSocketClient — 골격(Event 불변·approvalKeyProvider) → 프로토콜(envelope·46필드 청킹 위임·PINGPONG)
- 유형: implement
- 매핑: tasks.md T7 + T8 (design.md §구현 분할 계획 — 골격 단일 Write 후 섹션 1~2 staged Edit)
- 상태: done  (dev 1회 → review PASS 치명0/권장2/참고3 → qa 4 PASS/1 N-A, swift test 83개 회귀0. Event enum 키움과 문자 단위 동일 = QuoteService 계약 경계 보존)
- 담당: developer
- 의존: task-3
- 시도: 1
- 산출물: Sources/PMCore/Network/KISWebSocketClient.swift(신규 ~210줄 actor) / docs/OPERATIONAL_NOTES.md / 리뷰 docs/reviews/kis-migration-task-4-review.md / QA docs/sprints/kis-migration-task-4-qa.md
- QA 갭 기록: handle/handleJSON/handleRaw private — 단위 테스트 표면 없음(키움 동일 패턴). 체결 수신 경로는 라이브 V-A2·A6 커버 예정
- 리뷰 이월 (Task 5): ① .connected 멱등화 검토 ② WS approval 영구 실패 가시화 갭 ③ KISWebSocketClient·KISEnvironment·KISCredential·KISRESTClient 전부 배선 게이트 (미배선 잔존 시 치명 승격) ④ RESTError→SymbolLookupError 매핑
- commit: 61d4b53 (feat) + 07002ea (sprint docs)

### Task 5: 조립 — Info.plist ATS 예외 + AppDelegate 조립 루트 KIS 교체
- 유형: implement
- 매핑: tasks.md T9 + T10 (symbolLookup 클로저 = CTPF1002R 종목명만, 초기 시세는 QuoteService.loadInitial REST 경로 — s24 설계 결정) + Task 1~4 이월 배선 게이트
- 상태: done  (dev 1회 → review PASS 치명0/권장0/참고3 → qa 9/9 PASS. swift test 83 + AppTests 11 fresh derivedDataPath 회귀0, 배선 게이트 KIS* 5/5 도달, ATS ops.koreainvestment.com 단일 한정)
- 담당: developer
- 의존: task-1, task-2, task-3, task-4
- 시도: 1
- 산출물: project.yml(ATS +4줄) / App/AppDelegate.swift(KIS 전환 65줄) / Sources/PMCore/Service/QuoteService.swift(타입 참조 갱신 — tasks.md T10 명시 범위) / docs/OPERATIONAL_NOTES.md / 리뷰 docs/reviews/kis-migration-task-5-review.md / QA docs/sprints/kis-migration-task-5-qa.md
- 이월 처리: ① .connected 멱등화 — WatchlistViewModel 조건부 전이로 이미 멱등, 변경 불요 기록 ② approval 영구 실패 가시화 — MVP 제외 유지(s23 결정), loadInitial→authFailed 경로가 자격증명 오류 커버, approval 단독 엣지는 ops 노트 수집 대상 ③ 배선 게이트 5/5 ④ RESTError→SymbolLookupError 매핑 완료
- closeout 추가 기록: AddSymbolViewModel 주석에 KiwoomRESTClient 언급 잔존(동작 무영향) — 키움 legacy 정리 시 함께 / Sendable 경고 3건(Swift 5 모드 비차단, Swift 6 전환 시 KISRESTClient actor화 검토)
- commit: 249f563 (feat — CHANGELOG Unreleased 엔트리 포함) + 34ccd56 (sprint docs)

### Task 6: 자동화 검증 스위프 — 회귀 0 게이트
- 유형: implement (검증 중심 — 수정은 발견 결함 한정)
- 매핑: tasks.md V-C1b + V-B1t + V-B2 + V-C4
- 상태: done  (qa 단독 실행 — 검증 중심 태스크로 dev 단계 공집합, 결함 0건이라 developer 루프 미발동. 4/4 공식 PASS: PMCore 83 + AppTests 11 fresh dd 회귀0 / TokenManager 4케이스 무변경 / V-B2 정적 Keychain-only / V-C4 diff scope 전수 잠금)
- 담당: qa (conductor 단순화 결정 — Cleanup Separation 단순화 준용)
- 의존: task-5
- 시도: 1
- 산출물: docs/sprints/kis-migration-task-6-qa.md (제품 코드 수정 0건)
- commit: 49a1d48 (sprint docs — Meta done 마킹 포함)

## 라이브/수동 검증 (자동 루프 밖 — 오너 게이트)

> 거래일 09:00–15:30 KST 한정 항목 포함. 명세 = Vault prd/kis-migration/tasks.md §검증 단계.

- [x] V-A1 (라이브): 종목 등록 → CTPF1002R 종목명 + 초기 시세, EGW00201 0회 — **PASS 2026-06-05 장중(금 09:3x~)**. 오너 확인: 종목명 자동 표시 + 초기 시세 렌더 정상, 에러 0.
- [x] V-A1e (라이브): 등록 실패 분기 — **PASS 2026-06-05**. 미존재 코드 → "등록할 수 없는 종목코드" 인라인 에러 확인 (**P6 관측 종결** — 보정 불요).
- [x] V-A2 (라이브): WS 체결 0.3s 내 하이라이트·갱신 — **PASS 2026-06-05 장중**. 멀티 레코드 청킹 회귀 없음 (최대 회귀 후보였음).
- [x] V-A3 (라이브): 부호 체계 정확 표시 — **PASS 2026-06-05**. 하락 종목 음수 부호 정확 표시 실측 → **P5(REST `prdy_vrss` 하락 부호) 종결** — signed 직접 파싱 검증 확인.
- [x] V-A4 (라이브): 20개 한도 + P7 WS 한도 종결 — **PASS 2026-06-05 장중**. 오너 확인: 20개 도달 후 추가 시 한도 안내·미추가 + **20개 동시 구독 전 종목 시세 갱신 정상 → P7 종결** (WS 한도 ≥20, `Policy.maxWatchlistCount` 유지).
- [x] 🆕 발견 이슈 (비차단, 별도 픽스 — KIS 회귀 아님): KRX 신형 알파뉴메릭 티커(예: 에임드바이오 `0009K0`) 입력 불가 — `AddSymbolView.swift:38` `filter(\.isNumber)` + `AddSymbolViewModel.swift:53` 숫자-only guard (Phase D 기존 코드). REST/WS/영속화는 문자열 키라 무영향. → **종결 2026-06-05 (커밋 `77c9ada`)**: 입력 필터·submit 검증 영숫자 확장 + 소문자 대문자 정규화 + 단위 테스트 9건(AppTests 11→20). **라이브 실측 PASS 2026-06-05 장중** — `0009K0` 등록 → 종목명·시세·WS 갱신 정상 (KIS REST/WS 알파뉴메릭 수용 확인, 🟡 해소).
- [x] V-A5 (라이브): 삭제 시 구독 즉시 제거 — **PASS 2026-06-05**. 목록 즉시 제거 + 잔여 종목 갱신 지속.
- [x] V-A6 (라이브): WS 재연결 구독 자동 복구 — **PASS 2026-06-05**. Wi-Fi off→on 후 시세 갱신 자동 재개 (**refresh-recovery V13 겸사 PASS** — KIS 전환으로 처음 검증 가능해진 항목).
- [ ] V-B1 (일부 라이브): 토큰 24h 갱신 지속 end-to-end — **잔여**. 2026-06-05 장중 세션 이상 없음 관찰, 24h 경과 자동 재발급 end-to-end는 미종결 (장시간 상주 관찰 필요).
- [x] V-C3 (장외 가능): 장외 종가 + 장상태 라벨 + 갱신 정지 — **PASS 2026-06-04 장외(목 18:00경)**. 오너 확인: 관심종목 7개 종가 렌더 + "정규장 마감 · 종가 기준" 라벨 + 하이라이트/갱신 0 + auth-failed 배너 없음.
- [x] (겸사) keychain 서명 오너 런타임 게이트 — **PASS 2026-06-04**. ① 첫 실행(KIS 항목 첫 접근) "Always Allow" 클릭 → ② cdhash 변경 빌드(임시 프로브 1줄, CDHash 5e35c06a→f797cc56)에서 **무프롬프트 + 키 읽기 정상** = DR 기반 신뢰 영구지속 경험 증명 → ③ 프로브 원복(결정론적 빌드로 CDHash 원값 복귀 확인). s20 잔여 종결. ※ 검증 메모: touch·clean build로는 cdhash 불변(결정론적 빌드) — 교차빌드 검증엔 실코드 변경 필요.
