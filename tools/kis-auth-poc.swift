#!/usr/bin/env swift
//
// kis-auth-poc.swift — 한국투자증권(KIS) Open API 인증·시세·WS접속키 실측 PoC
//
// 목적(전환 체크리스트 [1]): 키움 지정단말기(8050) 제약 회피 가설 검증 + KIS 인증 흐름 실측.
//   ① access_token 발급 (POST /oauth2/tokenP)
//   ② 현재가 조회   (GET /uapi/domestic-stock/v1/quotations/inquire-price, tr_id FHKST01010100)
//   ③ WS 접속키 발급 (POST /oauth2/Approval) — 키움 WS와 다른 별도 흐름
//
//   ★ 전환 핵심 가설: 위 3개가 "외부 wifi에서도 HTTP 200" → 지정단말기/IP 제약 부재 확인.
//     (공식 문서에 지정단말기 언급 없음 + appkey/secret 기반 = 정황 근거 → 본 PoC 외부망 200으로 최종 확인.)
//
// ⚠️ 아래 base/path/tr_id/필드는 2차 출처(🟡) 가설 — 응답 raw JSON으로 검증/교정([2] 단계 입력).
//    출처: apiportal.koreainvestment.com + github.com/koreainvestment/open-trading-api (2026-05-30 확인).
//
// ⚠️ 보안: 실계좌 토큰·시세 stdout 출력. 토큰/approval_key는 앞/뒤 일부만 마스킹 출력. 파일 저장·커밋 금지.
//          토큰 재발급은 분당 1회 제한 — 반복 실행 시 EGW 오류 가능(정상, 1분 후 재시도).
//
// 실행:  swift tools/kis-auth-poc.swift              # real, 삼성전자(005930)
//        swift tools/kis-auth-poc.swift 000660       # real, 종목코드 지정(SK하이닉스)
//        swift tools/kis-auth-poc.swift 005930 vts    # 모의투자 도메인(vts)으로 시도
//
// 자격증명은 Keychain(kr.co.koreainvestment.paragon.{appkey,appsecret})에서 로드 — 값 비출력.

import Foundation
import Security

let args = CommandLine.arguments.dropFirst()
let symbol = args.first.flatMap { $0.allSatisfy(\.isNumber) ? $0 : nil } ?? "005930"
let useVTS = args.contains("vts")
// 🟡 도메인 가설: 실전 openapi:9443 / 모의 openapivts:29443
let restBase = useVTS ? "https://openapivts.koreainvestment.com:29443"
                      : "https://openapi.koreainvestment.com:9443"

func log(_ s: String) { print(s); fflush(stdout) }

// 민감값 마스킹 출력(앞6·뒤4)
func mask(_ s: String) -> String {
    guard s.count > 12 else { return "***" }
    return "\(s.prefix(6))…\(s.suffix(4)) (len=\(s.count))"
}

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

func pretty(_ data: Data, limit: Int = 4000) -> String {
    if let obj = try? JSONSerialization.jsonObject(with: data),
       let p = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
       let s = String(data: p, encoding: .utf8) { return String(s.prefix(limit)) }
    return String((String(data: data, encoding: .utf8) ?? "<binary>").prefix(limit))
}

// ── ① access_token (🟡 POST /oauth2/tokenP, body grant_type/appkey/appsecret) ──
func issueToken(appKey: String, secret: String) async -> (token: String?, http: Int, meta: String, raw: String) {
    var req = URLRequest(url: URL(string: "\(restBase)/oauth2/tokenP")!)
    req.httpMethod = "POST"
    req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: [
        "grant_type": "client_credentials", "appkey": appKey, "appsecret": secret,
    ])
    do {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        // 비민감 메타(유효기간·타입·만료시각)만 추려 출력 — [2] 필드 실측용
        let exp = json?["expires_in"].map { "\($0)" } ?? "?"
        let typ = (json?["token_type"] as? String) ?? "?"
        let dt = (json?["access_token_token_expired"] as? String) ?? "?"
        return (json?["access_token"] as? String, code, "expires_in=\(exp)s, token_type=\(typ), expired_at=\(dt)", pretty(data))
    } catch { return (nil, -1, "요청 오류", "요청 오류: \(error)") }
}

// ── ② 현재가 (🟡 GET inquire-price, tr_id FHKST01010100, FID_COND_MRKT_DIV_CODE=J) ──
func inquirePrice(token: String, appKey: String, secret: String) async -> (http: Int, raw: String) {
    var comp = URLComponents(string: "\(restBase)/uapi/domestic-stock/v1/quotations/inquire-price")!
    comp.queryItems = [
        .init(name: "FID_COND_MRKT_DIV_CODE", value: "J"),
        .init(name: "FID_INPUT_ISCD", value: symbol),
    ]
    var req = URLRequest(url: comp.url!)
    req.httpMethod = "GET"
    req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
    req.setValue(appKey, forHTTPHeaderField: "appkey")
    req.setValue(secret, forHTTPHeaderField: "appsecret")
    req.setValue("FHKST01010100", forHTTPHeaderField: "tr_id")
    req.setValue("P", forHTTPHeaderField: "custtype")   // P=개인
    do {
        let (data, resp) = try await URLSession.shared.data(for: req)
        return ((resp as? HTTPURLResponse)?.statusCode ?? -1, pretty(data, limit: 6000))
    } catch { return (-1, "요청 오류: \(error)") }
}

// ── ③ WS 접속키 (🟡 POST /oauth2/Approval, body grant_type/appkey/secretkey) ──
func issueApprovalKey(appKey: String, secret: String) async -> (key: String?, http: Int, raw: String) {
    var req = URLRequest(url: URL(string: "\(restBase)/oauth2/Approval")!)
    req.httpMethod = "POST"
    req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: [
        "grant_type": "client_credentials", "appkey": appKey, "secretkey": secret,
    ])
    do {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return (json?["approval_key"] as? String, code, pretty(data))
    } catch { return (nil, -1, "요청 오류: \(error)") }
}

func run() async -> Int32 {
    log("=== KIS Open API 인증·시세·WS접속키 PoC ===")
    log("env=\(useVTS ? "VTS(모의)" : "REAL")  base=\(restBase)  symbol=\(symbol)")
    guard let appKey = keychain("kr.co.koreainvestment.paragon.appkey"),
          let secret = keychain("kr.co.koreainvestment.paragon.appsecret") else {
        log("[FAIL] Keychain 자격증명 없음 (kr.co.koreainvestment.paragon.{appkey,appsecret})"); return 1
    }
    log("appkey=\(mask(appKey))  appsecret=\(mask(secret))")
    var pass = 0, total = 3

    // ①
    log("\n[1/3] access_token 발급 → POST /oauth2/tokenP")
    let t = await issueToken(appKey: appKey, secret: secret)
    log("  HTTP \(t.http)")
    if let tok = t.token { pass += 1; log("  ✅ access_token = \(mask(tok))"); log("  meta: \(t.meta)") }
    else { log("  ❌ 토큰 없음\n  응답:\n\(t.raw)") }

    // ②
    if let tok = t.token {
        log("\n[2/3] 현재가 조회 → GET inquire-price (tr_id FHKST01010100) \(symbol)")
        let p = await inquirePrice(token: tok, appKey: appKey, secret: secret)
        log("  HTTP \(p.http)")
        log("  응답(pretty):\n\(p.raw)")
        if p.http == 200 { pass += 1 }
    } else { log("\n[2/3] 토큰 없어 건너뜀") }

    // ③
    log("\n[3/3] WS 접속키 발급 → POST /oauth2/Approval")
    let a = await issueApprovalKey(appKey: appKey, secret: secret)
    log("  HTTP \(a.http)")
    if let k = a.key { pass += 1; log("  ✅ approval_key = \(mask(k))") }
    else { log("  ❌ approval_key 없음\n  응답:\n\(a.raw)") }

    log("\n=== 결과: \(pass)/\(total) PASS ===")
    log("★ 전환 핵심 가설: 위 3개 모두 외부 wifi에서 200/정상 → 지정단말기(8050) 제약 부재 확인.")
    log("→ [2] 단계 입력으로 확인할 것:")
    log("  · 토큰 응답: expires_in(유효기간) / token_type")
    log("  · 현재가 응답: rt_cd(0=성공) / msg_cd / output 내 stck_prpr(현재가)·필드 단위·스케일")
    log("  · 종목코드 형식: KIS는 6자리 순수(키움 잔고 A접두와 정규화 필요 — SymbolCode.normalize6)")
    log("  · approval_key: WS 구독 흐름(H0STCNT0) 진입키 — 별도 ws PoC로 체결 1건 실측")
    return pass == total ? 0 : 2
}

let code = await run()
exit(code)
