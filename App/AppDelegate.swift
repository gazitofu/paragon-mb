import AppKit
import PMCore

/// AppKit 셸 생명주기 연결점(K9) + 조립 루트(K1).
/// `applicationDidFinishLaunching`에서 의존성 그래프를 구성하고 메뉴바 셸을 띄운다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(viewModel: Self.makeWatchlistViewModel())
    }

    /// 조립 루트 — Keychain KIS 자격증명 → REST/Token → approvalKeyProvider → QuoteService → Store → WatchlistViewModel.
    /// 실시간 시작(`viewModel.start()`)은 패널 첫 열림 시 호출(여기선 그래프만 구성).
    @MainActor
    private static func makeWatchlistViewModel() -> WatchlistViewModel {
        let rest = KISRESTClient()

        // Keychain KIS 자격증명 — env 직접 읽기 금지(V-B2 게이트, Floor 4).
        let keychain = KeychainStore()
        let appKey    = (try? keychain.get(service: KISCredential.appKey))    ?? nil
        let appSecret = (try? keychain.get(service: KISCredential.appSecret)) ?? nil

        let tokenManager = TokenManager(fetcher: {
            guard let appKey, let appSecret else { throw KISRESTClient.RESTError.missingToken }
            return try await rest.issueToken(appKey: appKey, appSecret: appSecret)
        })

        // approval_key 발급 클로저 — WS connect마다 1회 호출(KIS 호출마다 새 키, 별도 제한 미관측).
        let approvalKeyProvider: KISWebSocketClient.ApprovalKeyProvider = {
            guard let appKey, let appSecret else { throw KISRESTClient.RESTError.missingToken }
            return try await rest.issueApprovalKey(appKey: appKey, appSecret: appSecret)
        }

        let service = QuoteService(
            rest: rest,
            tokenManager: tokenManager,
            approvalKeyProvider: approvalKeyProvider,
            appKey: appKey ?? "",
            appSecret: appSecret ?? ""
        )

        // M1 경계: child는 REST/token을 모름 — 조립 루트가 RESTError를 SymbolLookupError로 매핑해 주입.
        let symbolLookup: @Sendable (String) async throws -> Symbol = { code in
            do {
                let token = try await tokenManager.validToken()
                return try await rest.lookupName(code: code, token: token, appKey: appKey ?? "", appSecret: appSecret ?? "")
            } catch let error as KISRESTClient.RESTError {
                if case .lookupFailed = error { throw SymbolLookupError.invalidCode }
                if case .apiError = error     { throw SymbolLookupError.invalidCode }
                throw SymbolLookupError.network
            } catch {
                throw SymbolLookupError.network
            }
        }

        return WatchlistViewModel(store: WatchlistStore(), service: service, symbolLookup: symbolLookup)
    }
}
