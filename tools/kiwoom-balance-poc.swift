#!/usr/bin/env swift
//
// kiwoom-balance-poc.swift — 실계좌 계좌평가잔고 엔드포인트 실측 탐색 PoC
//
// 목적: holdings-pnl 슬라이스의 최대 미검증 전제(Premise #1·#4·#5) 해소.
//       "실계좌 잔고 → 보유종목 코드·종목명·보유수량·평단가·평가손익·수익률"을 얻는
//       REST 호출의 endpoint·TR(api-id)·요청 body·응답 필드를 실측 확인한다.
//       결과 raw JSON으로 KiwoomBalanceParser 파싱 + 손익 산식(Premise #4)을 잠근다.
//
// ⚠️ 아래 TR(api-id)·path·body는 2차 출처(🟡) 가설이다 — 응답으로 검증/교정 대상.
//    가설: POST {base}/api/dostk/acnt, header api-id=kt00018(계좌평가잔고내역요청),
//          body {"qry_tp":"1","dmst_stex_tp":"KRX"} (qry_tp 1=합산/2=개별 추정).
//    출처: openapi.kiwoom.com API 목록 + dongbin300/KiwoomRestApi.Net(.NET 래퍼).
//
// ⚠️ 보안: 실계좌 보유종목·평단가(민감 금융정보)를 stdout에 출력한다. 파일 저장·커밋 금지.
//          모의(mock)는 가짜 잔고이므로 보유 의미 없음 — real이 기본.
//
// 실행:  swift tools/kiwoom-balance-poc.swift          # real, qry_tp=1(합산)
//        swift tools/kiwoom-balance-poc.swift real 2   # real, qry_tp=2(개별)
//        swift tools/kiwoom-balance-poc.swift mock      # mock(검증: 잔고 없음/실계좌 필요 응답 형태 확인용)
//
// 자격증명은 Keychain(kr.co.kiwoom.paragon.{appkey,appsecret})에서 로드 — 값 비출력.

import Foundation
import Security

let args = CommandLine.arguments.dropFirst()
let useMock = (args.first?.lowercased() ?? "real") == "mock"
let qryTp = args.dropFirst().first ?? "1"   // 1=합산, 2=개별(추정)
let restBase = useMock ? "https://api.kiwoom.com:9443" : "https://api.kiwoom.com"

// 시도할 TR 가설 (api-id, 카테고리 path, body) — 응답으로 어느 게 맞는지/필드명 확인.
let candidates: [(apiID: String, path: String, body: [String: String], desc: String)] = [
    ("kt00018", "/api/dostk/acnt", ["qry_tp": qryTp, "dmst_stex_tp": "KRX"], "계좌평가잔고내역요청(가설)"),
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
    log("=== Kiwoom REST 계좌평가잔고 PoC ===")
    log("env=\(useMock ? "MOCK" : "REAL")  base=\(restBase)  qry_tp=\(qryTp)")
    guard let appKey = keychain("kr.co.kiwoom.paragon.appkey"),
          let secret = keychain("kr.co.kiwoom.paragon.appsecret") else {
        log("[FAIL] Keychain 자격증명 없음"); return 1
    }
    let token: String
    do { token = try await issueToken(appKey: appKey, secret: secret); log("[token] OK") }
    catch { log("[FAIL] 토큰: \(error)"); return 1 }

    for c in candidates {
        log("\n--- 시도: \(c.apiID) \(c.path) (\(c.desc)) body=\(c.body) ---")
        var req = URLRequest(url: URL(string: restBase + c.path)!)
        req.httpMethod = "POST"
        req.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        req.setValue(c.apiID, forHTTPHeaderField: "api-id")
        req.setValue("N", forHTTPHeaderField: "cont-yn")
        req.setValue("", forHTTPHeaderField: "next-key")
        req.httpBody = try? JSONSerialization.data(withJSONObject: c.body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            log("HTTP \(code)")
            // pretty-print JSON if possible
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
               let ps = String(data: pretty, encoding: .utf8) {
                log("응답(pretty):\n\(ps.prefix(6000))")
            } else {
                log("응답 raw:\n\(raw.prefix(4000))")
            }
        } catch {
            log("요청 오류: \(error)")
        }
    }
    log("\n→ 위 raw JSON에서 다음을 확인해 파싱·손익 산식을 잠근다:")
    log("  · 보유종목 리스트 키 / 종목코드·종목명 필드")
    log("  · 보유수량·평단가(매입단가) 필드 + 단위(원·주)")
    log("  · 평가손익·수익률 필드 (앱 계산 보유수량×(현재가−평단가)과 부호·반올림 일치 검증 → Premise #4)")
    log("  · 평단가 정의(수수료 포함 여부 → Premise #5)")
    log("  · 합산(총매입·총평가·총손익·총수익률) 필드 존재 여부")
    return 0
}

let code = await run()
exit(code)
