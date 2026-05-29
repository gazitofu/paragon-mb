import XCTest
@testable import PMCore

/// T-store-corrupt: load/save 라운드트립·순서 보존·손상/부재 폴백(K4·M2 loading 행).
final class WatchlistStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pmcore-store-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func store() -> WatchlistStore {
        WatchlistStore(fileURL: tempDir.appendingPathComponent("watchlist.json"))
    }

    func testSaveLoadRoundTripPreservesOrder() throws {
        let s = store()
        let symbols = [
            Symbol(code: "005930", name: "삼성전자"),
            Symbol(code: "000660", name: "SK하이닉스"),
            Symbol(code: "035720", name: "카카오"),
        ]
        try s.save(symbols)
        XCTAssertEqual(s.load(), symbols)            // 순서 보존
    }

    func testLoadMissingFileReturnsEmpty() {
        XCTAssertEqual(store().load(), [])           // 파일 부재 → 빈 목록
    }

    func testLoadCorruptFileReturnsEmpty() throws {
        let s = store()
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("{ not valid json ]".utf8).write(to: s.fileURL)
        XCTAssertEqual(s.load(), [])                 // 손상 → 빈 목록 폴백(크래시 금지)
    }

    func testSaveCreatesIntermediateDirectory() throws {
        let nested = tempDir.appendingPathComponent("a/b/c/watchlist.json")
        let s = WatchlistStore(fileURL: nested)
        try s.save([Symbol(code: "005930", name: "삼성전자")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }

    func testSaveEmptyThenLoad() throws {
        let s = store()
        try s.save([])
        XCTAssertEqual(s.load(), [])
    }

    func testOverwriteReplacesPrevious() throws {
        let s = store()
        try s.save([Symbol(code: "005930", name: "삼성전자")])
        try s.save([Symbol(code: "000660", name: "SK하이닉스")])
        XCTAssertEqual(s.load(), [Symbol(code: "000660", name: "SK하이닉스")])
    }
}
