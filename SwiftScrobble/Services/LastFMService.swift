//
//  LastFMService.swift
//  SwiftScrobble
//
//  Created by Byte Neko on 11/11/2026.
//

import Foundation
import CommonCrypto

final class LastFMService {
    
    private let keychain = KeychainManager()

    var apiKey: String? {
        keychain.read(key: "apiKey")
    }

    private func generateSignature(
        parameters: [String: String],
        sharedSecret: String
    ) -> String {
        let signatureString = parameters.keys.sorted()
            .map { "\($0)\(parameters[$0]!)" }
            .joined() + sharedSecret

        let data = Data(signatureString.utf8)

        var digest = [UInt8](
            repeating: 0,
            count: Int(CC_MD5_DIGEST_LENGTH)
        )

        data.withUnsafeBytes { buffer in
            _ = CC_MD5(
                buffer.baseAddress,
                CC_LONG(data.count),
                &digest
            )
        }

        return digest.map {
            String(format: "%02x", $0)
        }.joined()
    }

    func request(
        method: String,
        parameters: [String: String] = [:]
    ) async throws -> Data {

        guard
            let apiKey = keychain.read(key: "apiKey"),
            let sharedSecret = keychain.read(key: "sharedSecret")
        else {
            throw LastFMError.missingCredentials
        }

        var params = parameters
        params["method"] = method
        params["api_key"] = apiKey
        params["api_sig"] = generateSignature(
            parameters: params,
            sharedSecret: sharedSecret
        )
        params["format"] = "json"

        var request = URLRequest(url: URL(string: "https://ws.audioscrobbler.com/2.0/")!)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )

        var components = URLComponents()
        components.queryItems = params.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }

        request.httpBody = components.percentEncodedQuery?.data(
            using: .utf8
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        if let json = try? JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any],
           let error = json["error"] as? Int,
           let message = json["message"] as? String {
            throw LastFMError.apiError(error, message)
        }

        return data
    }


    // Update the currently playing track on Last.fm.
    func updateNowPlaying(
        track: Track,
        sessionKey: String
    ) async throws {

        let parameters = [
            "artist": track.artist,
            "track": track.title,
            "album": track.album,
            "duration": String(Int(track.duration)),
            "sk": sessionKey
        ]

        _ = try await request(
            method: "track.updateNowPlaying",
            parameters: parameters
        )
    }

    // Submit a completed scrobble to Last.fm.
    func scrobble(
        track: Track,
        timestamp: Int,
        sessionKey: String
    ) async throws {

        let parameters = [
            "artist": track.artist,
            "track": track.title,
            "album": track.album,
            "duration": String(Int(track.duration)),
            "timestamp": String(timestamp),
            "sk": sessionKey
        ]

        _ = try await request(
            method: "track.scrobble",
            parameters: parameters
        )
    }

    private enum LastFMError: LocalizedError {
        case apiError(Int, String)
        case missingCredentials

        var errorDescription: String? {
            switch self {
            case .apiError(let code, let message):
                return "Last.fm error \(code): \(message)"
            case .missingCredentials:
                return "Please enter your Last.fm API credentials."
            }
        }
    }
}
