//
//  LastFMAuthManager.swift
//  SwiftScrobble
//
//  Created by Byte Neko on 11/11/2026.
//

import Foundation
import AppKit
import Combine

@MainActor
final class LastFMAuthManager: ObservableObject {

    @Published private(set) var isAuthorizing = false
    @Published private(set) var username: String?
    @Published private(set) var errorMessage: String?

    private let service = LastFMService()
    private let keychain = KeychainManager()

    private var authToken: String?

    init() {
        username = keychain.read(key: "username")
    }

    var sessionKey: String? {
        keychain.read(key: "session")
    }

    func beginAuthorization() async {
        errorMessage = nil
        isAuthorizing = true

        do {
            let data = try await service.request(
                method: "auth.getToken"
            )

            let response = try JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any]

            guard let token = response?["token"] as? String else {
                throw AuthError.invalidResponse
            }

            authToken = token

            guard let apiKey = service.apiKey else {
                throw AuthError.invalidResponse
            }

            var components = URLComponents(
                string: "https://www.last.fm/api/auth/"
            )!

            components.queryItems = [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "token", value: token)
            ]

            guard let authURL = components.url else {
                throw AuthError.invalidResponse
            }

            NSWorkspace.shared.open(authURL)

        } catch {
            errorMessage = error.localizedDescription
            isAuthorizing = false
        }
    }
    
    func saveCredentials(apiKey: String, sharedSecret: String) -> Bool {
        guard !apiKey.isEmpty, !sharedSecret.isEmpty else {
            errorMessage = "Both API credentials are required."
            return false
        }

        let savedAPIKey = keychain.save(key: "apiKey", value: apiKey)
        let savedSecret = keychain.save(key: "sharedSecret", value: sharedSecret)

        guard savedAPIKey && savedSecret else {
            errorMessage = "Could not save credentials to Keychain."
            return false
        }

        errorMessage = nil
        return true
    }

    var hasCredentials: Bool {
        service.apiKey != nil &&
        keychain.read(key: "sharedSecret") != nil
    }

    func checkAuthorization() async {
        guard let token = authToken else {
            errorMessage = "Please start authorization first."
            return
        }

        do {
            let data = try await service.request(
                method: "auth.getSession",
                parameters: ["token": token]
            )

            let response = try JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any]

            guard
                let session = response?["session"] as? [String: Any],
                let sessionKey = session["key"] as? String,
                let name = session["name"] as? String
            else {
                throw AuthError.invalidResponse
            }

            guard
                keychain.save(key: "session", value: sessionKey),
                keychain.save(key: "username", value: name)
            else {
                throw AuthError.keychainFailure
            }

            username = name
            authToken = nil
            isAuthorizing = false

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private enum AuthError: LocalizedError {
        case invalidResponse
        case keychainFailure

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Last.fm returned an unexpected response."
            case .keychainFailure:
                return "Could not save your Last.fm credentials to Keychain."
            }
        }
    }
}
