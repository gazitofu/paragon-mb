#!/usr/bin/env swift
//
// kis-ws-poc.swift — 한국투자증권(KIS) WebSocket 실시간 체결(H0STCNT0) 실측 PoC
//
// 목적(전환 체크리스트 [2]): KIS WS 체결 raw 수신 + 필드 위치 맵 실측.
//   approval_key 발급(REST) → WS 접속 → H0STCNT0 구독 → 체결 raw 1건 수신 → 필드 index 덤프.
//   ★ 시세 전용 — tr_key=종목코드만, 계좌 데이터 0건 (사용자 요구: IP독립 주가조회, 계좌 불필요).
//
// 키움 WS와의 차이(🟡 2차 출처, 본 PoC로 실측·교정):
//   ① 인증: REST access_token 아님 → 별도 approval_key(/oauth2/Approval)
//   ② 구독: header/body envelope + tr_id "H0STCNT0" + tr_key 종목코드
//   ③ 수신: JSON 아님 → "|"·"^" 구분 raw 문자열 (위치 기반 파서)
//   ④ keep-alive: PINGPONG JSON echo
//
// 실행:  swift tools/kis-ws-poc.swift              # real, 005930, wss
//        swift tools/kis-ws-poc.swift 000660       # 종목 지정
//        swift tools/kis-ws-poc.swift 005930 ws     # 평문 ws로 시도(ATS 차단 시 진단용)
//
// 종료 코드:
//   0 = 체결 raw 수신          → KIS WS 시세 완전 검증
//   2 = 구독응답 OK, 체결 무수신 → 연결성 입증(장 마감/한산 추정)
//   1 = 접속/구독 실패
//
// ⚠️ 보안: approval_key는 마스킹 출력. 체결 시세는 공개정보. 파일 저장·커밋 금지.
//          ⚠️ KIS WS는 ws://(평문) 문서값 — macOS ATS가 script에서 차단할 수 있음.
//             앱은 Info.plist ATS 예외로 해결 예정. PoC는 wss 우선 시도 + 실패 진단.
//
// 자격증명은 Keychain(kr.co.koreainvestment.paragon.{appkey,appsecret})에서 로드 — 값 비출력.

import Foundation
import Security

let args = CommandLine.arguments.dropFirst()
let symbol = args.first.flatMap { $0.allSatisfy(\.isNumber) ? $0 : nil } ?? "005930"
let scheme = args.contains("ws") ? "ws" : "wss"
let restBase = "https://openapi.koreainvestment.com:9443"
let wsURLString = "\(scheme)://ops.koreainvestment.com:21000"   // 🟡 실전 WS (모의=:31000)
let trID = "H0STCNT0"                                            // 🟡 국내주식 실시간 체결가
let receiveBudgetSeconds: TimeInterval = 40

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

func toJSON(_ obj: [String: Any]) -> String {
    String(data: try! JSONSerialization.data(withJSONObject: obj), encoding: .utf8)!
}
func parse(_ text: String) -> [String: Any]? {
    text.data(using: .utf8).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
}

// ── approval_key 발급 (🟡 POST /oauth2/Approval, body grant_type/appkey/secretkey) ──
func issueApprovalKey(appKey: String, secret: String) async -> String? {
    var req = URLRequest(url: URL(string: "\(restBase)/oauth2/Approval")!)
    req.httpMethod = "POST"
    req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: [
        "grant_type": "client_credentials", "appkey": appKey, "secretkey": secret,
    ])
    guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return nil }
    let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    if json?["approval_key"] == nil { log("  [approval] HTTP \(code) 응답: \(String(data: data, encoding: .utf8)?.prefix(300) ?? "")") }
    return json?["approval_key"] as? String
}

// ── 수신 상태 ──
actor PoCState {
    var subOK = false, realCount = 0, msgCount = 0, firstReal: String?
    func markSub(_ b: Bool) { subOK = b }
    func bumpMsg() { msgCount += 1 }
    func addReal(_ d: String) { realCount += 1; if firstReal == nil { firstReal = d } }
}

// H0STCNT0 체결 raw 필드 위치 가설(🟡 — 덤프로 확정): 0종목코드 1체결시간 2현재가 3대비부호 4대비 5등락률 …
func dumpRealtimeFields(_ body: String) {
    let f = body.components(separatedBy: "^")
    log("  필드 \(f.count)개 (index=value):")
    let hint = [0: "종목코드", 1: "체결시간HHMMSS", 2: "현재가", 3: "전일대비부호", 4: "전일대비", 5: "등락률%", 12: "체결거래량", 13: "누적거래량"]
    for (i, v) in f.enumerated() where i < 20 {
        log("    [\(i)] \(v)\(hint[i].map { "   ← \($0)?(🟡)" } ?? "")")
    }
}

func run() async -> Int32 {
    log("=== KIS WS 실시간 체결 PoC ===")
    log("symbol=\(symbol)  tr_id=\(trID)  ws=\(wsURLString)")
    guard let appKey = keychain("kr.co.koreainvestment.paragon.appkey"),
          let secret = keychain("kr.co.koreainvestment.paragon.appsecret") else {
        log("[FAIL] Keychain 자격증명 없음"); return 1
    }

    // 1) approval_key
    guard let approvalKey = await issueApprovalKey(appKey: appKey, secret: secret) else {
        log("[FAIL] approval_key 발급 실패"); return 1
    }
    log("[approval] OK = \(mask(approvalKey))")

    // 2) WS 접속
    let task = URLSession(configuration: .default).webSocketTask(with: URL(string: wsURLString)!)
    task.resume()
    log("[ws] connect 시도…")
    let state = PoCState()

    // 3) 수신 루프
    let receiver = Task {
        while !Task.isCancelled {
            let message: URLSessionWebSocketTask.Message
            do { message = try await task.receive() }
            catch { log("[ws] 수신 종료/오류: \(error)"); break }
            let text: String
            switch message {
            case .string(let s): text = s
            case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
            @unknown default: continue
            }
            await state.bumpMsg()
            let mc = await state.msgCount
            if mc <= 6 { log("[ws] msg#\(mc): \(text.prefix(140))") }   // 초반만 verbatim(장중 체결 폭주 시 노이즈 방지)

            if text.hasPrefix("{") {
                // 구독 응답 또는 PINGPONG (JSON)
                let json = parse(text)
                let trnm = ((json?["header"] as? [String: Any])?["tr_id"] as? String) ?? ""
                if trnm == "PINGPONG" {
                    try? await task.send(.string(text))            // keep-alive echo
                    continue
                }
                let bodyObj = json?["body"] as? [String: Any]
                let rt = (bodyObj?["rt_cd"] as? String) ?? "?"
                let msg = (bodyObj?["msg1"] as? String) ?? ""
                log("[ws] 구독 응답 tr_id=\(trnm) rt_cd=\(rt) \(msg)")
                await state.markSub(rt == "0")
            } else {
                // 실시간 raw: "암호화flag|tr_id|건수|본문(^구분)"
                let parts = text.components(separatedBy: "|")
                let n = await { await state.addReal(text); return await state.realCount }()
                if n == 1 {
                    log("[ws] ★ 첫 체결 raw 수신:")
                    log("    raw(앞200): \(text.prefix(200))")
                    log("    헤더: 암호화flag=\(parts.first ?? "?") tr_id=\(parts.count>1 ? parts[1]:"?") 건수=\(parts.count>2 ? parts[2]:"?")")
                    if parts.count > 3 { dumpRealtimeFields(parts[3]) }
                } else { log("[ws] 체결 raw #\(n)") }
            }
        }
    }

    // 4) 구독 메시지 송신 (🟡 header/body envelope)
    let sub = toJSON([
        "header": ["approval_key": approvalKey, "custtype": "P", "tr_type": "1", "content-type": "utf-8"],
        "body": ["input": ["tr_id": trID, "tr_key": symbol]],
    ])
    do { try await task.send(.string(sub)); log("[ws] 구독 송신 (tr_id=\(trID) tr_key=\(symbol))") }
    catch { log("[FAIL] 구독 송신: \(error)"); receiver.cancel(); return 1 }

    // 5) 예산시간 폴링 — 첫 체결 시 조기 종료
    let deadline = Date().addingTimeInterval(receiveBudgetSeconds)
    while Date() < deadline {
        if await state.realCount > 0 { break }
        try? await Task.sleep(nanoseconds: 400_000_000)
    }
    receiver.cancel()
    task.cancel(with: .goingAway, reason: nil)

    // 6) 요약
    let subOK = await state.subOK, realCount = await state.realCount, msgCount = await state.msgCount
    log("\n=== 요약 ===")
    log("구독 OK : \(subOK)")
    log("총 수신 메시지: \(msgCount)건 (구독응답·PINGPONG 포함)")
    log("체결 수신: \(realCount)건")
    if realCount > 0 {
        log("판정: ✅ KIS WS 체결 시세 수신 확인 — 위 필드 index로 [2] 파서 위치 맵 확정")
        return 0
    } else if subOK {
        log("판정: 🟡 연결·구독 OK, 체결 무수신 — 장 마감/한산 추정. 장중 재실행 권장")
        return 2
    } else {
        log("판정: ❌ 접속/구독 실패 (ws 차단·envelope·approval_key 점검). ws 평문 차단 시 'ws' 인자로 재시도")
        return 1
    }
}

let code = await run()
exit(code)
