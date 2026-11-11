//
//  MenuBarView.swift
//  SwiftScrobble
//
//  Created by Byte Neko on 11/11/2026.
//

import SwiftUI
import AppKit

struct MenuBarView: View {

    @ObservedObject var monitor: MusicMonitor
    @ObservedObject var scrobbler: ScrobbleManager
    @ObservedObject var authManager: LastFMAuthManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        
        Group {
            if let username = authManager.username {
                Label(username, systemImage: "person.crop.circle")
                Text("Connected to Last.fm")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            } else if authManager.isAuthorizing {
                Button("I've authorised SwiftScrobbler") {
                    Task {
                        await authManager.checkAuthorization()
                    }
                }

                Text("Waiting for Last.fm authorisation...")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            } else {
                Button("Connect to Last.fm") {
                    Task {
                        await authManager.beginAuthorization()
                    }
                }
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            LastFMSettingsView(authManager: authManager)
        }

        Group {

            if let track = monitor.currentTrack {

                VStack(alignment: .leading, spacing: 6) {

                    Text(track.title)
                        .font(.headline)

                    Text(track.artist)
                        .foregroundStyle(.secondary)

                    Text(track.album)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    Label(
                        track.isPlaying ? "Playing" : "Paused",
                        systemImage: track.isPlaying
                            ? "play.fill"
                            : "pause.fill"
                    )

                    Text(
                        "Position: \(Int(track.position)) / \(Int(track.duration)) sec"
                    )
                    .font(.caption)

                    Text(
                        "Listened: \(Int(scrobbler.listenedSeconds)) sec"
                    )
                    .font(.caption)

                    if scrobbler.isEligible {
                        Label(
                            "Ready to scrobble",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                    }
                }

            } else {

                Text("Nothing playing")
                    .foregroundStyle(.secondary)
            }

            if let error = monitor.errorMessage {
                Divider()

                Text(error)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Divider()
            
            Button("Settings...") {
                openWindow(id: "settings")
            }

            Button("Refresh") {
                monitor.refresh()
            }

            Button("Quit SwiftScrobbler") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
    }
}
