//
//  SwiftScrobbleApp.swift
//  SwiftScrobble
//
//  Created by Byte Neko on 10/11/2026.
//



import SwiftUI

@main
struct SwiftScrobblerApp: App {
    @StateObject private var monitor = MusicMonitor()
    @StateObject private var scrobbler = ScrobbleManager()
    @StateObject private var authManager = LastFMAuthManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                monitor: monitor,
                scrobbler: scrobbler,
                authManager: authManager
            )
        } label: {
            Image(systemName: "waveform")
                .onAppear {
                    monitor.onPlaybackUpdate = { track in
                        scrobbler.observe(track)
                    }
                    monitor.start()
                }
        }
        .menuBarExtraStyle(.menu)

        Window("SwiftScrobbler Settings", id: "settings") {
            LastFMSettingsView(authManager: authManager)
                .frame(width: 400)
                .padding()
        }
    }
}
