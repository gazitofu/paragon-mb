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

    // MARK: - 내부 상태
    private var streamTask: Task<Void, Never>?
    private var marketTimer: Timer?
    private var lastPolledStatus: MarketStatus?    // 전환 감지 기준(불변식: 동일 상태 반복 호출 금지)

    init(store: WatchlistStore,
         service: QuoteServicing,
         marketClock: MarketClock = MarketClock(),
         symbolLookup: @escaping @Sendable (String) async throws -> Symbol) {
        self.store = store
        self.service = service
        self.marketClock = marketClock
        self.symbolLookup = symbolLookup
    }

    deinit {
        marketTimer?.invalidate()
        streamTask?.cancel()
    }

    // MARK: - 섹션 1: 초기 로드 · Store 연동 · V1/V2 라우팅 (M2 empty/loading)

    /// P0 진입점(Phase D 뷰 onAppear/첫 팝오버 열림에서 호출). 저장 0건=V1, 1+건=V2 로딩.
    func start() {
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
            if state == .loading { state = .normal }             // 스켈레톤→정상
        case let .marketStatus(status):
            marketStatus = status
            lastPolledStatus = status
        case let .connection(connected):
            if connected {
                if state == .wsDisconnected { state = .normal }  // 재연결 → 경고 제거
            } else if state == .normal {
                state = .wsDisconnected                          // 끊김 → 경고(마지막값 유지)
            }
        case let .error(err):
            switch err {
            case .authFailed: state = .authFailed                // 앱 재시작 안내 배너(Q15)
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

    /// 네트워크 배너 "다시 시도"(V13) — 캐시값 유지한 채 초기 로드 재시도.
    func retry() {
        guard !symbols.isEmpty else { return }
        loadFailed = false
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
