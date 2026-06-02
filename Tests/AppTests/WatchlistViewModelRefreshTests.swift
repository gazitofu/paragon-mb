import XCTest
import PMCore
@testable import PARAGON_MB

// === SECTION: MOCKS ===

/// mock NetworkReachability — onRecovered 콜백을 보관했다가 테스트가 수동 발화.
final class MockNetworkReachability: NetworkReachability, @unchecked Sendable {
    private(set) var handler: (@Sendable () -> Void)?
    private(set) var startCalled = false
    private(set) var stopCalled = false

    func onRecovered(_ handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }
    func start() { startCalled = true }
    func stop()  { stopCalled  = true }

    /// 테스트가 네트워크 복구를 수동 발화하는 헬퍼.
    func fireRecovered() { handler?() }
}

/// mock QuoteServicing — start(codes:) 호출 횟수·인자 기록 + continuation으로 이벤트 주입.
/// emit/resetCallCount 는 nonisolated — continuation.yield는 thread-safe하고,
/// startCallCount는 @MainActor テスト から await アクセスするため actor 境界を越える.
actor MockQuoteService: QuoteServicing {
    let updates: AsyncStream<QuoteUpdate>
    // nonisolated 접근을 위해 continuation을 별도 래퍼로 보관
    private let _cont: UncheckedSendableCont

    private(set) var startCallCount = 0
    private(set) var lastStartCodes: [String] = []

    init() {
        var c: AsyncStream<QuoteUpdate>.Continuation!
        updates = AsyncStream<QuoteUpdate> { c = $0 }
        _cont = UncheckedSendableCont(cont: c)
    }

    func start(codes: [String]) async {
        startCallCount += 1
        lastStartCodes = codes
    }

    func updateWatchlist(_ codes: [String]) async {}
    func stop() async {}

    /// actor 격리 없이 호출 가능 — continuation.yield는 thread-safe.
    nonisolated func emit(_ update: QuoteUpdate) {
        _cont.yield(update)
    }

    /// 카운트 초기화 — beginPipeline()의 첫 start 호출을 제외하고 refresh()만 세기 위해 사용.
    func resetCallCount() {
        startCallCount = 0
        lastStartCodes = []
    }
}

/// AsyncStream.Continuation을 nonisolated 컨텍스트에서 안전하게 보관하기 위한 래퍼.
/// Continuation.yield는 thread-safe(@unchecked Sendable 정당화).
private final class UncheckedSendableCont: @unchecked Sendable {
    private let cont: AsyncStream<QuoteUpdate>.Continuation
    init(cont: AsyncStream<QuoteUpdate>.Continuation) { self.cont = cont }
    func yield(_ value: QuoteUpdate) { cont.yield(value) }
}

// === SECTION: HELPERS ===

/// 테스트 전용 WatchlistStore — 임시 파일 경로에 미리 symbols를 저장.
private func makeStore(symbols: [Symbol]) throws -> WatchlistStore {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-watchlist-\(UUID().uuidString).json")
    let store = WatchlistStore(fileURL: url)
    try store.save(symbols)
    return store
}

private let sampleSymbols = [
    Symbol(code: "005930", name: "삼성전자"),
    Symbol(code: "000660", name: "SK하이닉스")
]

private let sampleQuote = Quote(price: 70000, previousClose: 69650)

/// VM의 streamTask가 이벤트를 처리하도록 실행 루프를 충분히 양보.
/// Task.yield()×20 + 짧은 sleep으로 MainActor 큐의 async 이벤트 처리를 보장.
private func drainTasks() async {
    for _ in 0..<20 { await Task.yield() }
    try? await Task.sleep(nanoseconds: 5_000_000) // 5ms — stream 소비 Task hop 대기
    for _ in 0..<10 { await Task.yield() }
}

// === SECTION: TEST CLASS ===

@MainActor
final class WatchlistViewModelRefreshTests: XCTestCase {

    // MARK: - V1 (T-VM1): authFailed → refresh() → state==.loading && isRefreshing==true

    func testV1_authFailedThenRefresh_setsLoadingAndIsRefreshing() async throws {
        let store = try makeStore(symbols: sampleSymbols)
        let service = MockQuoteService()
        let reachability = MockNetworkReachability()
        let vm = WatchlistViewModel(store: store, service: service,
                                    reachability: reachability,
                                    symbolLookup: { _ in sampleSymbols[0] })
        vm.start()
        await drainTasks()

        // authFailed 상태 주입
        await service.emit(.error(.authFailed))
        await drainTasks()
        XCTAssertEqual(vm.state, .authFailed)

        // refresh() 호출
        await service.resetCallCount()
        vm.refresh()

        XCTAssertEqual(vm.state, .loading,      "T-VM1: refresh 후 state==.loading")
        XCTAssertTrue(vm.isRefreshing,          "T-VM1: refresh 후 isRefreshing==true")
    }

    // MARK: - V2 (T-VM2): authFailed → refresh → .quote apply → state==.normal && !isRefreshing

    func testV2_afterRefresh_quoteApply_returnsNormal() async throws {
        let store = try makeStore(symbols: sampleSymbols)
        let service = MockQuoteService()
        let reachability = MockNetworkReachability()
        let vm = WatchlistViewModel(store: store, service: service,
                                    reachability: reachability,
                                    symbolLookup: { _ in sampleSymbols[0] })
        vm.start()
        await drainTasks()

        await service.emit(.error(.authFailed))
        await drainTasks()

        vm.refresh()
        await service.emit(.quote(code: "005930", quote: sampleQuote))
        await drainTasks()

        XCTAssertEqual(vm.state, .normal,       "T-VM2: quote 도착 후 state==.normal")
        XCTAssertFalse(vm.isRefreshing,         "T-VM2: quote 도착 후 isRefreshing==false")
    }

    // MARK: - V3 (T-VM3): refresh 후 .error(.authFailed) → state==.authFailed && !isRefreshing (무한회전 방지)

    func testV3_afterRefresh_errorAuthFailed_resetsIsRefreshing() async throws {
        let store = try makeStore(symbols: sampleSymbols)
        let service = MockQuoteService()
        let reachability = MockNetworkReachability()
        let vm = WatchlistViewModel(store: store, service: service,
                                    reachability: reachability,
                                    symbolLookup: { _ in sampleSymbols[0] })
        vm.start()
        await drainTasks()

        await service.emit(.error(.authFailed))
        await drainTasks()

        vm.refresh()
        XCTAssertTrue(vm.isRefreshing, "전제: refresh 직후 isRefreshing true")

        await service.emit(.error(.authFailed))
        await drainTasks()

        XCTAssertEqual(vm.state, .authFailed,   "T-VM3: error 후 state==.authFailed")
        XCTAssertFalse(vm.isRefreshing,         "T-VM3: error 후 isRefreshing==false (무한회전 방지 R2)")
    }

    // MARK: - V4 (T-VM4): wsDisconnected → refresh → state==.loading

    func testV4_wsDisconnectedThenRefresh_setsLoading() async throws {
        let store = try makeStore(symbols: sampleSymbols)
        let service = MockQuoteService()
        let reachability = MockNetworkReachability()
        let vm = WatchlistViewModel(store: store, service: service,
                                    reachability: reachability,
                                    symbolLookup: { _ in sampleSymbols[0] })
        vm.start()
        await drainTasks()

        // normal → wsDisconnected
        await service.emit(.quote(code: "005930", quote: sampleQuote))
        await drainTasks()
        await service.emit(.connection(false))
        await drainTasks()
        XCTAssertEqual(vm.state, .wsDisconnected, "전제: wsDisconnected 진입")

        vm.refresh()

        XCTAssertEqual(vm.state, .loading,      "T-VM4: refresh 후 state==.loading")
        XCTAssertTrue(vm.isRefreshing,          "T-VM4: refresh 후 isRefreshing==true")
    }

    // MARK: - ★V4 (T-VM5): wsDisconnected → refresh → .connection(true) 단독 → state==.normal && !isRefreshing

    func testV5_connectionTrueAlone_closesRefreshingSpinner() async throws {
        let store = try makeStore(symbols: sampleSymbols)
        let service = MockQuoteService()
        let reachability = MockNetworkReachability()
        let vm = WatchlistViewModel(store: store, service: service,
                                    reachability: reachability,
                                    symbolLookup: { _ in sampleSymbols[0] })
        vm.start()
        await drainTasks()

        // wsDisconnected 진입
        await service.emit(.quote(code: "005930", quote: sampleQuote))
        await drainTasks()
        await service.emit(.connection(false))
        await drainTasks()

        vm.refresh()  // state=.loading, isRefreshing=true
        XCTAssertEqual(vm.state, .loading)
        XCTAssertTrue(vm.isRefreshing)

        // quote 없이 .connection(true) 단독 수신 — 행5 단독 복귀 경로
        await service.emit(.connection(true))
        await drainTasks()

        XCTAssertEqual(vm.state, .normal,       "T-VM5: connection(true) 단독으로 state==.normal")
        XCTAssertFalse(vm.isRefreshing,         "T-VM5: connection(true) 단독으로 isRefreshing==false (quote 미도착)")
    }

    // MARK: - V5 (T-VM6): loadFailed → refresh() → loadFailed==false & quotes 불변

    func testV6_loadFailedRetry_clearsBannerAndPreservesCache() async throws {
        let store = try makeStore(symbols: sampleSymbols)
        let service = MockQuoteService()
        let reachability = MockNetworkReachability()
        let vm = WatchlistViewModel(store: store, service: service,
                                    reachability: reachability,
                                    symbolLookup: { _ in sampleSymbols[0] })
        vm.start()
        await drainTasks()

        // 캐시 데이터 먼저 채우기
        await service.emit(.quote(code: "005930", quote: sampleQuote))
        await drainTasks()
        let cachedQuotes = vm.quotes

        // loadFailed 배너 노출
        await service.emit(.error(.loadFailed))
        await drainTasks()
        XCTAssertTrue(vm.loadFailed, "전제: loadFailed==true")

        // 배너 "다시 시도" = refresh() 호출
        vm.refresh()
        await drainTasks()

        XCTAssertFalse(vm.loadFailed,           "T-VM6: refresh 후 loadFailed==false")
        XCTAssertEqual(vm.quotes, cachedQuotes, "T-VM6: 캐시 quotes 불변 (빈 화면 금지)")
    }

    // MARK: - V6 (T-VM7): normal → refresh → state==.normal && quotes 불변

    func testV7_normalRefresh_stateUnchangedAndCachePreserved() async throws {
        let store = try makeStore(symbols: sampleSymbols)
        let service = MockQuoteService()
        let reachability = MockNetworkReachability()
        let vm = WatchlistViewModel(store: store, service: service,
                                    reachability: reachability,
                                    symbolLookup: { _ in sampleSymbols[0] })
        vm.start()
        await drainTasks()

        await service.emit(.quote(code: "005930", quote: sampleQuote))
        await drainTasks()
        XCTAssertEqual(vm.state, .normal, "전제: normal 진입")
        let cachedQuotes = vm.quotes

        vm.refresh()
        await drainTasks()

        XCTAssertEqual(vm.state, .normal,       "T-VM7: normal 유지 (선리셋 안 함)")
        XCTAssertEqual(vm.quotes, cachedQuotes, "T-VM7: quotes 불변 (스켈레톤 전환 없음)")
    }

    // MARK: - V7 (T-VM8): loading → refresh → 깨지지 않고 isRefreshing set

    func testV8_loadingStateRefresh_setsIsRefreshingSafely() async throws {
        let store = try makeStore(symbols: sampleSymbols)
        let service = MockQuoteService()
        let reachability = MockNetworkReachability()
        let vm = WatchlistViewModel(store: store, service: service,
                                    reachability: reachability,
                                    symbolLookup: { _ in sampleSymbols[0] })
        vm.start()
        await drainTasks()
        // start() 직후는 .loading 상태 (quote 미수신)
        XCTAssertEqual(vm.state, .loading, "전제: loading 상태")

        vm.refresh()

        XCTAssertTrue(vm.isRefreshing,          "T-VM8: loading에서 refresh 후 isRefreshing set")
        // state는 .loading에서 선리셋(.loading→.loading)이므로 .loading 유지
        XCTAssertEqual(vm.state, .loading,      "T-VM8: state 유지 (크래시 없음)")
    }

    // MARK: - V8 (T-VM9): 연속 refresh()×3 → service.start 호출 count==1 (중복 가드)

    func testV9_tripleRefresh_serviceStartCalledOnce() async throws {
        let store = try makeStore(symbols: sampleSymbols)
        let service = MockQuoteService()
        let reachability = MockNetworkReachability()
        let vm = WatchlistViewModel(store: store, service: service,
                                    reachability: reachability,
                                    symbolLookup: { _ in sampleSymbols[0] })
        vm.start()
        await drainTasks()

        // beginPipeline()의 첫 start를 제외하기 위해 카운트 초기화
        await service.resetCallCount()

        vm.refresh()
        vm.refresh()
        vm.refresh()
        await drainTasks()

        let count = await service.startCallCount
        XCTAssertEqual(count, 1,                "T-VM9: 연속 refresh×3 → service.start 1회 (중복 가드)")
    }

    // MARK: - V9 (T-VM10): symbols 0건 → refresh() → service.start 미호출

    func testV10_emptySymbols_refreshDoesNotTriggerServiceStart() async throws {
        // symbols 0건 store — start()에서 state=.empty, beginPipeline 미호출
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-empty-\(UUID().uuidString).json")
        let store = WatchlistStore(fileURL: url)
        // 저장하지 않음 → load()는 빈 목록 반환
        let service = MockQuoteService()
        let reachability = MockNetworkReachability()
        let vm = WatchlistViewModel(store: store, service: service,
                                    reachability: reachability,
                                    symbolLookup: { _ in sampleSymbols[0] })
        vm.start()
        await drainTasks()

        XCTAssertEqual(vm.state, .empty, "전제: symbols 0건 → empty 상태")
        await service.resetCallCount()

        vm.refresh()
        await drainTasks()

        let count = await service.startCallCount
        XCTAssertEqual(count, 0,                "T-VM10: symbols 0건 → service.start 미호출 (guard !symbols.isEmpty)")
    }
}
