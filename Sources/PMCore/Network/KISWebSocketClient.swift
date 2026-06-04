import Foundation

/// KIS 실시간 체결 구독 WS 클라이언트.
/// URLSessionWebSocketTask 래핑 + approval envelope(H0STCNT0) + PINGPONG echo + 지수 백오프 재연결.
/// 라이브 동작은 PoC(tools/kis-ws-poc.swift)가 입증. 파싱은 KISQuoteParser 위임(경계 규칙 ②③).
/// ⚠️ approval_key 발급 로직은 이 타입 외부(approvalKeyProvider 주입) — 조립 루트(AppDelegate)가 담당.
public actor KISWebSocketClient {

    // === SECTION: EVENT_ENUM ===

    /// QuoteService 계약 경계 — Event 시그니처 KiwoomWebSocketClient와 불변(QuoteService.handle 무영향).
    public enum Event: Sendable {
        case connected
        case disconnected
        case quote(code: String, quote: Quote)
    }

    /// approval_key 발급 클로저. connect마다 1회 호출(캐시 불요 — KIS 호출마다 새 키 발급, 별도 제한 미관측).
    public typealias ApprovalKeyProvider = @Sendable () async throws -> String

    // === SECTION: STATE_FIELDS ===

    private let session: URLSession
    private let approvalKeyProvider: ApprovalKeyProvider

    private var task: URLSessionWebSocketTask?
    private var receiver: Task<Void, Never>?
    private var subscribed: Set<String> = []
    private var running = false
    private var reconnectAttempt = 0

    public let events: AsyncStream<Event>
    private let emit: AsyncStream<Event>.Continuation

    // === SECTION: INIT ===

    public init(session: URLSession = .shared,
                approvalKeyProvider: @escaping ApprovalKeyProvider) {
        self.session = session
        self.approvalKeyProvider = approvalKeyProvider
        var cont: AsyncStream<Event>.Continuation!
        // makeStream은 macOS 14+ — 클로저 패턴으로 macOS 13 호환(KiwoomWebSocketClient 계승)
        self.events = AsyncStream<Event> { cont = $0 }
        self.emit = cont
    }

    // === SECTION: CONNECTION ===

    public func connect(codes: Set<String> = []) {
        running = true
        subscribed = codes
        Task { await self.open() }
    }

    /// 활성 구독 집합 교체. 추가분 subscribe·제거분 unsubscribe envelope 전송.
    public func setSubscriptions(_ codes: Set<String>) {
        let added = codes.subtracting(subscribed)
        let removed = subscribed.subtracting(codes)
        subscribed = codes
        if !added.isEmpty   { Task { await self.sendSubscribe(codes: added,   trType: "1") } }
        if !removed.isEmpty { Task { await self.sendSubscribe(codes: removed, trType: "2") } }
    }

    public func disconnect() {
        running = false
        receiver?.cancel(); receiver = nil
        task?.cancel(with: .goingAway, reason: nil); task = nil
    }

    // MARK: - Internal connection

    private func open() async {
        guard running else { return }
        do {
            let approvalKey = try await approvalKeyProvider()
            // ⚠️ 평문 ws — Info.plist ATS 예외(ops.koreainvestment.com) 필요(T9).
            let t = session.webSocketTask(with: KISEnvironment.webSocketURL)
            task = t
            t.resume()
            startReceiver()
            // connect 직후 구독 종목이 있으면 즉시 envelope 송신.
            if !subscribed.isEmpty {
                try await sendSubscribeEnvelope(approvalKey: approvalKey, codes: subscribed, trType: "1")
            }
            // SUBSCRIBE SUCCESS는 수신 루프에서 .connected emit.
        } catch {
            await scheduleReconnect()
        }
    }

    private func sendSubscribeEnvelope(approvalKey: String, codes: Set<String>, trType: String) async throws {
        for code in codes {
            let envelope: [String: Any] = [
                "header": [
                    "approval_key": approvalKey,
                    "custtype": "P",
                    "tr_type": trType,          // "1"=구독 "2"=해지
                    "content-type": "utf-8",
                ],
                "body": ["input": ["tr_id": "H0STCNT0", "tr_key": code]],
            ]
            try await sendJSON(envelope)
        }
    }

    /// 재연결 후 approval_key 없이 보내는 단순 subscribe(approval_key 없이 이미 열린 task 재사용 불가 — 재open 시에만 호출).
    private func sendSubscribe(codes: Set<String>, trType: String) async {
        // setSubscriptions는 열린 연결에서만 의미 있음. task가 없으면 무시(재연결 시 open에서 재구독).
        guard task != nil else { return }
        do {
            let approvalKey = try await approvalKeyProvider()
            try await sendSubscribeEnvelope(approvalKey: approvalKey, codes: codes, trType: trType)
        } catch {
            // approval_key 발급 실패 시 재연결 흐름 대기(keep-alive 실패 → handleDisconnect).
        }
    }

    private func scheduleReconnect() async {
        guard running else { return }
        reconnectAttempt += 1
        // 키움 백오프 패턴 계승: 2·4·8·16·30초 상한
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await open()
    }

    private func handleDisconnect() async {
        emit.yield(.disconnected)
        task = nil
        await scheduleReconnect()
    }

    // === SECTION: RECEIVER ===

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

        if text.hasPrefix("{") {
            // JSON 제어 응답(구독 확인 / PINGPONG)
            await handleJSON(text)
        } else {
            // raw 체결 프레임: `암호화flag|tr_id|건수|본문`
            await handleRaw(text)
        }
    }

    private func handleJSON(_ text: String) async {
        guard let json = decodeJSON(text),
              let header = json["header"] as? [String: Any],
              let trID = header["tr_id"] as? String
        else { return }

        switch trID {
        case "PINGPONG":
            // keep-alive: 동일 메시지 echo 회신(미회신 시 서버 절단 추정)
            try? await sendRaw(text)

        case "H0STCNT0":
            // 구독 응답 — SUBSCRIBE SUCCESS 시 .connected emit + reconnectAttempt 리셋
            let body = json["body"] as? [String: Any]
            let rt = (body?["rt_cd"] as? String) ?? ""
            if rt == "0" {
                reconnectAttempt = 0
                emit.yield(.connected)
            }

        default:
            break
        }
    }

    private func handleRaw(_ text: String) async {
        // raw 형식: `암호화flag|tr_id|건수|본문` (실측 API_SPEC.md §H0STCNT0)
        let parts = text.components(separatedBy: "|")
        guard parts.count >= 4 else { return }
        // parts[0]=flag(0=평문) parts[1]=tr_id parts[2]=건수 parts[3]=본문
        guard parts[1] == "H0STCNT0" else { return }
        guard let count = Int(parts[2].trimmingCharacters(in: .whitespaces)), count > 0 else { return }
        let body = parts[3]

        // 파싱 위임: KISQuoteParser.parseExecutionChunked(경계 규칙 ②③)
        let records = KISQuoteParser.parseExecutionChunked(body: body, count: count)
        // 길이 불일치(46 배수 아님) 시 KISQuoteParser가 빈 배열 반환 — 해당 메시지 drop.
        for record in records {
            emit.yield(.quote(code: record.code, quote: record.quote))
        }
    }

    // MARK: - Send helpers

    private func sendJSON(_ obj: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: obj)
        guard let text = String(data: data, encoding: .utf8) else { return }
        try await sendRaw(text)
    }

    private func sendRaw(_ text: String) async throws {
        guard let task else { return }
        try await task.send(.string(text))
    }

    private func decodeJSON(_ text: String) -> [String: Any]? {
        guard let d = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }
}
