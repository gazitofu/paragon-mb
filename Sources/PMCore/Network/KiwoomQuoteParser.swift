import Foundation

/// 키움 페이로드 → Domain Quote 격리 파서(K8 — 실측 후 한 곳만 수정).
/// 부호·스케일 SSOT. 변경 시 QuoteParsingTests(Units & Signs Audit)가 게이트.
///
/// WS 0B(주식체결) 실측 매핑(PoC 2026-05-29, 005930):
///   FID 10 현재가  — 부호는 방향 표시, 가격은 abs (원, 스케일 없음 — 사용자 확인)
///   FID 11 전일대비 — 부호 보존(상승 +, 하락 −)
///   previousClose = price − change  → Quote가 등락률·방향 재파생
public enum KiwoomQuoteParser {

    /// WS 0B values → (종목코드, Quote). 필수 FID(10·11) 누락 시 nil.
    public static func parseRealtimeExecution(item: String, values: [String: String]) -> (code: String, quote: Quote)? {
        guard let priceRaw = values["10"], let signedPrice = parseSignedInt(priceRaw),
              let changeRaw = values["11"], let change = parseSignedInt(changeRaw)
        else { return nil }
        let price = abs(signedPrice)               // 가격은 양수 — FID 10 부호는 방향 표시일 뿐
        let previousClose = price - change         // 부호 보존된 change로 역산
        return (item, Quote(price: price, previousClose: previousClose))
    }

    /// 키움 숫자 문자열("+310500" / "-650" / "310500" / "+1,500") → Int. 콤마·공백 제거. 실패 시 nil.
    public static func parseSignedInt(_ s: String) -> Int? {
        let cleaned = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        return Int(cleaned)
    }

    /// REST ka10001(주식기본정보) 응답 → (Symbol, Quote). 실측 PoC 2026-05-29.
    ///   stk_cd 종목코드 / stk_nm 종목명 / cur_prc 현재가(부호=방향, abs) / base_pric 전일종가(기준가, 부호 없음)
    public static func parseStockInfo(_ json: [String: Any]) -> (symbol: Symbol, quote: Quote)? {
        guard let code = json["stk_cd"] as? String, !code.isEmpty,
              let name = json["stk_nm"] as? String, !name.isEmpty,
              let curRaw = json["cur_prc"] as? String, let signedPrice = parseSignedInt(curRaw),
              let baseRaw = json["base_pric"] as? String, let base = parseSignedInt(baseRaw)
        else { return nil }
        return (Symbol(code: code, name: name), Quote(price: abs(signedPrice), previousClose: abs(base)))
    }
}
