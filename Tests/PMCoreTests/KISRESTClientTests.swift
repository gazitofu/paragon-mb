import XCTest
@testable import PMCore

/// Task 2 QA — KISRESTClient 단위 검증.
/// 라이브 호출 없음: URLProtocol stub으로 HTTP 왕복 모의.
/// 검증 축: parseExpiry / 엔드포인트 경로·tr_id / 바디 키명 / 필드명 / 에러 매핑.
final class KISRESTClientTests: XCTestCase {

    // MARK: - Stub infrastructure

    /// URLProtocol stub. URLSession은 httpBody를 httpBodyStream으로 변환하므로
    /// startLoading()에서 스트림을 읽어 bodyData로 전달한다.
    private final class StubProtocol: URLProtocol {
        /// (캡처된 요청, 읽어낸 바디 Data) → (응답 바디, HTTPURLResponse)
        static var handler: ((URLRequest, Data?) throws -> (Data, HTTPURLResponse))?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let handler = StubProtocol.handler else {
                client?.urlProtocol(self, didFailWithError: URLError(.unknown))
                return
            }
            // URLSession은 POST body를 httpBodyStream으로 변환. 직접 읽는다.
            let bodyData: Data? = request.httpBodyStream.flatMap { stream in
                var data = Data()
                stream.open()
                var buf = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let n = stream.read(&buf, maxLength: buf.count)
                    guard n > 0 else { break }
                    data.append(contentsOf: buf.prefix(n))
                }
                stream.close()
                return data.isEmpty ? nil : data
            } ?? request.httpBody
            do {
                let (data, response) = try handler(request, bodyData)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
        override func stopLoading() {}
    }

    private func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: cfg)
    }

    // MARK: - parseExpiry

    /// expires_in(초) 우선 경로 — 86400초 = 24h (API_SPEC.md §인증 실측).
    func testParseExpiry_ExpiresIn_86400() {
        let client = KISRESTClient()
        let before = Date()
        let result = client.parseExpiry(expiresIn: 86400, expiredAt: nil)
        let interval = result.timeIntervalSince(before)
        XCTAssertGreaterThanOrEqual(interval, 86399)
        XCTAssertLessThanOrEqual(interval, 86402)
    }

    /// expiredAt(KST "yyyy-MM-dd HH:mm:ss") 폴백 경로.
    func testParseExpiry_ExpiredAt_KST() {
        let client = KISRESTClient()
        let result = client.parseExpiry(expiresIn: nil, expiredAt: "2026-06-05 09:36:42")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: result)
        XCTAssertEqual(c.year, 2026)
        XCTAssertEqual(c.month, 6)
        XCTAssertEqual(c.day, 5)
        XCTAssertEqual(c.hour, 9)
        XCTAssertEqual(c.minute, 36)
        XCTAssertEqual(c.second, 42)
    }

    /// expires_in=0 → expiredAt 폴백.
    func testParseExpiry_ZeroExpiresIn_FallsBackToExpiredAt() {
        let client = KISRESTClient()
        let result = client.parseExpiry(expiresIn: 0, expiredAt: "2026-06-05 09:36:42")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let c = cal.dateComponents([.year], from: result)
        XCTAssertEqual(c.year, 2026, "expiredAt 폴백이어야 함")
    }

    /// 양쪽 모두 nil → 보수적 23h 폴백.
    func testParseExpiry_BothNil_Returns23hFallback() {
        let client = KISRESTClient()
        let before = Date()
        let result = client.parseExpiry(expiresIn: nil, expiredAt: nil)
        let interval = result.timeIntervalSince(before)
        let expected: TimeInterval = 23 * 3600
        XCTAssertGreaterThanOrEqual(interval, expected - 2)
        XCTAssertLessThanOrEqual(interval, expected + 2)
    }

    /// expiredAt 빈 문자열 → 23h 폴백.
    func testParseExpiry_EmptyExpiredAt_Returns23hFallback() {
        let client = KISRESTClient()
        let before = Date()
        let result = client.parseExpiry(expiresIn: nil, expiredAt: "")
        let interval = result.timeIntervalSince(before)
        let expected: TimeInterval = 23 * 3600
        XCTAssertGreaterThanOrEqual(interval, expected - 2)
        XCTAssertLessThanOrEqual(interval, expected + 2)
    }

    // MARK: - issueToken: 엔드포인트·바디 키명

    /// issueToken → POST /oauth2/tokenP, 바디 key = `appsecret` (Approval `secretkey`와 다름 — 실측).
    func testIssueToken_EndpointAndBodyKey() async throws {
        let session = makeSession()
        var capturedPath: String?
        var capturedMethod: String?
        var capturedBody: Data?

        StubProtocol.handler = { req, bodyData in
            capturedPath = req.url?.path
            capturedMethod = req.httpMethod
            capturedBody = bodyData
            let resp: [String: Any] = ["access_token": "tok_abc", "token_type": "Bearer", "expires_in": 86400]
            return (try! JSONSerialization.data(withJSONObject: resp),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let client = KISRESTClient(session: session)
        let token = try await client.issueToken(appKey: "mykey", appSecret: "mysecret")

        XCTAssertEqual(token.value, "tok_abc")
        XCTAssertEqual(capturedPath, "/oauth2/tokenP", "tokenP 경로 (API_SPEC.md §인증)")
        XCTAssertEqual(capturedMethod, "POST")

        let bodyDict = try XCTUnwrap(capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        })
        XCTAssertEqual(bodyDict["appsecret"] as? String, "mysecret",
                       "`appsecret` 키 필요 (tokenP 전용, API_SPEC.md §인증)")
        XCTAssertNil(bodyDict["secretkey"], "tokenP에는 `secretkey` 미사용")
        XCTAssertEqual(bodyDict["grant_type"] as? String, "client_credentials")
    }

    /// issueToken rt_cd="1" → tokenRejected throw.
    func testIssueToken_RtCdNonZero_ThrowsTokenRejected() async {
        let session = makeSession()
        StubProtocol.handler = { req, _ in
            let body: [String: Any] = ["rt_cd": "1", "msg_cd": "EGW00201", "msg1": "초당 거래건수 초과"]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = KISRESTClient(session: session)
        do {
            _ = try await client.issueToken(appKey: "k", appSecret: "s")
            XCTFail("tokenRejected 미발생")
        } catch KISRESTClient.RESTError.tokenRejected(let msg) {
            XCTAssertEqual(msg, "초당 거래건수 초과")
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    /// issueToken HTTP 401 → http(401) throw.
    func testIssueToken_HTTP401_ThrowsHttp() async {
        let session = makeSession()
        StubProtocol.handler = { req, _ in
            return (Data(),
                    HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!)
        }
        let client = KISRESTClient(session: session)
        do {
            _ = try await client.issueToken(appKey: "k", appSecret: "s")
            XCTFail("http 에러 미발생")
        } catch KISRESTClient.RESTError.http(let code) {
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - issueApprovalKey: 엔드포인트·바디 키명

    /// issueApprovalKey → POST /oauth2/Approval, 바디 key = `secretkey` (tokenP `appsecret`와 다름 — 실측).
    func testIssueApprovalKey_EndpointAndBodyKey() async throws {
        let session = makeSession()
        var capturedPath: String?
        var capturedBody: Data?

        StubProtocol.handler = { req, bodyData in
            capturedPath = req.url?.path
            capturedBody = bodyData
            let resp: [String: Any] = ["approval_key": "ws_approval_key_36chars"]
            return (try! JSONSerialization.data(withJSONObject: resp),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let client = KISRESTClient(session: session)
        let key = try await client.issueApprovalKey(appKey: "mykey", appSecret: "mysecret")

        XCTAssertEqual(key, "ws_approval_key_36chars")
        XCTAssertEqual(capturedPath, "/oauth2/Approval", "Approval 경로 (API_SPEC.md §인증)")

        let bodyDict = try XCTUnwrap(capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        })
        XCTAssertEqual(bodyDict["secretkey"] as? String, "mysecret",
                       "`secretkey` 키 필요 (Approval 전용, API_SPEC.md §인증)")
        XCTAssertNil(bodyDict["appsecret"], "Approval에는 `appsecret` 미사용")
    }

    // MARK: - lookupName: CTPF1002R 경로·tr_id·쿼리·필드명

    /// lookupName → GET /uapi/domestic-stock/v1/quotations/search-stock-info, tr_id=CTPF1002R, PRDT_TYPE_CD=300.
    func testLookupName_EndpointTrIdAndQuery() async throws {
        let session = makeSession()
        var capturedReq: URLRequest?

        StubProtocol.handler = { req, _ in
            capturedReq = req
            let body: [String: Any] = [
                "rt_cd": "0",
                "output": ["prdt_abrv_name": "삼성전자", "pdno": "00000A005930"],
            ]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let client = KISRESTClient(session: session)
        let symbol = try await client.lookupName(code: "005930", token: "tok", appKey: "k", appSecret: "s")

        XCTAssertEqual(symbol.code, "005930")
        XCTAssertEqual(symbol.name, "삼성전자")

        let req = try XCTUnwrap(capturedReq)
        XCTAssertEqual(req.url?.path,
                       "/uapi/domestic-stock/v1/quotations/search-stock-info",
                       "CTPF1002R 경로 (API_SPEC.md §종목명 조회)")
        XCTAssertEqual(req.value(forHTTPHeaderField: "tr_id"), "CTPF1002R")

        let comps = try XCTUnwrap(URLComponents(url: req.url!, resolvingAgainstBaseURL: false))
        let typeCD = comps.queryItems?.first(where: { $0.name == "PRDT_TYPE_CD" })?.value
        XCTAssertEqual(typeCD, "300", "PRDT_TYPE_CD=300 (주식·ETF·ETN·ELW, API_SPEC.md §종목명 조회)")
        let pdno = comps.queryItems?.first(where: { $0.name == "PDNO" })?.value
        XCTAssertEqual(pdno, "005930")
    }

    /// prdt_abrv_name trailing 공백 trim (API_SPEC.md §종목명 조회 — msg1 trim 주의).
    func testLookupName_TrailingSpaceTrimmed() async throws {
        let session = makeSession()
        StubProtocol.handler = { req, _ in
            let body: [String: Any] = [
                "rt_cd": "0",
                "output": ["prdt_abrv_name": "삼성전자   ", "pdno": "00000A005930"],
            ]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = KISRESTClient(session: session)
        let symbol = try await client.lookupName(code: "005930", token: "tok", appKey: "k", appSecret: "s")
        XCTAssertEqual(symbol.name, "삼성전자")
    }

    /// rt_cd≠"0" → apiError throw.
    func testLookupName_RtCdNonZero_ThrowsApiError() async {
        let session = makeSession()
        StubProtocol.handler = { req, _ in
            let body: [String: Any] = ["rt_cd": "1", "msg_cd": "ERR001", "msg1": "종목 없음"]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = KISRESTClient(session: session)
        do {
            _ = try await client.lookupName(code: "999999", token: "tok", appKey: "k", appSecret: "s")
            XCTFail("apiError 미발생")
        } catch KISRESTClient.RESTError.apiError(let code, _) {
            XCTAssertEqual(code, "1")
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    /// prdt_abrv_name 공백만 → lookupFailed throw.
    func testLookupName_EmptyName_ThrowsLookupFailed() async {
        let session = makeSession()
        StubProtocol.handler = { req, _ in
            let body: [String: Any] = [
                "rt_cd": "0",
                "output": ["prdt_abrv_name": "   ", "pdno": "000000000000"],
            ]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = KISRESTClient(session: session)
        do {
            _ = try await client.lookupName(code: "000000", token: "tok", appKey: "k", appSecret: "s")
            XCTFail("lookupFailed 미발생")
        } catch KISRESTClient.RESTError.lookupFailed(_) {
            // 기대
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - lookupPrice: FHKST01010100 경로·tr_id·필드명

    /// lookupPrice → GET /uapi/domestic-stock/v1/quotations/inquire-price, tr_id=FHKST01010100.
    /// 실측값 기반: stck_prpr=363500, stck_sdpr=360500 (005930, 2026-06-04).
    func testLookupPrice_EndpointTrIdAndFields() async throws {
        let session = makeSession()
        var capturedReq: URLRequest?

        StubProtocol.handler = { req, _ in
            capturedReq = req
            let body: [String: Any] = [
                "rt_cd": "0",
                "output": [
                    "stck_prpr": "363500",
                    "prdy_vrss": "3000",
                    "prdy_vrss_sign": "2",
                    "prdy_ctrt": "0.83",
                    "stck_sdpr": "360500",
                    "stck_shrn_iscd": "005930",
                ],
            ]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let client = KISRESTClient(session: session)
        let quote = try await client.lookupPrice(code: "005930", token: "tok", appKey: "k", appSecret: "s")

        XCTAssertEqual(quote.price, 363_500)
        XCTAssertEqual(quote.previousClose, 360_500, "stck_sdpr = 기준가(전일종가)")

        let req = try XCTUnwrap(capturedReq)
        XCTAssertEqual(req.url?.path,
                       "/uapi/domestic-stock/v1/quotations/inquire-price",
                       "FHKST01010100 경로 (API_SPEC.md §현재가 REST)")
        XCTAssertEqual(req.value(forHTTPHeaderField: "tr_id"), "FHKST01010100")

        let comps = try XCTUnwrap(URLComponents(url: req.url!, resolvingAgainstBaseURL: false))
        let mrktDiv = comps.queryItems?.first(where: { $0.name == "FID_COND_MRKT_DIV_CODE" })?.value
        XCTAssertEqual(mrktDiv, "J", "FID_COND_MRKT_DIV_CODE=J (주식, API_SPEC.md §현재가 REST)")
        let iscd = comps.queryItems?.first(where: { $0.name == "FID_INPUT_ISCD" })?.value
        XCTAssertEqual(iscd, "005930")
    }

    /// stck_sdpr 누락 시 price - prdy_vrss 역산.
    func testLookupPrice_NoSdpr_FallsBackToChange() async throws {
        let session = makeSession()
        StubProtocol.handler = { req, _ in
            let body: [String: Any] = [
                "rt_cd": "0",
                "output": [
                    "stck_prpr": "363500",
                    "prdy_vrss": "3000",
                    "stck_shrn_iscd": "005930",
                ],
            ]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = KISRESTClient(session: session)
        let quote = try await client.lookupPrice(code: "005930", token: "tok", appKey: "k", appSecret: "s")
        XCTAssertEqual(quote.previousClose, 360_500, "363500-3000=360500 역산")
    }

    /// stck_prpr 누락 → lookupFailed throw.
    func testLookupPrice_MissingPrice_ThrowsLookupFailed() async {
        let session = makeSession()
        StubProtocol.handler = { req, _ in
            let body: [String: Any] = ["rt_cd": "0", "output": ["stck_shrn_iscd": "005930"]]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = KISRESTClient(session: session)
        do {
            _ = try await client.lookupPrice(code: "005930", token: "tok", appKey: "k", appSecret: "s")
            XCTFail("lookupFailed 미발생")
        } catch KISRESTClient.RESTError.lookupFailed(_) {
            // 기대
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - 공통 헤더 검증

    /// lookupName 공통 헤더: authorization Bearer, appkey, appsecret, custtype=P (API_SPEC.md §종목명 조회).
    func testCommonHeaders_LookupName() async throws {
        let session = makeSession()
        var capturedReq: URLRequest?
        StubProtocol.handler = { req, _ in
            capturedReq = req
            let body: [String: Any] = [
                "rt_cd": "0",
                "output": ["prdt_abrv_name": "삼성전자", "pdno": "00000A005930"],
            ]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = KISRESTClient(session: session)
        _ = try await client.lookupName(code: "005930", token: "mytoken", appKey: "mykey", appSecret: "mysecret")

        let req = try XCTUnwrap(capturedReq)
        XCTAssertEqual(req.value(forHTTPHeaderField: "authorization"), "Bearer mytoken")
        XCTAssertEqual(req.value(forHTTPHeaderField: "appkey"), "mykey")
        XCTAssertEqual(req.value(forHTTPHeaderField: "appsecret"), "mysecret")
        XCTAssertEqual(req.value(forHTTPHeaderField: "custtype"), "P")
    }

    // MARK: - Units & Signs Audit: prdy_vrss signed 직접 파싱 (부호필드 재구성 금지)

    /// prdy_vrss 음수 + stck_sdpr 있음: previousClose = stck_sdpr 우선 (경계 규칙 ④, API_SPEC.md §부호 규칙).
    func testLookupPrice_SignedPrdyVrss_NegativeWithSdpr() async throws {
        let session = makeSession()
        StubProtocol.handler = { req, _ in
            let body: [String: Any] = [
                "rt_cd": "0",
                "output": [
                    "stck_prpr": "356000",
                    "prdy_vrss": "-4500",      // WS 실측 음수 포함 (API_SPEC.md §부호 규칙)
                    "prdy_vrss_sign": "5",     // 5=하락, 검증용만
                    "stck_sdpr": "360500",
                    "stck_shrn_iscd": "005930",
                ],
            ]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = KISRESTClient(session: session)
        let quote = try await client.lookupPrice(code: "005930", token: "tok", appKey: "k", appSecret: "s")
        XCTAssertEqual(quote.price, 356_000)
        XCTAssertEqual(quote.previousClose, 360_500, "stck_sdpr 우선")
        XCTAssertEqual(quote.change, -4_500, "change = price - previousClose = -4500")
        XCTAssertEqual(quote.direction, .down)
    }

    /// prdy_vrss 음수 + stck_sdpr 없음: price - prdy_vrss 역산 (356000 - (-4500) = 360500).
    func testLookupPrice_SignedPrdyVrss_NegativeNoSdpr() async throws {
        let session = makeSession()
        StubProtocol.handler = { req, _ in
            let body: [String: Any] = [
                "rt_cd": "0",
                "output": [
                    "stck_prpr": "356000",
                    "prdy_vrss": "-4500",
                    "stck_shrn_iscd": "005930",
                ],
            ]
            return (try! JSONSerialization.data(withJSONObject: body),
                    HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let client = KISRESTClient(session: session)
        let quote = try await client.lookupPrice(code: "005930", token: "tok", appKey: "k", appSecret: "s")
        XCTAssertEqual(quote.previousClose, 360_500,
                       "price-prdy_vrss 역산: 356000-(-4500)=360500")
        XCTAssertEqual(quote.change, -4_500)
        XCTAssertEqual(quote.direction, .down)
    }
}
