import Foundation

/// ViewModel이 구독하는 시세 갱신 이벤트(K3 — REST/WS 출처 무관 단일 채널).
public enum QuoteUpdate: Sendable {
    case quote(code: String, quote: Quote)   // 시세 갱신(REST 초기값 또는 WS 체결)
    case marketStatus(MarketStatus)          // 장 상태(장전/장중/장마감)
    case connection(Bool)                    // WS 연결(true) / 끊김(false)
    case error(ServiceError)

    public enum ServiceError: Sendable {
        case authFailed    // 토큰 발급/재발급 실패 → 앱 재시작 안내(M2 auth-failed)
        case loadFailed    // 초기 시세 로드 실패(네트워크/미존재 코드)(M2 network 배너)
    }
}

/// 시세 오케스트레이션 계약(K1 — ViewModel은 본 프로토콜만 안다).
public protocol QuoteServicing: Sendable {
    var updates: AsyncStream<QuoteUpdate> { get }
    func start(codes: [String]) async
    func updateWatchlist(_ codes: [String]) async
    func stop() async
}

/// REST 초기값 + WS 갱신 통합(K3). 장 상태(MarketClock)에 따라 WS 구독 on/off.
/// 라이브 오케스트레이션은 Xcode/실연동에서 검증 — 구성요소(parser·REST·WS·clock·token)는 개별 검증됨.
public actor QuoteService: QuoteServicing {

    private let rest: KISRESTClient
    private let tokenManager: TokenManager
    private let marketClock: MarketClock
    private let ws: KISWebSocketClient
    private let appKey: String
    private let appSecret: String

    private var codes: [String] = []
    private var wsTask: Task<Void, Never>?

    public let updates: AsyncStream<QuoteUpdate>
    private let emit: AsyncStream<QuoteUpdate>.Continuation

    // MARK: - 골격 (DI)

    /// approvalKeyProvider: KISWebSocketClient에 주입 (connect마다 발급, 캐시 불요).
    /// appKey/appSecret: lookupPrice FHKST01010100 헤더 전달용 (KISRESTClient 계약).
    public init(rest: KISRESTClient,
                tokenManager: TokenManager,
                approvalKeyProvider: @escaping KISWebSocketClient.ApprovalKeyProvider,
                appKey: String,
                appSecret: String,
                marketClock: MarketClock = MarketClock(),
                session: URLSession = .shared) {
        self.rest = rest
        self.tokenManager = tokenManager
        self.marketClock = marketClock
        self.appKey = appKey
        self.appSecret = appSecret
        self.ws = KISWebSocketClient(session: session, approvalKeyProvider: approvalKeyProvider)
        var cont: AsyncStream<QuoteUpdate>.Continuation!
        self.updates = AsyncStream<QuoteUpdate> { cont = $0 }
        self.emit = cont
    }

    // MARK: - 섹션 1: start/stop · REST 초기값 · 장 상태별 WS on/off

    public func start(codes: [String]) async {
        self.codes = codes
        let status = marketClock.status(at: Date())
        emit.yield(.marketStatus(status))
        await loadInitial(codes)
        if status.isLive { await beginRealtime(Set(codes)) }   // 장 외에는 WS 미구독(마지막 값 유지)
    }

    public func updateWatchlist(_ newCodes: [String]) async {
        let added = Array(Set(newCodes).subtracting(codes))
        codes = newCodes
        if !added.isEmpty { await loadInitial(added) }
        if marketClock.status(at: Date()).isLive {
            await ws.setSubscriptions(Set(newCodes))
        }
    }

    public func stop() async {
        wsTask?.cancel(); wsTask = nil
        await ws.disconnect()
    }

    /// 종목별 REST 초기 시세 로드. 토큰은 1회 발급(이후 캐시). 토큰 실패=authFailed, 개별 조회 실패=loadFailed.
    private func loadInitial(_ codes: [String]) async {
        guard !codes.isEmpty else { return }
        let token: String
        do { token = try await tokenManager.validToken() }
        catch { emit.yield(.error(.authFailed)); return }
        for code in codes {
            do {
                let quote = try await rest.lookupPrice(code: code, token: token, appKey: appKey, appSecret: appSecret)
                emit.yield(.quote(code: code, quote: quote))
            } catch {
                emit.yield(.error(.loadFailed))
            }
        }
    }

    // MARK: - 섹션 2: WS 구독 · 이벤트 → QuoteUpdate 매핑

    private func beginRealtime(_ codes: Set<String>) async {
        await ws.connect(codes: codes)
        let feed = ws   // actor 참조 캡처(Sendable)
        wsTask = Task { [weak self] in
            for await event in feed.events {
                await self?.handle(event)
            }
        }
    }

    private func handle(_ event: KISWebSocketClient.Event) {
        switch event {
        case .connected: emit.yield(.connection(true))
        case .disconnected: emit.yield(.connection(false))
        case .quote(let code, let quote): emit.yield(.quote(code: code, quote: quote))
        }
    }
}
