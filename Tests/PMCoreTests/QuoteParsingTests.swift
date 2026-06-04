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

// MARK: - KISQuoteParser 재잠금 (V-C1 + V-C2 — KIS 실측 2026-06-04 기준)

/// Units & Signs Audit 게이트 (tasks.md §V-C2).
/// WS H0STCNT0 실측: 건수 011 → 46×11=506필드, 005930 `005930^092341^356000^5^-4500^-1.25^…`
/// 경계 규칙 ④: signed 직접 파싱 — abs 금지, sign 필드 부호 재구성 금지.
final class KISQuoteParserTests: XCTestCase {

    // MARK: - V-C1: parseSignedInt/Double 유틸

    /// [Audit row 1] parseSignedInt — 콤마·부호 prefix 견고 처리.
    func testParseSignedInt_Formats() {
        XCTAssertEqual(KISQuoteParser.parseSignedInt("-4500"),   -4_500)
        XCTAssertEqual(KISQuoteParser.parseSignedInt("+3000"),    3_000)
        XCTAssertEqual(KISQuoteParser.parseSignedInt("356000"), 356_000)
        XCTAssertEqual(KISQuoteParser.parseSignedInt("356,000"), 356_000)  // 콤마 제거
        XCTAssertEqual(KISQuoteParser.parseSignedInt("0"),           0)
        XCTAssertNil(KISQuoteParser.parseSignedInt("abc"))
    }

    func testParseSignedDouble_Formats() {
        XCTAssertEqual(KISQuoteParser.parseSignedDouble("-1.25") ?? 0, -1.25, accuracy: 1e-9)
        XCTAssertEqual(KISQuoteParser.parseSignedDouble("+3.67") ?? 0,  3.67, accuracy: 1e-9)
        XCTAssertEqual(KISQuoteParser.parseSignedDouble("0.00")  ?? 0,  0.00, accuracy: 1e-9)
        XCTAssertNil(KISQuoteParser.parseSignedDouble("nope"))
    }

    // MARK: - V-C1: parseRecord 단일 레코드

    /// [Audit row 1·2·4·5] 005930 실측값 — 46필드 배열(나머지는 빈 문자열 패딩).
    func testParseRecord_PoC_005930() {
        var fields = Array(repeating: "", count: 46)
        fields[0] = "005930"; fields[1] = "092341"; fields[2] = "356000"
        fields[3] = "5";      fields[4] = "-4500";  fields[5] = "-1.25"
        let r = KISQuoteParser.parseRecord(fields)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.code, "005930")
        // [Audit row 1] 현재가: 원 정수, 부호 없음(항상 양수)
        XCTAssertEqual(r?.quote.price, 356_000)
        // [Audit row 2] 전일대비: signed 직접 — abs 금지
        XCTAssertEqual(r?.quote.change, -4_500)
        // [Audit row 5] previousClose = price - change = 356000 - (-4500) = 360500
        XCTAssertEqual(r?.quote.previousClose, 360_500)
        XCTAssertEqual(r?.quote.direction, .down)
    }

    /// [Audit row 3] 등락률: signed 직접. Quote.changeRate = -4500/360500 ≈ -1.248%.
    func testParseRecord_ChangeRate_SignedDirect() {
        var fields = Array(repeating: "", count: 46)
        fields[0] = "005930"; fields[2] = "356000"; fields[3] = "5"; fields[4] = "-4500"; fields[5] = "-1.25"
        let r = KISQuoteParser.parseRecord(fields)
        // changeRate는 Quote가 price/previousClose에서 파생: -4500/360500
        XCTAssertEqual(r?.quote.changeRate ?? 0, -1.2482, accuracy: 0.001)
    }

    /// [Audit row 2] 상승 케이스: change 양수 직접 보존.
    func testParseRecord_UpSign_ChangePositive() {
        var fields = Array(repeating: "", count: 46)
        fields[0] = "005930"; fields[2] = "363500"; fields[3] = "2"; fields[4] = "3000"; fields[5] = "0.83"
        let r = KISQuoteParser.parseRecord(fields)
        XCTAssertEqual(r?.quote.price, 363_500)
        XCTAssertEqual(r?.quote.change,   3_000)
        XCTAssertEqual(r?.quote.previousClose, 360_500)
        XCTAssertEqual(r?.quote.direction, .up)
    }

    /// [Audit row 4] sign 필드 검증용 — 모순 시 signed 채택.
    /// 시나리오: sign=2(상승 주장)지만 change=-4500(하락) → signed -4500 채택.
    func testParseRecord_SignContradiction_SignedWins() {
        var fields = Array(repeating: "", count: 46)
        fields[0] = "005930"; fields[2] = "356000"
        fields[3] = "2"      // sign=2(상승) — 모순
        fields[4] = "-4500"  // signed 하락 — 이쪽 채택
        fields[5] = "-1.25"
        let r = KISQuoteParser.parseRecord(fields)
        XCTAssertEqual(r?.quote.change, -4_500, "sign 모순 시 signed 값 채택")
        XCTAssertEqual(r?.quote.direction, .down)
    }

    /// 보합(change=0) 케이스.
    func testParseRecord_Flat() {
        var fields = Array(repeating: "", count: 46)
        fields[0] = "000660"; fields[2] = "70000"; fields[3] = "3"; fields[4] = "0"; fields[5] = "0.00"
        let r = KISQuoteParser.parseRecord(fields)
        XCTAssertEqual(r?.quote.change, 0)
        XCTAssertEqual(r?.quote.direction, .flat)
    }

    /// 필드 부족 → nil.
    func testParseRecord_TooFewFields_ReturnsNil() {
        XCTAssertNil(KISQuoteParser.parseRecord(["005930", "092341", "356000", "5"]))
    }

    /// 현재가 파싱 실패 → nil.
    func testParseRecord_BadPrice_ReturnsNil() {
        var fields = Array(repeating: "", count: 46)
        fields[0] = "005930"; fields[2] = "abc"; fields[3] = "5"; fields[4] = "-4500"; fields[5] = "-1.25"
        XCTAssertNil(KISQuoteParser.parseRecord(fields))
    }

    // MARK: - V-C1: parseExecutionChunked — 멀티 레코드 청킹

    /// [V-C1 핵심] 건수 011 → 46×11=506필드 청킹 단언 (실측: API_SPEC.md §멀티 레코드 번들).
    func testParseExecutionChunked_Count11_Produces11Records() {
        // 11레코드 모두 005930 실측값으로 구성. 각 레코드는 동일 데이터(청킹 경계 검증 목적).
        var singleRecord = Array(repeating: "0", count: 46)
        singleRecord[0] = "005930"; singleRecord[1] = "092341"; singleRecord[2] = "356000"
        singleRecord[3] = "5";      singleRecord[4] = "-4500";  singleRecord[5] = "-1.25"
        let body = (0..<11).map { _ in singleRecord.joined(separator: "^") }.joined(separator: "^")
        let results = KISQuoteParser.parseExecutionChunked(body: body, count: 11)
        XCTAssertEqual(results.count, 11, "건수 011 → 11레코드 청킹")
        for r in results {
            XCTAssertEqual(r.code, "005930")
            XCTAssertEqual(r.quote.price, 356_000)
            XCTAssertEqual(r.quote.change, -4_500)
            XCTAssertEqual(r.quote.previousClose, 360_500)
        }
    }

    /// [V-C1 핵심] 멀티 레코드(건수≥2) — 2번째 레코드 청킹 경계 오프셋 정확성.
    func testParseExecutionChunked_MultiRecord_SecondRecordCorrect() {
        // 레코드1: 005930 하락 / 레코드2: 000660 상승 → 2번째 틱 청킹 경계 검증
        var rec1 = Array(repeating: "0", count: 46)
        rec1[0] = "005930"; rec1[2] = "356000"; rec1[3] = "5"; rec1[4] = "-4500"; rec1[5] = "-1.25"
        var rec2 = Array(repeating: "0", count: 46)
        rec2[0] = "000660"; rec2[2] = "73700";  rec2[3] = "2"; rec2[4] = "650";   rec2[5] = "0.89"
        let body = (rec1 + rec2).joined(separator: "^")
        let results = KISQuoteParser.parseExecutionChunked(body: body, count: 2)
        XCTAssertEqual(results.count, 2)
        // 첫 번째 레코드
        XCTAssertEqual(results[0].code, "005930")
        XCTAssertEqual(results[0].quote.price, 356_000)
        XCTAssertEqual(results[0].quote.change, -4_500)
        // 두 번째 레코드 — 청킹 경계 오프셋 정확성 핵심 단언
        XCTAssertEqual(results[1].code, "000660")
        XCTAssertEqual(results[1].quote.price, 73_700)
        XCTAssertEqual(results[1].quote.change, 650)
        XCTAssertEqual(results[1].quote.previousClose, 73_050)  // 73700 - 650
        XCTAssertEqual(results[1].quote.direction, .up)
    }

    /// 건수=0 → 빈 배열.
    func testParseExecutionChunked_ZeroCount_Empty() {
        let results = KISQuoteParser.parseExecutionChunked(body: "005930^092341^356000^5^-4500^-1.25", count: 0)
        XCTAssertEqual(results.count, 0)
    }

    /// 필드 수 부족(46×N 미만) → 빈 배열(크래시 없음).
    func testParseExecutionChunked_InsufficientFields_ReturnsEmpty() {
        // count=2 요구인데 46필드만 있음 → 빈 배열
        var fields = Array(repeating: "0", count: 46)
        fields[0] = "005930"; fields[2] = "356000"; fields[3] = "5"; fields[4] = "-4500"; fields[5] = "-1.25"
        let body = fields.joined(separator: "^")
        let results = KISQuoteParser.parseExecutionChunked(body: body, count: 2)
        XCTAssertEqual(results.count, 0, "필드 부족 → empty, not crash")
    }

    // MARK: - V-C2: parsePrice (FHKST01010100)

    /// [Audit row 6] parsePrice — stck_sdpr 우선, prdy_vrss signed 직접.
    func testParsePrice_WithSdpr_005930() {
        let json: [String: Any] = [
            "stck_prpr": "356000",
            "prdy_vrss": "-4500",
            "prdy_vrss_sign": "5",
            "stck_sdpr": "360500",
        ]
        let q = KISQuoteParser.parsePrice(json)
        XCTAssertEqual(q?.price, 356_000)
        XCTAssertEqual(q?.previousClose, 360_500, "stck_sdpr 우선")
        XCTAssertEqual(q?.change, -4_500)
        XCTAssertEqual(q?.direction, .down)
    }

    /// stck_sdpr 없음 → price - prdy_vrss 역산.
    func testParsePrice_NoSdpr_FallsBackToChange() {
        let json: [String: Any] = ["stck_prpr": "356000", "prdy_vrss": "-4500"]
        let q = KISQuoteParser.parsePrice(json)
        XCTAssertEqual(q?.previousClose, 360_500, "356000-(-4500)=360500 역산")
    }

    /// stck_prpr 누락 → nil.
    func testParsePrice_MissingPrice_ReturnsNil() {
        XCTAssertNil(KISQuoteParser.parsePrice(["prdy_vrss": "-4500"]))
    }

    // MARK: - V-C2: parseStockInfo (CTPF1002R)

    /// [Audit row 7] parseStockInfo — prdt_abrv_name trailing 공백 trim.
    func testParseStockInfo_TrailingSpaceTrimmed() {
        let json: [String: Any] = [
            "pdno": "005930",
            "prdt_abrv_name": "삼성전자   ",
            "stck_prpr": "356000",
            "stck_sdpr": "360500",
        ]
        let r = KISQuoteParser.parseStockInfo(json)
        XCTAssertEqual(r?.symbol.name, "삼성전자")
        XCTAssertEqual(r?.symbol.code, "005930")
    }

    /// prdt_abrv_name 공백만 → nil.
    func testParseStockInfo_WhitespaceOnlyName_ReturnsNil() {
        let json: [String: Any] = ["pdno": "005930", "prdt_abrv_name": "   ", "stck_prpr": "356000", "stck_sdpr": "360500"]
        XCTAssertNil(KISQuoteParser.parseStockInfo(json))
    }
}
