import XCTest
import PMCore
@testable import PARAGON_MB

/// 알파뉴메릭 티커 입력 검증 (ops/2026-06-05-alphanumeric-ticker-input.md).
/// sanitize(뷰 필터 공용)와 submit 선검사(2차 차단)가 KRX 영숫자 6자리 코드(예: 0009K0)를
/// 수용하면서 기존 숫자 6자리 동작을 회귀 없이 유지하는지 잠근다.
@MainActor
final class AddSymbolViewModelTests: XCTestCase {

    // MARK: - 헬퍼

    private func makeViewModel(
        existing: [Symbol] = [],
        onRegister: @escaping (Symbol) -> Void = { _ in },
        lookup: @escaping @Sendable (String) async throws -> Symbol = { Symbol(code: $0, name: "이름") }
    ) -> AddSymbolViewModel {
        AddSymbolViewModel(existing: existing, lookup: lookup, onRegister: onRegister, onCancel: {})
    }

    private func errorMessage(_ vm: AddSymbolViewModel) -> String? {
        if case let .error(msg) = vm.phase { return msg }
        return nil
    }

    // MARK: - sanitize (뷰 onChange 필터)

    func testSanitizeKeepsAlphanumericAndUppercases() {
        XCTAssertEqual(AddSymbolViewModel.sanitize("0009k0"), "0009K0")
        XCTAssertEqual(AddSymbolViewModel.sanitize("0009K0"), "0009K0")
        XCTAssertEqual(AddSymbolViewModel.sanitize("005930"), "005930")
    }

    func testSanitizeStripsNonASCIIAlphanumeric() {
        XCTAssertEqual(AddSymbolViewModel.sanitize("00-09 K0"), "0009K0")   // 구분자 제거
        XCTAssertEqual(AddSymbolViewModel.sanitize("가0009K0"), "0009K0")    // 한글 제거
        XCTAssertEqual(AddSymbolViewModel.sanitize("０００９Ｋ０"), "")        // 전각 영숫자 거부(비ASCII)
    }

    func testSanitizeTruncatesToSixBeforeUppercasing() {
        XCTAssertEqual(AddSymbolViewModel.sanitize("0009k0123"), "0009K0")
    }

    // MARK: - submit 형식 선검사 (2차 차단)

    func testAlphanumericSixCharCodeRegisters() async {
        let exp = expectation(description: "onRegister")
        var registered: Symbol?
        let vm = makeViewModel(onRegister: { registered = $0; exp.fulfill() })
        vm.codeInput = "0009K0"
        vm.submit()
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(registered?.code, "0009K0")
    }

    func testLowercaseInputIsUppercasedBeforeLookup() async {
        // 뷰 필터를 거치지 않은 직접 주입(2차 차단 단독)에서도 대문자 정규화 보장.
        let exp = expectation(description: "onRegister")
        var registered: Symbol?
        let vm = makeViewModel(onRegister: { registered = $0; exp.fulfill() })
        vm.codeInput = "0009k0"
        vm.submit()
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(registered?.code, "0009K0")
    }

    func testNumericSixDigitStillRegisters() async {
        // 기존 숫자 6자리 회귀 가드.
        let exp = expectation(description: "onRegister")
        var registered: Symbol?
        let vm = makeViewModel(onRegister: { registered = $0; exp.fulfill() })
        vm.codeInput = "005930"
        vm.submit()
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(registered?.code, "005930")
    }

    func testNonASCIICodeRejectedSynchronously() {
        let vm = makeViewModel()
        vm.codeInput = "０００９Ｋ０"   // 전각 — isNumber/isLetter true지만 비ASCII
        vm.submit()
        XCTAssertEqual(errorMessage(vm), "등록할 수 없는 종목코드입니다")
    }

    func testWrongLengthCodeRejected() {
        let vm = makeViewModel()
        vm.codeInput = "0009K"        // 5자리
        vm.submit()
        XCTAssertEqual(errorMessage(vm), "등록할 수 없는 종목코드입니다")
    }

    // MARK: - 중복 선검사 (대문자 정규화 후 비교)

    func testDuplicateCheckMatchesCaseInsensitively() {
        let vm = makeViewModel(existing: [Symbol(code: "0009K0", name: "에임드바이오")])
        vm.codeInput = "0009k0"
        vm.submit()
        XCTAssertEqual(errorMessage(vm), "이미 등록된 종목입니다")
    }
}
