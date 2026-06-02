import Foundation
import Combine
import PMCore

/// V2 목록 화면 상태의 단일 소유자(M2) + 장 상태 폴링·KRX 전환 구동(M3, 옵션 C).
/// 행 뷰(child)는 `Quote`·`PriceDirection`만 받아 렌더하고 네트워크/토큰 상태를 모른다(경계 계약).
/// `token-refreshing`는 deferred(D-token-refresh-indicator) — 투명 재발급이라 구동 이벤트 없음.
@MainActor
final class WatchlistViewModel: ObservableObject {

    /// 화면 상태(M2 단일 소유). V1=empty / V2=loading·normal·wsDisconnected·authFailed.
    enum ScreenState: Equatable {
        case empty
        case loading
        case normal
        case wsDisconnected
        case authFailed
    }

    // MARK: - Published
    @Published private(set) var state: ScreenState = .loading
    @Published private(set) var isRefreshing = false          // refresh 진행 직교 플래그(ScreenState와 독립)
    @Published private(set) var symbols: [Symbol] = []
    @Published private(set) var quotes: [String: Quote] = [:]
    @Published private(set) var marketStatus: MarketStatus = .closed
    @Published private(set) var lastUpdated: Date?            // 헤더 "마지막 갱신 시각"(체결 도착 시점)
    @Published private(set) var loadFailed = false            // 초기 REST 전체 실패 배너(M2) — 캐시값 유지
    @Published private(set) var addViewModel: AddSymbolViewModel?  // non-nil = V3 표시
    @Published private(set) var undoToast: UndoToast?         // non-nil = 삭제 토스트 표시(M2 remove 행)

    /// 삭제 직후 "삭제됨 · 되돌리기" 토스트의 복원 컨텍스트. id로 뷰의 자동 소멸 타이머를 키.
    struct UndoToast: Equatable, Identifiable {
        let id = UUID()
        let symbol: Symbol
        let index: Int
    }

    // MARK: - 의존성 (K1 — 추상화만)
    private let store: WatchlistStore
    private let service: QuoteServicing
    private let marketClock: MarketClock
    private let symbolLookup: @Sendable (String) async throws -> Symbol
    private let reachability: NetworkReachability      // OS 네트워크 복구 감지 어댑터(mock 주입 가능)

    // MARK: - 내부 상태
    private var streamTask: Task<Void, Never>?
    private var marketTimer: Timer?
    private var lastPolledStatus: MarketStatus?    // 전환 감지 기준(불변식: 동일 상태 반복 호출 금지)

    init(store: WatchlistStore,
         service: QuoteServicing,
         marketClock: MarketClock = MarketClock(),
         reachability: NetworkReachability = NetworkPathReachability(),
         symbolLookup: @escaping @Sendable (String) async throws -> Symbol) {
        self.store = store
        self.service = service
        self.marketClock = marketClock
        self.reachability = reachability
        self.symbolLookup = symbolLookup
    }

    deinit {
        marketTimer?.invalidate()
        streamTask?.cancel()
        reachability.stop()    // NWPathMonitor 정리 — VM이 생명주기 소유(design.md §③, reviewer 권장①)
    }

    // MARK: - 섹션 1: 초기 로드 · Store 연동 · V1/V2 라우팅 (M2 empty/loading)

    /// P0 진입점(Phase D 뷰 onAppear/첫 팝오버 열림에서 호출). 저장 0건=V1, 1+건=V2 로딩.
    func start() {
        // NWPath 복구 콜백 1회 등록 — unsatisfied→satisfied 전이 시 refresh() 자동 호출(P2)
        reachability.onRecovered { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        reachability.start()
        symbols = store.load()
        guard !symbols.isEmpty else { state = .empty; return }   // V1
        beginPipeline()
    }

    /// 실시간 파이프라인 부트스트랩 — 구독·서비스 start·장 폴링을 한 번에 띄운다.
    /// start(비어있지 않음)과 commitAdd(빈 상태→첫 종목) 양쪽에서 재사용.
    private func beginPipeline() {
        state = .loading                                         // V2 스켈레톤
        let status = marketClock.status(at: Date())
        marketStatus = status
        lastPolledStatus = status
        if streamTask == nil { subscribeUpdates() }
        if marketTimer == nil { startMarketTimer() }
        let codes = symbols.map(\.code)
        Task { await service.start(codes: codes) }               // 장중이면 WS, 장 외면 REST 초기값만
    }

    // MARK: - 섹션 2: WS 스트림 구독 · 갱신 (M2 normal/ws-disconnected)

    private func subscribeUpdates() {
        streamTask?.cancel()
        let stream = service.updates                             // nonisolated let — 동기 접근
        streamTask = Task { [weak self] in                       // @MainActor 상속(생성 컨텍스트)
            for await update in stream {
                self?.apply(update)
            }
        }
    }

    private func apply(_ update: QuoteUpdate) {
        switch update {
        case let .quote(code, quote):
            quotes[code] = quote
            lastUpdated = Date()
            loadFailed = false
            isRefreshing = false
            // 복귀 조건 확장 — authFailed/wsDisconnected에서 refresh 후 quote 도착 시에도 .normal 복귀(design.md §②)
            if state == .loading || state == .authFailed || state == .wsDisconnected { state = .normal }
        case let .marketStatus(status):
            marketStatus = status
            lastPolledStatus = status
        case let .connection(connected):
            if connected {
                // wsDisconnected 직접 복귀 또는 refresh 선리셋(.loading)으로 진입한 경로 양쪽 처리(design.md 매트릭스 행5)
                if state == .wsDisconnected || (isRefreshing && state == .loading) { state = .normal }
                isRefreshing = false    // .connection(true) = 재구독 성공 → 스피너 해제(행5 기대 UI)
            } else if state == .normal {
                state = .wsDisconnected                          // 끊김 → 경고(마지막값 유지)
            }
        case let .error(err):
            isRefreshing = false    // 에러 경로에서 스피너 무한 회전 방지(design.md §② R2)
            switch err {
            case .authFailed: state = .authFailed                // 재실패 시 배너 재노출(T-VM3)
            case .loadFailed: loadFailed = true                  // 배너 + 캐시값 유지(빈 화면 금지)
            }
        }
    }

    // MARK: - 섹션 3: 삭제 · 추가 네비게이션 (M2 remove/nav)

    /// "+ 종목 추가" → V3. 현재 코드 set·count를 child에 주입(M1 경계).
    func presentAddSymbol() {
        addViewModel = AddSymbolViewModel(
            existing: symbols,
            lookup: symbolLookup,
            onRegister: { [weak self] symbol in self?.commitAdd(symbol) },
            onCancel: { [weak self] in self?.dismissAddSymbol() }
        )
    }

    func dismissAddSymbol() {
        addViewModel = nil
    }

    private func commitAdd(_ symbol: Symbol) {
        guard !symbols.contains(where: { $0.code == symbol.code }) else { dismissAddSymbol(); return }
        let wasEmpty = symbols.isEmpty
        symbols.append(symbol)
        persist()
        addViewModel = nil
        if wasEmpty {
            beginPipeline()                                      // 빈 상태→첫 종목: 파이프라인 부트스트랩
        } else {
            Task { await service.updateWatchlist(symbols.map(\.code)) }
        }
    }

    /// 행 삭제 — 목록·구독에서 즉시 제거, "삭제됨 · 되돌리기" 토스트 노출, 마지막 항목이면 V1 전환(M2 remove).
    func remove(_ symbol: Symbol) {
        guard let index = symbols.firstIndex(where: { $0.code == symbol.code }) else { return }
        symbols.remove(at: index)
        quotes[symbol.code] = nil
        persist()
        undoToast = UndoToast(symbol: symbol, index: index)
        if symbols.isEmpty {
            state = .empty
            Task { await service.stop() }
        } else {
            Task { await service.updateWatchlist(symbols.map(\.code)) }
        }
    }

    /// 토스트 "되돌리기" — 삭제 위치에 복원, 마지막 항목 복원 시 파이프라인 재기동(M2 remove 행).
    func undoLastDelete() {
        guard let toast = undoToast else { return }
        let wasEmpty = symbols.isEmpty
        symbols.insert(toast.symbol, at: min(toast.index, symbols.count))
        persist()
        undoToast = nil
        if wasEmpty {
            beginPipeline()
        } else {
            Task { await service.updateWatchlist(symbols.map(\.code)) }
        }
    }

    func dismissUndoToast() {
        undoToast = nil
    }

    /// 전(全)상태 복구 액션 — P1 수동 버튼·P2 NWPath 자동 복구·배너 "다시 시도" 공유 단일 진입점.
    /// retry()를 흡수(design.md §⑤, 게이트 Q2). authFailed 포함 어떤 상태에서도 파이프라인 재트리거.
    func refresh() {
        guard !isRefreshing else { return }     // 중복 호출 가드 — service.start 1회 초과 금지(T-VM9)
        guard !symbols.isEmpty else { return }  // V1(EmptyState)에서 무동작(이슈3 결정=숨김과 정합)
        isRefreshing = true
        // state 선리셋 — authFailed/wsDisconnected에서 apply(.quote) 복귀 조건이 .loading 경유로 확실히 동작
        // .normal은 건드리지 않음(정상 중 새로고침 시 캐시 화면 유지 — 수용 기준 5번)
        if state != .normal { state = .loading }
        loadFailed = false                      // 네트워크 배너 제거(기존 retry() 동작 계승)
        Task { await service.start(codes: symbols.map(\.code)) }
    }

    private func persist() {
        try? store.save(symbols)   // 쓰기 실패는 폴백(크래시 금지) — Store 계약(손상 시 빈 목록)
    }

    // MARK: - 섹션 3': 장 상태 폴링 · KRX 전환 구동 (M3 / 옵션 C, KRX-only)

    private func startMarketTimer() {
        marketTimer?.invalidate()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollMarketStatus() }
        }
        RunLoop.main.add(timer, forMode: .common)              // 메뉴 트래킹 중에도 발화
        marketTimer = timer
    }

    private func pollMarketStatus() {
        let now = marketClock.status(at: Date())
        guard now != lastPolledStatus else { return }
        let was = lastPolledStatus
        lastPolledStatus = now
        marketStatus = now                                     // 헤더 라벨·불투명도(M3 시각)
        let codes = symbols.map(\.code)
        guard !codes.isEmpty else { return }
        if now.isLive && !(was?.isLive ?? false) {
            Task { await service.start(codes: codes) }         // 장 외 → 장중
        } else if !now.isLive && (was?.isLive ?? false) {
            Task { await service.stop() }                      // 장중 → 장 외
        }
    }
}
