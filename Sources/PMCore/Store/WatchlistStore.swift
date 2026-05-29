import Foundation

/// 관심종목 JSON 영속(K4 — 종목 목록만 영속, 시세 비영속).
/// atomic write(임시 파일 → rename) + 손상/부재 시 빈 목록 폴백(크래시 금지).
/// 스키마 SSOT: docs/DB_SCHEMA.md §관심종목 영속 (version 1).
public struct WatchlistStore {
    public enum StoreError: Error { case encodeFailed, writeFailed }

    /// 디스크 표현. `version`은 향후 마이그레이션 키.
    private struct Payload: Codable {
        var version: Int
        var symbols: [Symbol]
    }
    public static let schemaVersion = 1

    public let fileURL: URL

    /// 기본 경로: ~/Library/Application Support/PARAGON-MB/watchlist.json.
    /// 테스트는 임시 경로를 주입한다.
    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PARAGON-MB", isDirectory: true)
            self.fileURL = base.appendingPathComponent("watchlist.json")
        }
    }

    /// 종목 목록 로드. 파일 부재 또는 디코딩 실패(손상) 시 빈 목록 반환 — 크래시 금지.
    public func load() -> [Symbol] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(Payload.self, from: data)
        else { return [] }
        return decoded.symbols
    }

    /// 종목 목록 저장. 상위 디렉터리 생성 후 atomic write.
    /// 한도(`Policy.maxWatchlistCount`)·중복 검사는 도메인 로직 책임 — Store는 받은 목록을 그대로 영속.
    public func save(_ symbols: [Symbol]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let payload = Payload(version: Self.schemaVersion, symbols: symbols)
        guard let data = try? JSONEncoder().encode(payload) else { throw StoreError.encodeFailed }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw StoreError.writeFailed
        }
    }
}
