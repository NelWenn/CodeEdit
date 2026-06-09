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

    /// Cached so the Keychain is read at most once per launch (each read can prompt the user).
    /// Cleared on a 401 so an expired token is re-read on the next request.
    private static var cachedToken: String?

    /// Reads the Claude Code OAuth access token from the macOS Keychain (cached after the first read).
    static func accessToken() -> String? {
        if let cachedToken {
            return cachedToken
        }
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
        let token: String?
        if let oauth = object["claudeAiOauth"] as? [String: Any] {
            token = oauth["accessToken"] as? String
        } else {
            token = object["accessToken"] as? String
        }
        cachedToken = token
        return token
    }

    static func fetchUsage() async throws -> ClaudeUsage {
        guard let token = accessToken() else { throw ClientError.noToken }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // NOTE: an anthropic-beta header returns 401; send Authorization only.
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.badResponse }
        if http.statusCode == 401 {
            cachedToken = nil // expired -> re-read the Keychain next time
        }
        guard (200..<300).contains(http.statusCode) else { throw ClientError.badResponse }
        return try ClaudeUsage(endpointData: data)
    }
}
