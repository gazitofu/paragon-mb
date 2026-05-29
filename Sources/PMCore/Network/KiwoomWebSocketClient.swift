import Foundation

/// 키움 체결 구독 WS 클라이언트(K7 — 종목코드 set 구독 단순 계약, 슬롯 예산 추상화 없음).
/// URLSessionWebSocketTask 래핑 + LOGIN/REG/PING/REAL(PoC 검증 흐름) + 지수 백오프 재연결.
/// 라이브 동작은 PoC(tools/kiwoom-ws-poc.swift)가 입증. 파싱은 KiwoomQuoteParser(잠금) 위임.
/// ⚠️ 미검증: REG refresh 의미·구독 해제(REMOVE) 정확 동작 — 제거 시 재REG로 대체(재연결 시 정합). 추후 calibration.
public actor KiwoomWebSocketClient {

    public enum Event: Sendable {
        case connected
        case disconnected
        case quote(code: String, quote: Quote)
    }

    public typealias TokenProvider = @Sendable () async throws -> String

    private let environment: KiwoomEnvironment
    private let session: URLSession
    private let tokenProvider: TokenProvider

    private var task: URLSessionWebSocketTask?
    private var receiver: Task<Void, Never>?
    private var subscribed: Set<String> = []
    private var running = false
    private var reconnectAttempt = 0

    public let events: AsyncStream<Event>
    private let emit: AsyncStream<Event>.Continuation

    public init(environment: KiwoomEnvironment,
                session: URLSession = .shared,
                tokenProvider: @escaping TokenProvider) {
        self.environment = environment
        self.session = session
        self.tokenProvider = tokenProvider
        var cont: AsyncStream<Event>.Continuation!
        self.events = AsyncStream<Event> { cont = $0 }   // makeStream은 macOS14+ → 클로저 패턴(13 호환)
        self.emit = cont
    }

    public func connect(codes: Set<String> = []) {
        running = true
        subscribed = codes
        Task { await self.open() }
    }

    /// 활성 구독 집합 교체. REG로 반영(K7 단순 계약).
    public func setSubscriptions(_ codes: Set<String>) {
        subscribed = codes
        Task { await self.sendREG() }
    }

    public func disconnect() {
        running = false
        receiver?.cancel(); receiver = nil
        task?.cancel(with: .goingAway, reason: nil); task = nil
    }

    // MARK: - internal

    private func open() async {
        guard running else { return }
        do {
            let token = try await tokenProvider()
            let t = session.webSocketTask(with: environment.webSocketURL)
            task = t
            t.resume()
            startReceiver()
            try await send(["trnm": "LOGIN", "token": token])
        } catch {
            await scheduleReconnect()
        }
    }

    private func startReceiver() {
        receiver = Task { [weak self] in
            guard let self else { return }
            while await self.running, let t = await self.task {
                do {
                    let message = try await t.receive()
                    await self.handle(message)
                } catch {
                    await self.handleDisconnect()
                    break
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) async {
        let text: String
        switch message {
        case .string(let s): text = s
        case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
        @unknown default: return
        }
        guard let json = decode(text), let trnm = json["trnm"] as? String else { return }
        switch trnm {
        case "LOGIN":
            if (json["return_code"] as? Int) == 0 {
                reconnectAttempt = 0
                emit.yield(.connected)
                await sendREG()
            } else {
                await handleDisconnect()
            }
        case "PING":
            try? await send(raw: text)        // keep-alive echo
        case "REAL":
            emitReal(json)
        default:
            break
        }
    }

    private func emitReal(_ json: [String: Any]) {
        guard let arr = json["data"] as? [[String: Any]] else { return }
        for d in arr where (d["type"] as? String) == "0B" {
            guard let item = d["item"] as? String,
                  let values = d["values"] as? [String: String],
                  let parsed = KiwoomQuoteParser.parseRealtimeExecution(item: item, values: values)
            else { continue }
            emit.yield(.quote(code: parsed.code, quote: parsed.quote))
        }
    }

    private func sendREG() async {
        guard !subscribed.isEmpty else { return }
        try? await send([
            "trnm": "REG", "grp_no": "1", "refresh": "1",
            "data": [["item": Array(subscribed), "type": ["0B"]]],
        ])
    }

    private func handleDisconnect() async {
        emit.yield(.disconnected)
        task = nil
        await scheduleReconnect()
    }

    private func scheduleReconnect() async {
        guard running else { return }
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)   // 2,4,8,16,30…초 상한
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await open()
    }

    private func send(_ obj: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: obj)
        try await send(raw: String(data: data, encoding: .utf8) ?? "")
    }

    private func send(raw: String) async throws {
        guard let task else { return }
        try await task.send(.string(raw))
    }

    private func decode(_ text: String) -> [String: Any]? {
        guard let d = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }
}
