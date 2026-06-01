import Foundation
import Network

// === SECTION: PROTOCOL ===

/// OS 네트워크 경로 복구 감지 계약. VM은 이 protocol만 알고 NWPathMonitor를 직접 모른다.
/// 복구 = unsatisfied → satisfied 전이 엣지에서만 onRecovered 콜백 발화.
/// 앱 시작 직후 최초 satisfied는 발화하지 않음 (서비스 파이프라인이 이미 기동 중이므로 중복 refresh 방지).
public protocol NetworkReachability: Sendable {
    /// unsatisfied → satisfied 복구 전이 시 1회 호출.
    /// 최초 satisfied(앱 시작 직후)는 발화하지 않음.
    func onRecovered(_ handler: @escaping @Sendable () -> Void)
    func start()
    func stop()
}

// === SECTION: IMPL ===

/// NWPathMonitor 래핑 어댑터. transition-edge(unsatisfied→satisfied)만 onRecovered 발화.
public final class NetworkPathReachability: NetworkReachability, @unchecked Sendable {

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    // lock으로 보호하는 가변 상태
    private let lock = NSLock()
    private var _handler: (@Sendable () -> Void)?
    private var _lastStatus: NWPath.Status?    // nil = 아직 관측 전

    public init(queue: DispatchQueue = DispatchQueue(label: "com.paragon-mb.network-reachability")) {
        self.monitor = NWPathMonitor()
        self.queue = queue
    }

    public func onRecovered(_ handler: @escaping @Sendable () -> Void) {
        lock.withLock { _handler = handler }
    }

    public func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        monitor.cancel()
    }

    // === SECTION: TRANSITION ===

    private func handlePathUpdate(_ path: NWPath) {
        handleStatusUpdate(path.status)
    }

    /// 테스트에서 NWPath.Status를 직접 주입할 수 있도록 분리된 진입점.
    /// @testable import PMCore 로 접근.
    func handleStatusUpdate(_ current: NWPath.Status) {
        let (handler, shouldFire) = lock.withLock { () -> ((@Sendable () -> Void)?, Bool) in
            let previous = _lastStatus
            _lastStatus = current

            // 최초 관측(previous == nil)은 앱 기동 시점 — 발화 금지(R1 최초 satisfied 오발화 방지).
            // previous가 .unsatisfied(또는 .requiresConnection)이고 current가 .satisfied일 때만 복구 엣지.
            let isRecovery: Bool
            if let prev = previous {
                isRecovery = (prev != .satisfied) && (current == .satisfied)
            } else {
                isRecovery = false
            }

            return (_handler, isRecovery)
        }

        if shouldFire {
            handler?()
        }
    }
}
