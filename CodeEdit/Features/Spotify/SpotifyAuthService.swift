//
//  SpotifyAuthService.swift
//  CodeEdit
//

import AppKit
import AuthenticationServices

/// Runs the Spotify Authorization-Code-with-PKCE flow, persists tokens in the Keychain, and
/// vends a valid access token (refreshing when needed).
@MainActor
final class SpotifyAuthService: NSObject {
    private let keychain = CodeEditKeychain()
    private var session: ASWebAuthenticationSession?

    private(set) var tokens: SpotifyTokens? {
        didSet { persist() }
    }

    override init() {
        super.init()
        if let raw = keychain.get(SpotifyConfiguration.keychainKey),
           let data = raw.data(using: .utf8),
           let stored = try? JSONDecoder().decode(SpotifyTokens.self, from: data) {
            self.tokens = stored
        }
    }

    var isAuthorized: Bool { tokens != nil }

    /// Interactive login. Throws on user cancel or token-exchange failure.
    func authorize() async throws {
        let verifier = SpotifyPKCE.makeVerifier()
        let challenge = SpotifyPKCE.challenge(for: verifier)
        let state = UUID().uuidString

        var comps = URLComponents(url: SpotifyConfiguration.authorizeURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "client_id", value: SpotifyConfiguration.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: SpotifyConfiguration.redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "state", value: state),
            .init(name: "scope", value: SpotifyConfiguration.scopes.joined(separator: " "))
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: comps.url!,
                callbackURLScheme: SpotifyConfiguration.callbackScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? SpotifyError.notAuthorized)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            // If the session can't present (no anchor / already presenting), the completion
            // handler never fires — resume here so `authorize()` doesn't hang forever.
            if !session.start() {
                continuation.resume(throwing: SpotifyError.notAuthorized)
            }
        }

        guard let code = SpotifyAuthCallback.code(from: callbackURL, expectedState: state) else {
            throw SpotifyError.notAuthorized
        }
        try await exchange(code: code, verifier: verifier)
    }

    func logout() {
        tokens = nil
        keychain.delete(SpotifyConfiguration.keychainKey)
    }

    /// A valid access token, refreshing first if it is expiring.
    func validAccessToken() async throws -> String {
        guard var current = tokens else { throw SpotifyError.notAuthorized }
        if current.shouldRefresh() {
            current = try await refresh(current)
        }
        return current.accessToken
    }

    // MARK: - Token endpoints

    private func exchange(code: String, verifier: String) async throws {
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfiguration.redirectURI,
            "client_id": SpotifyConfiguration.clientID,
            "code_verifier": verifier
        ]
        let data = try await postForm(body)
        tokens = try SpotifyTokens(responseData: data, refreshFallback: nil)
    }

    @discardableResult
    private func refresh(_ current: SpotifyTokens) async throws -> SpotifyTokens {
        let body = [
            "grant_type": "refresh_token",
            "refresh_token": current.refreshToken,
            "client_id": SpotifyConfiguration.clientID
        ]
        let data = try await postForm(body)
        let refreshed = try SpotifyTokens(responseData: data, refreshFallback: current.refreshToken)
        tokens = refreshed
        return refreshed
    }

    private func postForm(_ fields: [String: String]) async throws -> Data {
        var request = URLRequest(url: SpotifyConfiguration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw SpotifyError.http(http.statusCode)
        }
        return data
    }

    private func persist() {
        guard let tokens, let data = try? JSONEncoder().encode(tokens),
              let raw = String(data: data, encoding: .utf8) else { return }
        keychain.set(raw, forKey: SpotifyConfiguration.keychainKey)
    }
}

extension SpotifyAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? ASPresentationAnchor()
    }
}

extension CharacterSet {
    /// Allowed characters for `application/x-www-form-urlencoded` values.
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
