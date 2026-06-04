import Foundation

/// KIS 페이로드 → Domain Quote/Symbol 격리 파서.
/// 부호·스케일 SSOT (경계 규칙 ②③④).
/// WS 실측 SSOT: docs/API_SPEC.md §H0STCNT0 필드맵 (005930, 2026-06-04).
///
/// 경계 규칙 ④: [4][5] signed 값 직접 파싱 — abs 금지, sign 필드로 부호 재구성 금지.
/// [3]sign 필드(2=상승·5=하락)는 검증 보조 전용 — 모순 시 signed 채택.
public enum KISQuoteParser {

    // === SECTION: WS_CHUNKED ===

    /// WS H0STCNT0 raw 본문 → [(code, Quote)].
    /// 형식: `본문` 은 `^` 구분 평문. 건수 N → 46필드 × N 청킹.
    /// 길이 불일치(46 배수 아님) 시 해당 레코드 skip — 조용한 크래시 방지.
    public static func parseExecutionChunked(body: String, count: Int) -> [(code: String, quote: Quote)] {
        guard count > 0 else { return [] }
        let fields = body.components(separatedBy: "^")
        let expected = 46 * count
        guard fields.count >= expected else { return [] }
        var results: [(code: String, quote: Quote)] = []
        results.reserveCapacity(count)
        for i in 0..<count {
            let base = i * 46
            let chunk = Array(fields[base..<(base + 46)])
            if let r = parseRecord(chunk) {
                results.append(r)
            }
        }
        return results
    }

    // === SECTION: WS_RECORD ===

    /// per-record 46필드 배열 → (code, Quote).
    /// [0]코드 [1]시각 [2]현재가 [3]sign [4]signed 전일대비 [5]signed 등락률.
    /// signed 직접 파싱 — sign 필드는 검증 보조만 (모순 시 signed 채택, 경계 규칙 ④).
    public static func parseRecord(_ fields: [String]) -> (code: String, quote: Quote)? {
        guard fields.count >= 6 else { return nil }
        let code = fields[0].trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return nil }

        guard let price = parseSignedInt(fields[2]), price > 0 else { return nil }
        guard let change = parseSignedInt(fields[4]) else { return nil }

        // sign 필드 [3]: 2=상승·5=하락(실측). 부호 재구성 미사용 — 교차검증만.
        let signField = fields[3].trimmingCharacters(in: .whitespaces)
        validateSignConsistency(code: code, signField: signField, change: change)

        let previousClose = price - change
        return (code, Quote(price: price, previousClose: previousClose))
    }

    // === SECTION: REST_PARSE ===

    /// CTPF1002R(주식기본조회) JSON → (Symbol, Quote).
    /// prdt_abrv_name trailing 공백 trim. stck_sdpr(기준가=전일종가) → previousClose.
    public static func parseStockInfo(_ json: [String: Any]) -> (symbol: Symbol, quote: Quote)? {
        guard let code = json["pdno"] as? String,
              !code.trimmingCharacters(in: .whitespaces).isEmpty,
              let rawName = json["prdt_abrv_name"] as? String,
              !rawName.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        let name = rawName.trimmingCharacters(in: .whitespaces)
        let trimmedCode = code.trimmingCharacters(in: .whitespaces)
        // Symbol only — Quote는 inquire-price 경로(QuoteService.loadInitial)가 담당.
        // 호출처가 Quote 없는 Symbol만 필요한 경우 nil previousClose 허용.
        guard let priceStr = json["stck_prpr"] as? String, let price = parseSignedInt(priceStr), price > 0,
              let sdprStr = json["stck_sdpr"] as? String, let sdpr = parseSignedInt(sdprStr)
        else {
            // Quote 데이터 없어도 Symbol은 반환 가능 — 등록 플로우는 Symbol만 필요.
            // 단, Quote 없는 분기는 nil로 처리 (호출처가 Quote 요구 시 inquire-price 경유).
            return nil
        }
        return (Symbol(code: trimmedCode, name: name), Quote(price: price, previousClose: sdpr))
    }

    /// FHKST01010100(주식현재가) JSON → Quote.
    /// prdy_vrss: signed 직접 파싱 (부호필드 prdy_vrss_sign 재구성 금지 — 경계 규칙 ④).
    /// stck_sdpr(기준가=전일종가) 우선 — 없으면 price − prdy_vrss 역산.
    public static func parsePrice(_ json: [String: Any]) -> Quote? {
        guard let priceStr = json["stck_prpr"] as? String,
              let price = parseSignedInt(priceStr), price > 0
        else { return nil }
        let change = (json["prdy_vrss"] as? String).flatMap { parseSignedInt($0) } ?? 0
        let previousClose: Int
        if let sdprStr = json["stck_sdpr"] as? String, let sdpr = parseSignedInt(sdprStr), sdpr > 0 {
            previousClose = sdpr
        } else {
            previousClose = price - change
        }
        return Quote(price: price, previousClose: previousClose)
    }

    // === SECTION: UTILS ===

    /// KIS 숫자 문자열(콤마 허용, 부호 prefix 허용) → Int. 실패 시 nil.
    /// 예: "-4500" → -4500 / "356,000" → 356000 / "+3000" → 3000.
    public static func parseSignedInt(_ s: String) -> Int? {
        let cleaned = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        return Int(cleaned)
    }

    /// KIS 숫자 문자열(콤마 허용, 부호 prefix 허용) → Double. 실패 시 nil.
    /// 예: "-1.25" → -1.25 / "+3.67" → 3.67.
    public static func parseSignedDouble(_ s: String) -> Double? {
        let cleaned = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    // === SECTION: SIGN_VALIDATION ===

    /// sign 필드 vs signed change 교차검증 — 모순 시 ops 기록(부호 재구성 미사용).
    /// 2=상승(change>0), 5=하락(change<0), 3=보합(change==0).
    private static func validateSignConsistency(code: String, signField: String, change: Int) {
        let expectedByChange: String
        if change > 0 { expectedByChange = "2" }
        else if change < 0 { expectedByChange = "5" }
        else { expectedByChange = "3" }

        if !signField.isEmpty && signField != expectedByChange {
            // 모순: signed 채택 + 불일치 기록 (ops 노트 수집 경로)
            // 로그는 DEBUG 빌드에만 출력 — 운영 환경 노이즈 방지.
            #if DEBUG
            print("[KISQuoteParser] sign 모순: code=\(code) signField=\(signField) expected=\(expectedByChange) change=\(change) → signed 채택")
            #endif
        }
    }
}
