# Operational Notes

에이전트들이 발견한 빌드/테스트/환경 관련 학습 사항. 최대 50항목.
형식: `- [{날짜}] {내용} ({에이전트명})`

## 빌드

## 테스트

## 환경

## 주의사항

- [2026-06-04] keychain 서명 오너 런타임 게이트 PASS(s20 잔여 종결, V-C3 겸사): 첫 실행 "Always Allow" 1회 후, cdhash가 다른 빌드에서 무프롬프트 + KIS 키 읽기 정상 = DR 기반 신뢰 영구지속 경험 증명. **검증 시 발견**: Xcode 빌드는 결정론적 — `touch` 재빌드·`clean build` 모두 CDHash 불변(Xcode 16 debug-dylib 구조상 코드 변경도 stub 실행파일 불변 + 동일 소스는 bit-identical 산출). 교차빌드 서명 검증에는 **실제 코드 변경**(임시 프로브 1줄 추가→검증→원복)이 필요. 원복 후 CDHash 원값 복귀로 bit-exact 확인 가능. (main)
- [2026-06-04] Task 5 조립 완료(T9+T10): project.yml info.properties에 NSAppTransportSecurity(ops.koreainvestment.com NSExceptionAllowsInsecureHTTPLoads) 추가 → xcodegen 재생성으로 Info.plist 영속. AppDelegate KIS* 전환 + QuoteService 타입 참조(KiwoomRESTClient→KISRESTClient, KiwoomWebSocketClient→KISWebSocketClient) + init(rest:tokenManager:approvalKeyProvider:appKey:appSecret:) 교체. swift test 83/83 PASS 회귀 0, xcodebuild BUILD SUCCEEDED. .connected 멱등: WatchlistViewModel state 조건 분기가 멱등 소비 확인 — KISWebSocketClient 변경 불요. (developer)
- [2026-06-04] KISWebSocketClient(신규, T7+T8) — actor + Event enum(시그니처 불변) + approvalKeyProvider 주입 + H0STCNT0 approval envelope(tr_type "1"=구독/"2"=해지) + PINGPONG echo + raw flag|tr_id|건수|본문 분기 + KISQuoteParser.parseExecutionChunked 위임 + 지수 백오프 재연결(2·4·8·16·30s 상한). setSubscriptions는 추가/제거 diff를 각각 별도 envelope으로 송신. connect마다 approvalKeyProvider 1콜(캐시 불요). swift test 83/83 PASS 회귀 0. (developer)
- [2026-06-04] KISQuoteParser(신규) — parseExecutionChunked(46×N 청킹), parseRecord([0]~[5] signed 직접+sign 검증), parseStockInfo(CTPF1002R), parsePrice(FHKST01010100), parseSignedInt/Double. KISRESTClient.lookupPrice 숫자 파싱 KISQuoteParser.parseSignedInt 수렴(R1). QuoteParsingTests에 KISQuoteParserTests 18케이스 추가(기존 Kiwoom 단언 보존). swift test 83/83 PASS 회귀 0. (developer)
- [2026-06-04] KISRESTClient(신규) — ThrottleQueue actor(600ms 직렬 가드) + issueToken(tokenP `appsecret`) + issueApprovalKey(Approval `secretkey`) + lookupName(CTPF1002R `prdt_abrv_name` trim) + lookupPrice(FHKST01010100 `stck_sdpr` → Quote.previousClose, prdy_vrss signed 직접). swift test 46/46 PASS 회귀 0, 기존 테스트 무수정. (developer)
- [2026-06-04] KISEnvironment(신규)·KISCredential(KeychainStore 추가) — KiwoomEnvironment/KiwoomCredential과 병존. AppDelegate는 Task 10(조립 루트)에서 KIS로 전환 전까지 Kiwoom 식별자 유지. swift test 46 Suite passed, 회귀 0. (developer)

- [2026-06-01] NWPath.Status를 직접 주입하는 테스트 패턴: NetworkPathReachability는 handleStatusUpdate(_:) 내부 메서드를 @testable import로 노출해 NWPathMonitor 실물 없이 결정론적 단위 테스트 가능. Swift 6 모드에서 @Sendable 클로저 내 var 캡처는 warning이나 Swift 5.9(Package.swift swift-tools-version:5.9)에서는 에러 아님. (developer)
- [2026-06-01] PARAGON-MBTests Xcode unit test 타겟: bundle.unit-test + BUNDLE_LOADER/TEST_HOST로 App 타겟 호스트 설정. CODE_SIGN_IDENTITY="-" + CODE_SIGNING_REQUIRED/ALLOWED=NO 플래그 없이도 xcodebuild test 성공(ad-hoc). XCTest dylib은 macOS 14.0 기준이라 macOS 13.0 배포 대상 지정 시 ld warning 발생하나 테스트 실행에는 무해. (developer)
- [2026-06-01] PARAGON-MBTests Info.plist 필수: bundle.unit-test 타입은 xcodegen이 Info.plist를 자동 생성하지 않음. project.yml settings.base에 GENERATE_INFOPLIST_FILE: YES를 명시하지 않으면 "Cannot code sign because the target does not have an Info.plist file" 에러로 빌드 실패. (developer)
- [2026-06-01] @MainActor 클래스 deinit에서 Sendable protocol 호출 안전: WatchlistViewModel(@MainActor)의 deinit에서 reachability.stop()(NetworkReachability: Sendable)을 직접 호출 가능. deinit은 actor isolation 외부에서 실행되지만 Sendable 계약이 있어 빌드 경고 없음(Swift 5.9 확인). (developer)
- [2026-06-02] @MainActor VM + actor mock QuoteService 조합 테스트 패턴: AsyncStream.Continuation.yield()는 thread-safe이므로 nonisolated emit() 메서드 + @unchecked Sendable 래퍼로 actor 격리 없이 이벤트 주입 가능. drainTasks()에 Task.yield()×30 + Task.sleep(5ms)를 조합해야 MainActor 큐의 for-await 소비 Task가 안정적으로 처리됨(yield()×10만으론 타이밍 불안정). (developer)
- [2026-06-02] Task 5 MarketStatusHeader refreshButton 배선: 순수 UI 배선(단일 파일 수정)으로 BUILD SUCCEEDED + PMCore swift test 46/46 회귀 0. isAdding 블록 내 symbols.isEmpty 조건 중첩 구조로 표시조건 구현(T7 `!symbols.isEmpty && !isAdding` 충족). (developer)
- [2026-06-02] 코드 서명 ad-hoc → Apple Development 교체(keychain 재프롬프트 해소, B1): `project.yml` 앱·테스트 타깃 `CODE_SIGN_IDENTITY "-"` → `"Apple Development"` + `DEVELOPMENT_TEAM: F29HVM9355`(무료 Personal Team). 근본원인 = ad-hoc 서명은 빌드마다 cdhash 변동 → designated requirement(DR)에 cdhash 포함 → keychain "Always Allow"가 매 재빌드마다 무효화. 교체 후 DR = `identifier + anchor apple generic + leaf CN`(cdhash 無)로 고정 → 재빌드해도 동일 DR → Always Allow 영구 지속. **선결 함정**: Xcode가 무료 cert를 발급해도 발급자(WWDR **G3**) 중간 인증서가 keychain에 없으면 `security find-identity -v -p codesigning`이 0개 반환(체인 단절) → Apple 공개 배포 `AppleWWDRCAG3.cer`(apple.com/certificateauthority)를 login keychain에 import해야 유효 ID로 잡힘. macOS 로컬 개발은 provisioning profile 불요(Development cert 직접 서명, Manual 유지). (main)
