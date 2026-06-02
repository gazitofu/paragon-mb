# Architecture — PARAGON-MB

> 갱신: 2026-05-29 (`/team-dev:architect-design`, 기능 `holdings-pnl` 두 번째 슬라이스 — §보유종목 슬라이스 추가). 근거: `Vault/appdev/PARAGON-MB/prd/holdings-pnl/{proposal.md, design.md}` + `decisions/2026-05-29-holdings-pnl-display-policy.md`(결정 A 단순 평가손익식). 큰 변경(실계좌 잔고 인증 축 + 신규 도메인·store·계산 lib·뷰) 사전 갱신.
> 갱신: 2026-05-28 (`/team-dev:architect-design`, 기능 `watchlist-realtime` 첫 슬라이스 기준).
> 근거: `Vault/appdev/PARAGON-MB/prd/watchlist-realtime/{proposal.md, design.md}`. Approaches ② 하이브리드(WebSocket 채택, 슬롯 예산·멀티계좌 추상화는 이연) 사용자 확정.
> 개정: 2026-05-28 — 메뉴바 셸을 SwiftUI `MenuBarExtra(.window)` → AppKit `NSStatusItem`+`NSPopover`(AppDelegate 혼합)로 변경(사용자 결정). 패널 UI는 `NSHostingController`로 SwiftUI 그대로 호스팅. App 레이어 셸 구현만 변경 — PMCore·데이터·인증·장상태 로직 불변. 참조: 사용자가 현재 사용하는 TokenEater(NSStatusItem+NSPopover 패턴) + Stats·Fantastical 등 프로덕션 메뉴바 앱 표준.

## 개요

macOS 메뉴바 상주 앱. AppKit `NSStatusItem`+`NSPopover` 단일 팝오버 패널이 전체 UI이며, 팝오버 콘텐츠는 `NSHostingController`로 SwiftUI 패널(PanelRootView)을 호스팅한다. 키움 REST/WebSocket을 직접 호출해 관심종목 시세를 표시한다. **조회 전용 — 주문 기능 없음.** 분리형 `NSWindow` 대시보드는 v1에서 도입하지 않는다(팝오버 단일로 충분).

첫 Swift 프로젝트라는 학습 맥락을 고려해 표준적이고 과하지 않은 4-레이어 구조를 채택한다. 보유종목·지수 등 미래 슬라이스의 확장 골격(구독 매니저·슬롯 예산기·모의/실계좌 전환 계층)은 **선제 구축하지 않는다**(과설계 방지) — 단, 그 자리에 끼워 넣을 수 있도록 경계만 명확히 둔다(§하이브리드 추상화 경계).

## 스택

| 영역 | 선택 | 근거 |
|---|---|---|
| 언어 | Swift 5.9+ | 첫 Swift 프로젝트, macOS 네이티브 |
| 셸/UI | AppKit `NSStatusItem`+`NSPopover` (셸) + SwiftUI (패널 UI, `NSHostingController` 호스팅) | 메뉴바 아이콘은 `NSStatusItem`이 소유하고 팝오버는 `NSHostingController`로 SwiftUI 패널을 호스팅. SwiftUI `MenuBarExtra` 대비 ⑴ 우클릭 컨텍스트 메뉴(NSMenu) 표준 지원, ⑵ `popover.show`/`performClose` 프로그램적 제어, ⑶ `preferredContentSize`로 320pt 폭·최대 높이 명시 제어, ⑷ v2 메뉴바 상시 텍스트(`button` image/title) 경로 확보. 사용자 결정 2026-05-28 (참조: TokenEater·Stats·Fantastical 프로덕션 패턴). 추가 비용 ~50–80줄 보일러플레이트 |
| 앱 생명주기 | SwiftUI `App` + `@NSApplicationDelegateAdaptor(AppDelegate.self)` 혼합 | `AppDelegate.applicationDidFinishLaunching`에서 `StatusBarController`를 생성. SwiftUI 선언적 진입과 AppKit 셸 제어를 함께 사용 |
| 빌드 형식 | **Xcode 앱 프로젝트** (`.xcodeproj`) + 로컬 SwiftPM 패키지로 코어 분리 | 메뉴바 앱은 앱 번들·Info.plist·`LSUIElement`(Dock 미표시)·코드사이닝이 필요 → 순수 `Package.swift` executable로는 번들 구성이 번거롭다. AppDelegate 혼합 생명주기와도 정합. 코어 로직(네트워킹·도메인·저장)은 로컬 SwiftPM 패키지(`PMCore`)로 분리해 단위 테스트 가능하게 함 |
| 비동기 | Swift Concurrency (`async/await`, `AsyncStream`, `actor`) | 콜백·델리게이트보다 학습·가독성 유리. WebSocket 수신 스트림을 `AsyncStream`으로 모델링 |
| WebSocket | `URLSessionWebSocketTask` (Foundation 내장) | 외부 의존성 0. Starscream 등 서드파티 불필요 |
| HTTP | `URLSession` (Foundation 내장) | 동일 |
| 자격증명 보관 | macOS Keychain Services (`Security` 프레임워크) | 평문 저장 금지(Premise #7 confirmed). 얇은 래퍼만 자작 — 외부 의존성 불필요 |
| 관심종목 영속 | JSON 파일 (`~/Library/Application Support/PARAGON-MB/watchlist.json`) | 종목코드+순서 소수 데이터에 Core Data/SQLite는 과함. `Codable` + atomic write로 충분 |
| 최소 타깃 | macOS 13 (Ventura) | SwiftUI Concurrency·`NSHostingController` 안정성 기준 |
| 외부 의존성 | **없음** (Foundation/SwiftUI/AppKit/Security 표준만) | 첫 프로젝트 의존성 관리 부담 최소화 |

> 자격증명은 절대 git에 들어가지 않음 — `.gitignore` 처리됨. appkey/secret은 사용자가 앱 최초 실행 시 입력 → Keychain 저장.

## 레이어 구조 (4계층)

```
┌─────────────────────────────────────────────┐
│ App (Xcode target)                          │
│  PARAGONMBApp.swift  — SwiftUI App + @NSApplicationDelegateAdaptor
│  AppDelegate.swift   — applicationDidFinishLaunching → StatusBarController 생성
│  StatusBarController — NSStatusItem+NSPopover(.transient), 좌클릭 토글/우클릭 NSMenu,
│                        NSHostingController로 PanelRootView 호스팅
│  Views/             — SwiftUI 뷰 (V1/V2/V3)  │
│  ViewModels/        — @MainActor ObservableObject (화면 상태)
└────────────────┬────────────────────────────┘
                 │ depends on
┌────────────────▼────────────────────────────┐
│ PMCore (로컬 SwiftPM 패키지 — 테스트 대상)   │
│  Domain/   — 순수 모델·정책(엔티티, 장 상태) │
│  Service/  — 시세 오케스트레이션(REST+WS 통합)│
│  Network/  — 키움 REST·WebSocket 클라이언트  │
│  Auth/     — 토큰 발급·재발급·Keychain       │
│  Store/    — 관심종목 JSON 영속              │
└──────────────────────────────────────────────┘
```

**의존성 방향**: App → PMCore (단방향). PMCore는 SwiftUI·AppKit에 의존하지 않음(Domain은 순수 Swift) → 단위 테스트 용이. 뷰는 ViewModel만 알고, ViewModel은 PMCore의 Service 프로토콜만 안다. 셸(NSStatusItem/NSPopover/AppDelegate) 변경은 App 레이어 내부에 갇혀 PMCore에 영향을 주지 않는다.

## 폴더 구조 (제안)

```
PARAGON-MB/
├── PARAGON-MB.xcodeproj              # 앱 번들 빌드 (LSUIElement=YES)
├── App/                              # Xcode 앱 타깃 소스
│   ├── PARAGONMBApp.swift            # SwiftUI App + @NSApplicationDelegateAdaptor(AppDelegate)
│   ├── AppDelegate.swift             # applicationDidFinishLaunching → StatusBarController 생성
│   ├── StatusBarController.swift     # NSStatusItem+NSPopover(.transient), 좌클릭 토글/우클릭 NSMenu, NSHostingController 호스팅
│   ├── Info.plist                    # LSUIElement, App Transport Security
│   ├── Views/
│   │   ├── PanelRootView.swift       # P0 라우팅(V1/V2/V3 전환)
│   │   ├── EmptyStateView.swift      # V1 빈 상태
│   │   ├── WatchlistView.swift       # V2 목록 뷰
│   │   ├── WatchlistRowView.swift    # 종목 행(등락 색·심볼·하이라이트)
│   │   ├── AddSymbolView.swift       # V3 종목 등록
│   │   └── MarketStatusHeader.swift  # 장 상태 라벨 + 갱신 시각 + 경고/인증 인디케이터
│   └── ViewModels/
│       ├── WatchlistViewModel.swift  # @MainActor — 화면 상태·이벤트 처리
│       └── AddSymbolViewModel.swift  # V3 등록 상태(idle/loading/error/success)
├── Sources/PMCore/                   # 로컬 SwiftPM 패키지 (Package.swift는 repo 루트)
│   ├── Domain/
│   │   ├── Symbol.swift              # 종목 모델(코드·이름)
│   │   ├── Quote.swift               # 시세 모델(현재가·등락액·등락률·기준종가)
│   │   ├── PriceDirection.swift      # 상승/하락/보합 enum(부호·심볼 파생)
│   │   ├── MarketStatus.swift        # 장전/장중/장마감 enum
│   │   ├── MarketClock.swift         # 현재 시각 → 장 상태 판별(경계값·공휴일)
│   │   └── Policy.swift              # 정책 상수(관심종목 한도 등) — 하드코딩 분리
│   ├── Service/
│   │   └── QuoteService.swift        # REST 초기값 + WS 갱신 통합 오케스트레이션
│   ├── Network/
│   │   ├── KiwoomRESTClient.swift    # 종목 조회·토큰 발급 REST
│   │   ├── KiwoomWebSocketClient.swift # 체결 구독 WS(연결·재연결·AsyncStream)
│   │   └── KiwoomEnvironment.swift   # 모의/실 baseURL·엔드포인트 상수
│   ├── Auth/
│   │   ├── TokenManager.swift        # actor — 토큰 발급·만료 추적·자동 재발급
│   │   └── KeychainStore.swift       # 자격증명 Keychain CRUD 래퍼
│   └── Store/
│       └── WatchlistStore.swift      # 관심종목 JSON 영속(load/save atomic)
├── Tests/PMCoreTests/                # PMCore 단위 테스트
│   ├── MarketClockTests.swift
│   ├── PriceDirectionTests.swift
│   ├── QuoteParsingTests.swift       # WS 페이로드 → Quote 부호·스케일 단언
│   ├── PolicyTests.swift             # 한도 정책
│   └── WatchlistStoreTests.swift
├── Package.swift                     # PMCore 패키지 정의(루트)
└── docs/                             # SSOT (본 문서 포함)
```

> 현재 `Sources/`·`Tests/`는 `.gitkeep`만 존재. `Package.swift` 미생성 → sprint 첫 태스크에서 스택 부트스트랩.

## 핵심 컴포넌트 책임

- **AppDelegate** (`NSApplicationDelegate`, `@NSApplicationDelegateAdaptor`로 SwiftUI App에 연결): `applicationDidFinishLaunching`에서 `StatusBarController`를 생성·보유. SwiftUI 선언적 진입과 AppKit 셸 제어의 연결점.
- **StatusBarController**: `NSStatusBar.system.statusItem(withLength: .variableLength)`와 `NSPopover()`를 소유. `button.action`+`sendAction(on: [.leftMouseUp, .rightMouseUp])`으로 좌클릭=팝오버 토글(`popover.show(relativeTo:of:preferredEdge:.minY)`/`performClose`)·우클릭=`NSMenu` 컨텍스트 메뉴(종료·설정) 분기. `popover.behavior = .transient`(바깥 클릭 자동 닫힘, 필요 시 `NSEvent.addGlobalMonitorForEvents` 보강)·`preferredContentSize`(320pt 폭)로 패널 크기 제어. 팝오버 콘텐츠는 `NSHostingController(rootView: PanelRootView)`로 SwiftUI 패널을 호스팅 — 셸은 패널 내부 상태를 모른다(경계). v2에서 `button` image/title로 메뉴바 상시 텍스트를 추가할 진입점. (참조: 사용자 사용 앱 TokenEater의 NSStatusItem+NSPopover 패턴 — 단, 컨텍스트 메뉴 다수·MenuBarRenderer·대시보드 창 등 v1 미해당분은 복제하지 않고 ~50–80줄 경량 유지.)
- **WatchlistViewModel** (`@MainActor ObservableObject`): 화면 상태(loading/normal/ws-disconnected/authFailed/empty)의 단일 소유자. QuoteService의 `AsyncStream`을 구독해 행 데이터를 갱신하고, 등록/삭제 사용자 이벤트를 Service·Store로 위임. 뷰는 이 ViewModel의 `@Published` 상태만 렌더한다. **refresh 복구**: `refresh()`가 authFailed 포함 막힌 상태에서 `service.start` 재트리거(중복 가드 `isRefreshing` 직교 플래그) — 헤더 수동 버튼·loadFailed 배너·네트워크 복구 콜백 3진입이 수렴(retry() 흡수).
- **NetworkPathReachability** (`NetworkReachability` protocol, PMCore Domain/lib): `NWPathMonitor` 래핑. unsatisfied→satisfied transition-edge에서만 `onRecovered` 1회 발화(최초 satisfied 무시) → VM `refresh()` 자동 호출. VM/UI는 OS 모니터링 API를 모른다(경계).
- **QuoteService**: 관심종목 변경 → REST 초기값 로드 → WS 구독 등록/해제 오케스트레이션. 장 상태(MarketClock)에 따라 WS 구독을 켜고 끈다(장 외에는 구독 없이 마지막 값 유지). ViewModel에 `AsyncStream<QuoteUpdate>` 제공.
- **KiwoomWebSocketClient**: `URLSessionWebSocketTask` 래핑. 연결·재구독·재연결(지수 백오프) 담당. 끊김/복구를 상태 이벤트로 emit. **슬롯 예산 추상화는 두지 않음** — 단순 종목코드 set 구독/해제만(하이브리드 경계).
- **TokenManager** (`actor`): 토큰 1개 소유·만료 시각 추적. 만료 임박(예: 잔여 < 임계) 또는 401 응답 시 재발급. 재발급 실패는 상태로 표면화. REST·WS 클라이언트는 이 actor에서 유효 토큰을 받아 사용.
- **MarketClock**: 순수 함수 — `Date` → `MarketStatus`. 정규장 경계·점심 연속거래·공휴일 캘린더(상수 테이블)를 입력으로. 외부 호출 없음 → 테스트 100% 결정적.
- **WatchlistStore**: 종목코드+순서 JSON 영속. atomic write(임시 파일 → rename). 손상 파일은 빈 목록으로 폴백.

## 하이브리드 추상화 경계 (이연 결정 — 사용자 확정 ②)

첫 슬라이스에서 **두지 않는** 것(과설계 방지). 미래 슬라이스 진입 시 도입한다:

| 항목 | 첫 슬라이스 결정 | 갱신(holdings-pnl, 2026-05-29) |
|---|---|---|
| 구독 매니저(슬롯 예산기) | 도입 안 함. WS 클라이언트가 종목코드 set만 구독/해제 | **합집합 set 채택**: `QuoteService`가 watchlist·holdings 코드를 분리 보관하고 `Set(watchlist)∪Set(holdings)`로 단일 진입점 구독. 중복 1회는 Set 연산이 자동 보장. **full ref-count는 여전히 v2 이연**(지수·예수금 진입 시) |
| 모의/실계좌 전환 계층 | 도입 안 함. `KiwoomEnvironment`에 baseURL 상수 2개(mock/real)만 두고 빌드 시 mock 고정 | **전환 계층 신설 안 함 유지**. 실계좌 구분은 토큰에 내재. 모의 토큰 잔고 가드는 `HoldingsViewModel`에 명시(Floor 4 — config 숨김 금지) |
| 슬롯 예산 추상화 | `Policy.maxWatchlistCount` 상수 1개로만 표현 | `Policy.totalSlotBudget`(관심+보유 합집합) 상수 추가. 다종 슬롯 합산 추상화는 여전히 v2 |

**경계 원칙**: WS 클라이언트는 "종목코드 집합을 구독한다"는 단순 계약만 노출한다. 미래에 슬롯 예산기를 끼워도 이 계약(구독/해제)은 바뀌지 않도록 한다. `KiwoomEnvironment`는 mock/real을 enum으로 갖되 전환 로직(잔고 인증 경로 분기)은 두지 않는다 — 상수만.

## 보유종목 슬라이스 (holdings-pnl, 2026-05-29 — 큰 변경 사전 갱신)

두 번째 슬라이스. 실계좌 잔고 인증 축을 추가하고, 저빈도 REST 잔고 스냅샷과 고빈도 WS 현재가를 결합해 **단순 평가손익(결정 A)**을 실시간 산출한다. 첫 슬라이스 `QuoteService`·`KiwoomWebSocketClient`·`TokenManager`·`PriceDirection`·`DesignTokens`를 계승하고, 위험 표면(손익 산식·부호·스케일)에만 순수 계산 lib + 테스트 잠금을 집중 투입한다.

### 신규 컴포넌트

- **HoldingPnL** (`Domain/`, 순수 lib — 손익 산식 단일 출처): 종목별 `평가손익액 = qty×(cur−pur)`·평가금액·수익률, 합산은 **Σ개별로만** 계산(별도 산식 금지 → 헤더=개별 합 보장). 원 단위 `Int` 정수 연산, 수익률만 `Double`. 결정 A 잠금 — 키움 `evltv_prft`(수수료+세금 차감)와 의도적으로 다름. `BalancePnLTests`가 부호·스케일·반올림·Σ일치·0 분모 게이트.
- **SymbolCode** (`Domain/`, 순수): `normalize6()` 종목코드 정규화 단일 함수. 잔고 `stk_cd` "A085620" → "085620"(WS 6자리와 통일). 보유↔관심 구독 공유·동일 코드 비교가 모두 이 함수를 통과(분산 금지). `SymbolCodeTests` 잠금.
- **Holding** (`Domain/Types`): 보유 종목 모델(code·name·qty·purchasePrice·purchaseAmount). 시세 비포함·**디스크 영속 안 함**(잔고 REST 재조회로 복원 — watchlist JSON과 대비).
- **KiwoomBalanceParser** (`Network/`, 격리 파서): kt00018 JSON → `[Holding]`. `stk_cd·stk_nm·rmnd_qty·pur_pric·pur_amt·cur_prc`만 추출, `evltv_prft·sum_cmsn·tax·prft_rt` 미추출(결정 A). `KiwoomBalanceParserTests` 잠금.
- **HoldingsViewModel** (`App/ViewModels/`, @MainActor): 보유 화면 상태 단일 소유자(loading/live/offline/empty/error). 잔고 폴링(`Policy.balancePollInterval`)·QuoteService 스트림 구독·손익 재계산·모의/실계좌 가드(명시 배치). watchlist와 분리.
- **HoldingsView / HoldingsSummaryHeader / HoldingsRowView / PanelTabBar** (`App/Views/`): 보유 탭 콘텐츠·합산 헤더·2단 스택 행·보유/관심 세그먼트 탭. UI는 ViewModel `@Published`만 렌더(네트워크 직접 호출 금지).

### 변경 컴포넌트

- **QuoteService**: watchlist·holdings 코드 분리 보관 + `updateHoldings(_:)` 추가. WS 구독은 항상 `Set(watchlist)∪Set(holdings)` 합집합으로 `setSubscriptions` 전달(단일 진입점 — 직접 `ws.setSubscriptions` 호출 금지). watchlist 갱신이 holdings 구독을 덮어쓰지 않음. `QuoteServicing` 프로토콜에 `updateHoldings` 추가(`WatchlistViewModel` 호출처 무영향 — 외부 시그니처 불변).
- **KiwoomRESTClient**: `fetchBalance(token:)` 추가(POST /api/dostk/acnt, api-id kt00018). 기존 `lookup`·`issueToken` 불변.
- **PanelRootView**: 탭 축·양 ViewModel 라우팅. 기존 watchlist 3분기(add/empty/list)는 관심 탭 내부로 이동(동작 불변). 생성 호출처(`StatusBarController`/`AppDelegate`)가 `holdingsViewModel` 추가 주입.
- **Policy**: `balancePollInterval`(60s 기본)·`totalSlotBudget` 상수 추가.

### 데이터 결합 흐름

보유 구성(코드·수량·평단·매입금액)은 저빈도 REST 잔고(폴링), 현재가는 고빈도 WS(`QuoteService.updates` 공유 스트림). `HoldingsViewModel`이 두 소스를 `HoldingPnL`에 넣어 매 틱 재계산. 잔고 응답의 `cur_prc`는 WS 도착 전 초기 현재가로만 사용(이후 WS 우선). 장 외에는 WS off·마지막 종가 유지(첫 슬라이스 장상태 규칙 계승).

## 관심종목 한도 정책 (수치 하드의존 금지)

Premise #3(~40슬롯 한도, 2차 출처 🟡)은 미검증이므로 `Policy.maxWatchlistCount` 단일 상수로 분리한다(현재 값 20). 키 발급 후 실측으로 한도가 달라지면 이 상수 한 줄만 수정 → 정책 재조정. 비즈니스 로직·뷰는 상수를 참조할 뿐 숫자를 박지 않는다.

## 장 상태 판별

`MarketClock`이 `Date`(+ KST 타임존)를 입력받아 장전/장중/장마감을 반환. 정규장 09:00–15:30 KST, 주말·공휴일은 장마감. 공휴일은 상수 테이블(연 1회 갱신)로 시작 — 동적 캘린더 API 연동은 v1 범위 밖. 경계값(개장 직전/직후, 마감 직후)은 단위 테스트로 잠근다.

## 보안

- appkey/secret/access token은 macOS Keychain(`kSecClassGenericPassword`)에만 저장. 메모리 외 평문 흔적 없음.
- `.gitignore`로 자격증명·빌드 산출물 제외(이미 처리).
- App Transport Security: 키움 도메인 HTTPS/WSS 전용.

## 미해결 / sprint 전 사용자 액션

- **Premise #1 (🔴 최대 리스크)**: 표준 키움 키로 별도 신청·요금 없이 WebSocket 체결 수신 가능 여부 미확인. 거짓이면 본 WS 설계의 핵심이 막힘 → **키 발급 직후 최소 PoC(WS 연결 + 단일 종목 체결 1건 수신)로 실측** 후 sprint 진입 권장. 완화 방향은 design.md §기술 설계 위험 요소 참조.
- Premise #2(모의환경 실시간 수신), #3(슬롯 한도), #6(토큰 24h 재발급)은 2차 출처 🟡 — 동일 PoC에서 함께 검증.
