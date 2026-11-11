//
//  Untitled.swift
//  SwiftScrobble
//
//  Created by Byte Neko on 11/11/2026.
//


import SwiftUI

struct LastFMSettingsView: View {

    @ObservedObject var authManager: LastFMAuthManager

    @State private var apiKey = ""
    @State private var sharedSecret = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Last.fm API Credentials")
                .font(.headline)

            TextField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            SecureField("Shared Secret", text: $sharedSecret)
                .textFieldStyle(.roundedBorder)

            Button("Save Credentials") {
                saved = authManager.saveCredentials(
                    apiKey: apiKey.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    sharedSecret: sharedSecret.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                )

                if saved {
                    apiKey = ""
                    sharedSecret = ""
                }
            }

            if saved {
                Label("Credentials saved", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Link(
                "Create a Last.fm API account",
                destination: URL(string: "https://www.last.fm/api/account/create")!
            )
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
