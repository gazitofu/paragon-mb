import AppKit
import PMCore

/// AppKit 셸 생명주기 연결점(K9) + 조립 루트(K1).
/// `applicationDidFinishLaunching`에서 의존성 그래프를 구성하고 메뉴바 셸을 띄운다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(viewModel: Self.makeWatchlistViewModel())
    }

    /// 조립 루트 — Keychain 자격증명 → REST/Token → QuoteService → Store → WatchlistViewModel.
    /// 실시간 시작(`viewModel.start()`)은 Phase D에서 패널 첫 열림 시 호출(여기선 그래프만 구성).
    @MainActor
    private static func makeWatchlistViewModel() -> WatchlistViewModel {
        let environment = KiwoomEnvironment.real          // 모의 전환은 v2(KiwoomEnvironment.mock)
        let rest = KiwoomRESTClient(environment: environment)

        let keychain = KeychainStore()
        let appKey = (try? keychain.get(service: KiwoomCredential.appKey)) ?? nil
        let appSecret = (try? keychain.get(service: KiwoomCredential.appSecret)) ?? nil

        let tokenManager = TokenManager(fetcher: {
            guard let appKey, let appSecret else { throw KiwoomRESTClient.RESTError.missingToken }
            return try await rest.issueToken(appKey: appKey, secret: appSecret)
        })

        let service = QuoteService(environment: environment, rest: rest, tokenManager: tokenManager)

        // M1 경계: child는 REST/token을 모름 — 조립 루트가 RESTError를 SymbolLookupError로 매핑해 주입.
        let symbolLookup: @Sendable (String) async throws -> Symbol = { code in
            do {
                let token = try await tokenManager.validToken()
                return try await rest.lookup(code: code, token: token).symbol
            } catch let error as KiwoomRESTClient.RESTError {
                if case .lookupFailed = error { throw SymbolLookupError.invalidCode }
                throw SymbolLookupError.network
            } catch {
                throw SymbolLookupError.network
            }
        }

        return WatchlistViewModel(store: WatchlistStore(), service: service, symbolLookup: symbolLookup)
    }
}
