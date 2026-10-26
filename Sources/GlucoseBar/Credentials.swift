import Foundation
import Security

enum CredentialError: LocalizedError {
    case invalidToken, keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidToken: return "请输入有效的登录凭证。仅粘贴 token 或完整的 Bearer 值。"
        case .keychain: return "无法访问 macOS 钥匙串，请确认登录钥匙串已解锁后重试。"
        }
    }
}

enum Credentials {
    private static let service = "local.codex.GlucoseBar.sisensing-cn"
    private static let account = "cloud-token"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func normalized(_ input: String) throws -> String {
        var token = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().hasPrefix("bearer ") { token = String(token.dropFirst(7)) }
        token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~+/=")
        guard (16...4096).contains(token.utf8.count), token.unicodeScalars.allSatisfy(allowed.contains) else {
            throw CredentialError.invalidToken
        }
        return token
    }

    static func load() throws -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { throw CredentialError.keychain(status) }
        return token
    }

    static func save(_ token: String) throws {
        let data = Data(try normalized(token).utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "GlucoseBar · 硅基动感"
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw CredentialError.keychain(added) }
        } else if status != errSecSuccess { throw CredentialError.keychain(status) }
    }

    static func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialError.keychain(status) }
    }
}
