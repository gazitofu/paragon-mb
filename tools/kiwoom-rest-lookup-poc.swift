#!/usr/bin/env swift
//
// kiwoom-rest-lookup-poc.swift — REST 종목조회 엔드포인트 실측 탐색 PoC
//
// 목적: 관심종목 등록 시 "종목코드 → 종목명 + 초기 현재가"를 얻는 REST 호출의
//       엔드포인트·TR·응답 필드를 실측 확인한다 (API_SPEC.md 🔴 미검증 해소).
//       결과 raw JSON을 보고 KiwoomRESTClient.lookup 파싱을 잠근다.
//
// ⚠️ 아래 엔드포인트/TR(api-id)은 2차 출처(🟡) 가설이다 — 응답으로 검증/교정 대상.
//    가설: POST {base}/api/dostk/stkinfo, header api-id=ka10001(주식기본정보요청), body {"stk_cd":code}
//
// 실행:  swift tools/kiwoom-rest-lookup-poc.swift            # real, 005930
//        swift tools/kiwoom-rest-lookup-poc.swift mock 000660
//
// 자격증명은 Keychain(kr.co.kiwoom.paragon.{appkey,appsecret})에서 로드 — 값 비출력.

import Foundation
import Security

let args = CommandLine.arguments.dropFirst()
let useMock = (args.first?.lowercased() ?? "real") == "mock"
let symbol = args.dropFirst().first ?? "005930"
let restBase = useMock ? "https://api.kiwoom.com:9443" : "https://api.kiwoom.com"

// 시도할 TR 가설 목록 (api-id, 카테고리 path) — 응답으로 어느 게 맞는지 확인.
let candidates: [(apiID: String, path: String, desc: String)] = [
    ("ka10001", "/api/dostk/stkinfo", "주식기본정보요청(가설)"),
]

func log(_ s: String) { print(s); fflush(stdout) }

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

func issueToken(appKey: String, secret: String) async throws -> String {
    var req = URLRequest(url: URL(string: "\(restBase)/oauth2/token")!)
    req.httpMethod = "POST"
    req.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONSerialization.data(withJSONObject: [
        "grant_type": "client_credentials", "appkey": appKey, "secretkey": secret,
    ])
    let (data, _) = try await URLSession.shared.data(for: req)
    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    guard let token = json["token"] as? String, !token.isEmpty else {
        throw NSError(domain: "poc", code: 1, userInfo: [NSLocalizedDescriptionKey: "토큰 없음: \(String(data: data, encoding: .utf8) ?? "")"])
    }
    return token
}

func run() async -> Int32 {
    log("=== Kiwoom REST 종목조회 PoC ===")
    log("env=\(useMock ? "MOCK" : "REAL")  base=\(restBase)  symbol=\(symbol)")
    guard let appKey = keychain("kr.co.kiwoom.paragon.appkey"),
          let secret = keychain("kr.co.kiwoom.paragon.appsecret") else {
        log("[FAIL] Keychain 자격증명 없음"); return 1
    }
    let token: String
    do { token = try await issueToken(appKey: appKey, secret: secret); log("[token] OK") }
    catch { log("[FAIL] 토큰: \(error)"); return 1 }

    for c in candidates {
        log("\n--- 시도: \(c.apiID) \(c.path) (\(c.desc)) ---")
        var req = URLRequest(url: URL(string: restBase + c.path)!)
        req.httpMethod = "POST"
        req.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        req.setValue(c.apiID, forHTTPHeaderField: "api-id")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["stk_cd": symbol])
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            log("HTTP \(code)")
            log("응답 raw:\n\(raw.prefix(2000))")
        } catch {
            log("요청 오류: \(error)")
        }
    }
    log("\n→ 위 raw JSON에서 종목명·현재가·전일종가 필드명을 확인해 lookup 파싱을 잠근다.")
    return 0
}

let code = await run()
exit(code)
