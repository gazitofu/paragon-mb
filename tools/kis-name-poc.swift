#!/usr/bin/env swift
//
// kis-name-poc.swift — 한국투자증권(KIS) 종목명 조회(주식기본조회 CTPF1002R) 실측 PoC
//
// 목적(전환 체크리스트 [3] 선행): inquire-price(FHKST01010100)는 종목명을 반환하지 않음(2026-06-04 실측)
//   → watchlist 등록 플로우(코드 입력 → 종목명 표시)에 필요한 종목명 확보 경로 실측.
//   후보 TR = 주식기본조회 [v1_국내주식-067]: GET /uapi/domestic-stock/v1/quotations/search-stock-info
//   (출처: 공식 GitHub koreainvestment/open-trading-api examples_llm/domestic_stock/search_stock_info — 1차)
//   응답의 종목명 필드명(prdt_name/prdt_abrv_name 류 🟡)을 본 PoC raw로 확정.
//
// 실행:  swift tools/kis-name-poc.swift                  # real, 005930
//        swift tools/kis-name-poc.swift 005930 069500    # 복수 종목(주식+ETF) — 토큰 1회 발급 공유
//
//   ⚠️ 토큰 재발급 분당 1회 제한 — 복수 종목은 인자로 한 번에(실행당 토큰 1회).
//
// 종료 코드: 0 = 전 종목 200 + 종목명 필드 확인 / 2 = 200이나 종목명 필드 불명 / 1 = 인증·호출 실패
//
// ⚠️ 보안: 토큰 마스킹 출력. 종목 기본정보는 공개정보. 파일 저장·커밋 금지.
// 자격증명은 env 파일(기본 ~/.config/secrets/api.env, override=PARAGON_SECRETS_ENV) 우선 → Keychain 폴백 로드 — 값 비출력.
//   (사용자 결정 2026-06-03: decisions/2026-06-03-kis-credentials-from-env.md)

import Foundation
import Security

let symbols: [String] = {
    let s = CommandLine.arguments.dropFirst().filter { $0.allSatisfy(\.isNumber) }
    return s.isEmpty ? ["005930"] : Array(s)
}()
let restBase = "https://openapi.koreainvestment.com:9443"

func log(_ s: String) { print(s); fflush(stdout) }
func mask(_ s: String) -> String { s.count > 12 ? "\(s.prefix(6))…\(s.suffix(4)) (len=\(s.count))" : "***" }

func keychain(_ service: String) -> String? {
    let q: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
          let d = item as? Data, let s = String(data: d, encoding: .utf8) else { return nil }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

// env 파일(기본 ~/.config/secrets/api.env, override=PARAGON_SECRETS_ENV)에서 KEY 값 로드.
// 형식: optional `export `, KEY=VALUE, 따옴표·#주석·공백 허용. 값은 로그에 비출력(Floor 4).
func envFileValue(_ key: String) -> String? {
    let path = ProcessInfo.processInfo.environment["PARAGON_SECRETS_ENV"]
        ?? (NSHomeDirectory() as NSString).appendingPathComponent(".config/secrets/api.env")
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
    for raw in content.components(separatedBy: .newlines) {
        var line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        if line.hasPrefix("export ") { line = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
        guard let eq = line.firstIndex(of: "="),
              String(line[..<eq]).trimmingCharacters(in: .whitespaces) == key else { continue }
        var v = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        if v.count >= 2,
           (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")) {
            v = String(v.dropFirst().dropLast())
        }
        return v.isEmpty ? nil : v
    }
    return nil
}

// 자격증명 로드: env 파일 우선 → Keychain 폴백(사용자 결정 2026-06-03). source는 비민감(env/keychain 구분만).
func loadCredential(envKey: String, keychainService service: String) -> (value: String?, source: String) {
    if let v = envFileValue(envKey) { return (v, "env:\(envKey)") }
    if let v = keychain(service) { return (v, "keychain:\(service)") }
    return (nil, "없음")
}

func pretty(_ data: Data, limit: Int = 4000) -> String {
    if let obj = try? JSONSerialization.jsonObject(with: data),
       let p = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
       let s = String(data: p, encoding: .utf8) { return String(s.prefix(limit)) }
    return String((String(data: data, encoding: .utf8) ?? "<binary>").prefix(limit))
}

// ── access_token (실측 확정: POST /oauth2/tokenP — API_SPEC.md §인증) ──
func issueToken(appKey: String, secret: String) async -> String? {
    var req = URLRequest(url: URL(string: "\(restBase)/oauth2/tokenP")!)
    req.httpMethod = "POST"
    req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: [
        "grant_type": "client_credentials", "appkey": appKey, "appsecret": secret,
    ])
    guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return nil }
    let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    if json?["access_token"] == nil { log("  [token] HTTP \(code) 응답:\n\(pretty(data, limit: 600))") }
    return json?["access_token"] as? String
}

// ── 주식기본조회 (🟡 GET search-stock-info, tr_id CTPF1002R, PRDT_TYPE_CD=300) ──
func searchStockInfo(token: String, appKey: String, secret: String, symbol: String) async -> (http: Int, output: [String: Any]?, raw: String) {
    var comp = URLComponents(string: "\(restBase)/uapi/domestic-stock/v1/quotations/search-stock-info")!
    comp.queryItems = [
        .init(name: "PRDT_TYPE_CD", value: "300"),   // 300 = 주식·ETF·ETN·ELW (공식 샘플)
        .init(name: "PDNO", value: symbol),
    ]
    var req = URLRequest(url: comp.url!)
    req.httpMethod = "GET"
    req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
    req.setValue(appKey, forHTTPHeaderField: "appkey")
    req.setValue(secret, forHTTPHeaderField: "appsecret")
    req.setValue("CTPF1002R", forHTTPHeaderField: "tr_id")
    req.setValue("P", forHTTPHeaderField: "custtype")
    do {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return (code, json?["output"] as? [String: Any], pretty(data, limit: 5000))
    } catch { return (-1, nil, "요청 오류: \(error)") }
}

func run() async -> Int32 {
    log("=== KIS 종목명 조회(주식기본조회 CTPF1002R) PoC ===")
    log("symbols=\(symbols.joined(separator: ","))  base=\(restBase)")
    let appKeyC = loadCredential(envKey: "KIS_APP_KEY", keychainService: "kr.co.koreainvestment.paragon.appkey")
    let secretC = loadCredential(envKey: "KIS_APP_SECRET", keychainService: "kr.co.koreainvestment.paragon.appsecret")
    guard let appKey = appKeyC.value, let secret = secretC.value else {
        log("[FAIL] 자격증명 없음 — env(KIS_APP_KEY/KIS_APP_SECRET)·Keychain 모두 부재"); return 1
    }
    log("[cred] appkey=\(mask(appKey)) [\(appKeyC.source)]  appsecret=\(mask(secret)) [\(secretC.source)]")

    log("\n[token] POST /oauth2/tokenP (실행당 1회 — 분당 1회 제한)")
    guard let token = await issueToken(appKey: appKey, secret: secret) else {
        log("[FAIL] 토큰 발급 실패 (직전 발급 1분 이내면 잠시 후 재시도)"); return 1
    }
    log("  ✅ access_token = \(mask(token))")

    // 종목명 후보 필드(🟡 — raw로 확정): 상품명/약어명/영문명/120자명
    let nameCandidates = ["prdt_name", "prdt_abrv_name", "prdt_eng_name", "prdt_name120", "prdt_eng_abrv_name"]
    var okCount = 0, nameFound = 0

    for (i, symbol) in symbols.enumerated() {
        if i > 0 { try? await Task.sleep(nanoseconds: 600_000_000) }   // 연속 호출 EGW00201(초당 건수 초과) 실측 → 간격 확보
        log("\n[\(i + 1)/\(symbols.count)] search-stock-info PDNO=\(symbol) (PRDT_TYPE_CD=300)")
        var r = await searchStockInfo(token: token, appKey: appKey, secret: secret, symbol: symbol)
        if r.raw.contains("EGW00201") {                                 // rate-limit 1회 재시도(1s 백오프)
            log("  ⏳ EGW00201(초당 건수 초과) — 1s 후 재시도")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            r = await searchStockInfo(token: token, appKey: appKey, secret: secret, symbol: symbol)
        }
        log("  HTTP \(r.http)")
        if r.http == 200, let out = r.output {
            okCount += 1
            let hits = nameCandidates.compactMap { k in (out[k] as? String).map { "\(k)=\"\($0)\"" } }
            if hits.isEmpty {
                log("  ⚠️ 종목명 후보 필드 미발견 — 전체 output 키 확인 필요")
                log("  응답(pretty):\n\(r.raw)")
            } else {
                nameFound += 1
                log("  ✅ 종목명 필드: \(hits.joined(separator: "  "))")
                // 코드 형식 교차확인(잔고 A접두 이슈와 대비)
                for k in ["pdno", "std_pdno", "shtn_pdno"] {
                    if let v = out[k] as? String { log("     \(k)=\"\(v)\"") }
                }
                if i == 0 { log("  전체 응답(첫 종목만, 필드 시맨틱 실측용):\n\(r.raw)") }
            }
        } else {
            log("  ❌ 실패 응답:\n\(r.raw)")
        }
    }

    log("\n=== 요약 ===")
    log("호출 성공: \(okCount)/\(symbols.count)  종목명 확인: \(nameFound)/\(symbols.count)")
    if nameFound == symbols.count {
        log("판정: ✅ CTPF1002R = watchlist 등록용 종목명 확보 경로 확정 — API_SPEC.md 🔴 갭 해소")
        return 0
    } else if okCount > 0 {
        log("판정: 🟡 호출은 성공했으나 종목명 필드 추가 확인 필요 — raw output 검토")
        return 2
    } else {
        log("판정: ❌ 호출 실패 — tr_id/params/권한 점검")
        return 1
    }
}

let code = await run()
exit(code)
