//
//  ClaudeUsageEndpointClient.swift
//  CodeEdit
//

import Foundation
import Security

/// Fetches Claude usage from the (undocumented) OAuth usage endpoint, used as a
/// fallback when no live statusline data is available.
enum ClaudeUsageEndpointClient {
    enum ClientError: Error { case noToken, badResponse }

    /// Reads the Claude Code OAuth access token from the macOS Keychain.
    static func accessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let oauth = object["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String {
            return token
        }
        return object["accessToken"] as? String
    }

    static func fetchUsage() async throws -> ClaudeUsage {
        guard let token = accessToken() else { throw ClientError.noToken }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // NOTE: an anthropic-beta header returns 401; send Authorization only.
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.badResponse
        }
        return try ClaudeUsage(endpointData: data)
    }
}
