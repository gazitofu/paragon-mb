import XCTest
@testable import PMCore

/// T-parse + Units & Signs Audit(PASS 게이트 — Sprint Execution Rules).
/// WS 0B 실측 페이로드(PoC 2026-05-29, 005930) 기준으로 부호·스케일 잠금.
final class QuoteParsingTests: XCTestCase {

    /// 실측 PoC 첫 REAL 0B values 일부(005930). FID 10 현재가 / 11 전일대비 / 12 등락률.
    private let pocValues: [String: String] = [
        "20": "095257", "10": "+310500", "11": "+11000", "12": "+3.67",
        "16": "+309500", "17": "+319000", "18": "+308000", "13": "8766800",
    ]

    func testParseRealExecution_PoC_005930() {
        let r = KiwoomQuoteParser.parseRealtimeExecution(item: "005930", values: pocValues)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.code, "005930")
        XCTAssertEqual(r?.quote.price, 310_500)           // abs(FID10), 원값(스케일 없음 — 사용자 확인)
        XCTAssertEqual(r?.quote.change, 11_000)           // = FID11
        XCTAssertEqual(r?.quote.previousClose, 299_500)   // price − change
        XCTAssertEqual(r?.quote.direction, .up)
        XCTAssertEqual(r?.quote.changeRate ?? 0, 3.6728, accuracy: 0.0001)  // ≈ FID12(3.67)
    }

    func testParseDownSignPreserved() {
        // 하락: FID10 부호=방향(가격은 abs), FID11 음수 보존 → previousClose 역산.
        let r = KiwoomQuoteParser.parseRealtimeExecution(item: "000660", values: ["10": "-73700", "11": "-650"])
        XCTAssertEqual(r?.quote.price, 73_700)
        XCTAssertEqual(r?.quote.change, -650)
        XCTAssertEqual(r?.quote.previousClose, 74_350)
        XCTAssertEqual(r?.quote.direction, .down)
    }

    func testParseFlat() {
        let r = KiwoomQuoteParser.parseRealtimeExecution(item: "005930", values: ["10": "50000", "11": "0"])
        XCTAssertEqual(r?.quote.change, 0)
        XCTAssertEqual(r?.quote.direction, .flat)
    }

    func testSignedIntFormats() {
        XCTAssertEqual(KiwoomQuoteParser.parseSignedInt("+310500"), 310_500)
        XCTAssertEqual(KiwoomQuoteParser.parseSignedInt("-650"), -650)
        XCTAssertEqual(KiwoomQuoteParser.parseSignedInt("310500"), 310_500)
        XCTAssertEqual(KiwoomQuoteParser.parseSignedInt("+1,500"), 1_500)   // 콤마 제거
        XCTAssertNil(KiwoomQuoteParser.parseSignedInt("abc"))
    }

    func testMissingRequiredFieldReturnsNil() {
        XCTAssertNil(KiwoomQuoteParser.parseRealtimeExecution(item: "x", values: ["10": "+100"]))  // FID11 없음
        XCTAssertNil(KiwoomQuoteParser.parseRealtimeExecution(item: "x", values: ["11": "+100"]))  // FID10 없음
    }

    // 토큰 만료 파싱(KST yyyyMMddHHmmss).
    func testParseExpiry_PoCFormat() {
        let date = KiwoomRESTClient.parseExpiry("20260530095257")
        XCTAssertNotNil(date)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        XCTAssertEqual(c.year, 2026); XCTAssertEqual(c.month, 5); XCTAssertEqual(c.day, 30)
        XCTAssertEqual(c.hour, 9); XCTAssertEqual(c.minute, 52); XCTAssertEqual(c.second, 57)
    }

    func testParseExpiry_InvalidReturnsNil() {
        XCTAssertNil(KiwoomRESTClient.parseExpiry(nil))
        XCTAssertNil(KiwoomRESTClient.parseExpiry(""))
        XCTAssertNil(KiwoomRESTClient.parseExpiry("not-a-date"))
    }

    // REST ka10001 종목조회 — 실측 PoC 응답(2026-05-29, 005930) 기준 잠금.
    func testParseStockInfo_PoC_005930() {
        let json: [String: Any] = [
            "stk_cd": "005930", "stk_nm": "삼성전자",
            "cur_prc": "+311000", "base_pric": "299500",
            "pred_pre": "+11500", "flu_rt": "+3.84", "return_code": 0,
        ]
        let r = KiwoomQuoteParser.parseStockInfo(json)
        XCTAssertEqual(r?.symbol, Symbol(code: "005930", name: "삼성전자"))
        XCTAssertEqual(r?.quote.price, 311_000)            // abs(cur_prc), 원값
        XCTAssertEqual(r?.quote.previousClose, 299_500)    // base_pric(기준가)
        XCTAssertEqual(r?.quote.change, 11_500)            // = pred_pre
        XCTAssertEqual(r?.quote.direction, .up)
        XCTAssertEqual(r?.quote.changeRate ?? 0, 3.8397, accuracy: 0.001)  // ≈ flu_rt 3.84
    }

    func testParseStockInfoMissingNameReturnsNil() {
        XCTAssertNil(KiwoomQuoteParser.parseStockInfo(["stk_cd": "005930", "cur_prc": "+1", "base_pric": "1"]))
    }
}
