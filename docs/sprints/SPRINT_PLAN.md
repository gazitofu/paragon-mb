# Sprint Plan

## Meta
- 생성일: 2026-06-04
- 기능: kis-migration (watchlist-realtime 데이터 프로바이더 KIS 이식)
- PRD: /Users/gazitofu/Vault/appdev/PARAGON-MB/prd/kis-migration/
- 모드: Strict  (Auto-Strict: auth 접점 TokenManager·approval_key·Keychain 식별자 + ATS Info.plist env config + provider 전면 교체)
- 상태: in-progress
- 브랜치: feat/kis-migration (로컬 feature 브랜치 — remote 부재로 PR 생략, closeout 시 main 머지. 사용자 승인 2026-06-04)
- 이전 plan 백업: SPRINT_PLAN-2026-06-02.md (refresh-recovery, done)
- 요구사항 SSOT: git docs/API_SPEC.md §[3] 이식 체크리스트 7항 + §실측 확정. 태스크 정의 SSOT: Vault prd/kis-migration/tasks.md (T0~T10 + V-*).
- closeout 체크리스트: ① API_SPEC §부록 키움 legacy 삭제 (reviewer 메모 — affects 등재, 이식 완료 시점) ② CHANGELOG required ③ release closeout required ④ main 머지

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
- commit: (미정)

### Task 5: 조립 — Info.plist ATS 예외 + AppDelegate 조립 루트 KIS 교체
- 유형: implement
- 매핑: tasks.md T9 + T10 (symbolLookup 클로저 = CTPF1002R 종목명만, 초기 시세는 QuoteService.loadInitial REST 경로 — s24 설계 결정)
- 상태: pending
- 담당: developer
- 의존: task-1, task-2, task-3, task-4
- 시도: 1
- 산출물: (미정)
- commit: (미정)

### Task 6: 자동화 검증 스위프 — 회귀 0 게이트
- 유형: implement (검증 중심 — 수정은 발견 결함 한정)
- 매핑: tasks.md V-C1b + V-B1t + V-B2 + V-C4
- 상태: pending
- 담당: developer
- 의존: task-5
- 시도: 1
- 산출물: (미정)
- commit: (미정)

## 라이브/수동 검증 (자동 루프 밖 — 오너 게이트)

> 거래일 09:00–15:30 KST 한정 항목 포함. 명세 = Vault prd/kis-migration/tasks.md §검증 단계.

- [ ] V-A1 (라이브): 종목 등록 → CTPF1002R 종목명 + 초기 시세, EGW00201 0회
- [ ] V-A1e (라이브): 등록 실패 분기 (P6 실제 형태 관측·보정)
- [ ] V-A2 (라이브): WS 체결 0.3s 내 하이라이트·갱신 (멀티 레코드 청킹)
- [ ] V-A3 (라이브): 부호 체계 정확 표시 + P5 REST 하락 부호 종결 (비-blocking)
- [ ] V-A4 (라이브): 20개 한도 + P7 WS 한도 종결
- [ ] V-A5 (라이브): 삭제 시 구독 즉시 제거
- [ ] V-A6 (라이브): WS 재연결 구독 자동 복구
- [ ] V-B1 (일부 라이브): 토큰 24h 갱신 지속 end-to-end
- [ ] V-C3 (장외 가능): 장외 종가 + 장상태 라벨 + 갱신 정지
- [ ] (겸사) keychain 서명 오너 런타임 게이트 — 첫 실행 "Always Allow" 1회 → 재빌드 무프롬프트 (s20 잔여)
