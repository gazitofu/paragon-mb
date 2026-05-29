#!/usr/bin/env swift
//
// kiwoom-ws-poc.swift — Premise #1 검증 PoC
//
// 목적: "표준 키움 키로 별도 신청·요금 없이 WebSocket 실시간 체결(0B)을 수신할 수 있는가"
//       를 실측한다 (PARAGON-MB 최대 리스크 / handoff ★Premise #1).
//
// 흐름: Keychain 자격증명 로드 → OAuth 토큰 발급(REST) → WS 접속 → LOGIN → REG(0B)
//       → REAL 체결 패킷 수신.
//
// 실행:  swift tools/kiwoom-ws-poc.swift            # 모의(mock), 005930
//        swift tools/kiwoom-ws-poc.swift real        # 실전 도메인
//        swift tools/kiwoom-ws-poc.swift mock 000660 # 종목 지정
//
// 종료 코드:
//   0 = REAL 체결 수신 성공            → Premise #1 완전 검증
//   2 = WS+LOGIN+REG 성공, REAL 무수신 → 연결성은 입증(장 마감/거래 한산 추정)
//   1 = 실패(토큰/접속/LOGIN/REG 중 하나)
//
// 자격증명은 절대 출력하지 않는다. 외부 의존성 0 (Foundation/Security만).

import Foundation
import Security

// MARK: - 설정

let args = CommandLine.arguments.dropFirst()
let envArg = args.first.map { $0.lowercased() } ?? "mock"
let useMock = envArg != "real"
let symbol = args.dropFirst().first ?? "005930"
let receiveBudgetSeconds: TimeInterval = 25

// 엔드포인트: 사용자 직접 발급·확인(2026-05-29). .NET 래퍼의 mockapi.kiwoom.com 은 outdated.
// REST token: 실전 api.kiwoom.com / 모의 api.kiwoom.com:9443.  WS: 실전·모의 공통(모의 구분은 토큰에 내재).
let restBase = useMock ? "https://api.kiwoom.com:9443" : "https://api.kiwoom.com"
let wsURLString = "wss://api.kiwoom.com:10000/api/dostk/websocket"

let appkeyService = "kr.co.kiwoom.paragon.appkey"
let secretService = "kr.co.kiwoom.paragon.appsecret"

func log(_ s: String) { print(s); fflush(stdout) }

enum PoCError: Error, CustomStringConvertible {
    case message(String)
    var description: String { if case .message(let m) = self { return m }; return "unknown" }
}

// MARK: - Keychain (앱의 AuthService와 동일 경로를 검증)

func keychainValue(service: String) throws -> String {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess else {
        throw PoCError.message("Keychain 조회 실패 (\(service)): OSStatus \(status)")
    }
    guard let data = item as? Data,
          let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !str.isEmpty
    else {
        throw PoCError.message("Keychain 값 디코드 실패 (\(service))")
    }
    return str
}

// MARK: - OAuth 토큰

struct TokenResponse: Decodable {
    let token: String?
    let token_type: String?
    let expires_dt: String?
    let return_code: Int?
    let return_msg: String?
}

func fetchToken(appkey: String, secret: String) async throws -> String {
    var req = URLRequest(url: URL(string: "\(restBase)/oauth2/token")!)
    req.httpMethod = "POST"
    req.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
    let body: [String: String] = [
        "grant_type": "client_credentials",
        "appkey": appkey,
        "secretkey": secret,
    ]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, resp) = try await URLSession.shared.data(for: req)
    let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
    log("[token] HTTP \(code)")

    let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
    if let rc = decoded.return_code, rc != 0 {
        throw PoCError.message("토큰 발급 거부 return_code=\(rc) msg=\(decoded.return_msg ?? "")")
    }
    guard let token = decoded.token, !token.isEmpty else {
        let raw = String(data: data, encoding: .utf8) ?? "<binary>"
        throw PoCError.message("토큰 필드 없음. 원문: \(raw.prefix(300))")
    }
    log("[token] 발급 성공 (expires_dt=\(decoded.expires_dt ?? "?"))")
    return token
}

// MARK: - 수신 상태 (단일 receive 루프 → actor로 안전 공유)

actor PoCState {
    var loginOK = false
    var regOK = false
    var realCount = 0
    var firstRealDump: String?
    func markLogin(_ b: Bool) { loginOK = b }
    func markReg(_ b: Bool) { regOK = b }
    func addReal(_ dump: String) {
        realCount += 1
        if firstRealDump == nil { firstRealDump = dump }
    }
}

// MARK: - JSON 헬퍼

func toJSONString(_ obj: [String: Any]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: obj)
    return String(data: data, encoding: .utf8)!
}

func parse(_ text: String) -> [String: Any]? {
    guard let d = text.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
}

// MARK: - 메인 흐름

func run() async -> Int32 {
    log("=== Kiwoom WS PoC ===")
    log("env=\(useMock ? "MOCK" : "REAL")  symbol=\(symbol)  ws=\(wsURLString)")

    // 1) 자격증명
    let appkey: String, secret: String
    do {
        appkey = try keychainValue(service: appkeyService)
        secret = try keychainValue(service: secretService)
        log("[keychain] appkey/secret 로드 OK (값 비출력)")
    } catch {
        log("[FAIL] \(error)")
        return 1
    }

    // 2) 토큰
    let token: String
    do {
        token = try await fetchToken(appkey: appkey, secret: secret)
    } catch {
        log("[FAIL] 토큰: \(error)")
        return 1
    }

    // 3) WS 접속
    let session = URLSession(configuration: .default)
    let task = session.webSocketTask(with: URL(string: wsURLString)!)
    task.resume()
    log("[ws] connect 시도…")

    let state = PoCState()

    // 4) 단일 수신 루프 (LOGIN 응답 시 REG 송신, PING echo, REAL 집계)
    let receiver = Task {
        while !Task.isCancelled {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await task.receive()
            } catch {
                log("[ws] 수신 종료/오류: \(error)")
                break
            }
            let text: String
            switch message {
            case .string(let s): text = s
            case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
            @unknown default: continue
            }
            guard let json = parse(text), let trnm = json["trnm"] as? String else {
                log("[ws] 비정형 수신: \(text.prefix(200))")
                continue
            }

            switch trnm {
            case "LOGIN":
                let rc = (json["return_code"] as? Int) ?? -1
                let msg = (json["return_msg"] as? String) ?? ""
                log("[ws] LOGIN return_code=\(rc) \(msg)")
                if rc == 0 {
                    await state.markLogin(true)
                    let reg = toJSONString([
                        "trnm": "REG",
                        "grp_no": "1",
                        "refresh": "1",
                        "data": [["item": [symbol], "type": ["0B"]]],
                    ])
                    do {
                        try await task.send(.string(reg))
                        log("[ws] REG 송신 (item=\(symbol) type=0B)")
                    } catch {
                        log("[ws] REG 송신 실패: \(error)")
                    }
                }

            case "REG":
                let rc = (json["return_code"] as? Int) ?? -1
                let msg = (json["return_msg"] as? String) ?? ""
                log("[ws] REG return_code=\(rc) \(msg)")
                await state.markReg(rc == 0)

            case "REAL":
                let dump = text.prefix(500).description
                await state.addReal(dump)
                let n = await state.realCount
                if n == 1 {
                    log("[ws] ★ 첫 REAL 체결 수신:")
                    log("      \(dump)")
                } else {
                    log("[ws] REAL #\(n)")
                }

            case "PING":
                try? await task.send(.string(text)) // 키움 keep-alive echo

            default:
                log("[ws] 기타 trnm=\(trnm): \(text.prefix(200))")
            }
        }
    }

    // 5) LOGIN 패킷 송신
    do {
        try await task.send(.string(toJSONString(["trnm": "LOGIN", "token": token])))
        log("[ws] LOGIN 패킷 송신")
    } catch {
        log("[FAIL] LOGIN 송신: \(error)")
        receiver.cancel()
        return 1
    }

    // 6) 예산 시간 동안 폴링 — 첫 REAL 수신 시 조기 종료
    let deadline = Date().addingTimeInterval(receiveBudgetSeconds)
    while Date() < deadline {
        if await state.realCount > 0 { break }
        try? await Task.sleep(nanoseconds: 400_000_000)
    }

    receiver.cancel()
    task.cancel(with: .goingAway, reason: nil)

    // 7) 요약
    let loginOK = await state.loginOK
    let regOK = await state.regOK
    let realCount = await state.realCount
    log("")
    log("=== 요약 ===")
    log("LOGIN ok : \(loginOK)")
    log("REG ok   : \(regOK)")
    log("REAL 수신: \(realCount)건")

    if realCount > 0 {
        log("판정: ✅ Premise #1 검증 — 표준 키로 WS 실시간 체결 수신 확인")
        return 0
    } else if loginOK && regOK {
        log("판정: 🟡 연결성 입증(LOGIN+REG OK), REAL 무수신 — 장 마감/거래 한산 추정. 장중 재실행 권장")
        return 2
    } else {
        log("판정: ❌ Premise #1 미검증 — WS 핸드셰이크 실패")
        return 1
    }
}

let code = await run()
exit(code)
