import Foundation
import Security

/// 자격증명 Keychain CRUD 얇은 래퍼(보안 — 평문 저장 금지, DB_SCHEMA §자격증명).
/// 값은 절대 로그·예외 메시지에 노출하지 않는다(Floor 4).
/// 서비스 식별자는 `KiwoomCredential` 상수 사용(PoC와 동일 `kr.co.kiwoom.paragon.*` — 사용자 결정 2026-05-29).
public struct KeychainStore {
    public enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case dataEncodingFailed
    }

    public init() {}

    /// 값 조회. 항목 없으면 nil(에러 아님).
    public func get(service: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataEncodingFailed
        }
        return value
    }

    /// upsert. 기존 항목은 service로 매칭해 in-place 갱신(account 보존), 없으면 추가.
    /// → PoC가 `-a "$USER"`로 넣은 기존 항목도 그대로 갱신·중복 생성 없음.
    public func set(service: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.dataEncodingFailed }
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let updateStatus = SecItemUpdate(match as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError.unexpectedStatus(updateStatus) }
        var add = match
        add[kSecValueData as String] = data
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
    }

    /// 삭제. 없으면 무시(idempotent).
    public func delete(service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

/// 키움 자격증명 Keychain 서비스 식별자(SSOT). PoC·앱 공유 — 마이그레이션 불필요.
public enum KiwoomCredential {
    public static let appKey = "kr.co.kiwoom.paragon.appkey"
    public static let appSecret = "kr.co.kiwoom.paragon.appsecret"
}
