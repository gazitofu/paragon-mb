import XCTest
@testable import PMCore

/// Q-secret 보조: Keychain upsert/get/delete 라운드트립. 임시 서비스명 사용 — 실 KIS 키 비건드림.
/// (Xcode 테스트 호스트에서 로그인 Keychain 접근. 실 자격증명 `kr.co.koreainvestment.paragon.*`은 절대 미사용.)
final class KeychainStoreTests: XCTestCase {

    private let store = KeychainStore()
    private var service: String!

    override func setUp() {
        super.setUp()
        service = "kr.co.paragon.keychain-test-\(UUID().uuidString)"
    }

    override func tearDown() {
        try? store.delete(service: service)
        super.tearDown()
    }

    func testSetThenGet() throws {
        try store.set(service: service, value: "secret-123")
        XCTAssertEqual(try store.get(service: service), "secret-123")
    }

    func testGetMissingReturnsNil() throws {
        XCTAssertNil(try store.get(service: service))
    }

    func testUpsertUpdatesInPlace() throws {
        try store.set(service: service, value: "v1")
        try store.set(service: service, value: "v2")
        XCTAssertEqual(try store.get(service: service), "v2")
    }

    func testDeleteRemoves() throws {
        try store.set(service: service, value: "x")
        try store.delete(service: service)
        XCTAssertNil(try store.get(service: service))
    }

    func testDeleteMissingIsIdempotent() {
        XCTAssertNoThrow(try store.delete(service: service))
    }
}
