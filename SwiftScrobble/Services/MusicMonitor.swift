//
//  MusicMonitor.swift
//  SwiftScrobble
//
//  Created by Byte Neko on 11/11/2026.
//


import Foundation
import AppKit
import Combine

@MainActor
final class MusicMonitor: ObservableObject {

    @Published private(set) var currentTrack: Track?
    @Published private(set) var errorMessage: String?

    // Fires whenever a new track is detected
    var onTrackChanged: ((Track?) -> Void)?
    
    var onPlaybackUpdate: ((Track?) -> Void)?

    private var pollingTask: Task<Void, Never>?

    func start() {
        guard pollingTask == nil else { return }

        refresh()

        pollingTask = Task {
            while !Task.isCancelled {

                try? await Task.sleep(
                    nanoseconds: 2_000_000_000
                )

                guard !Task.isCancelled else { break }

                refresh()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() {

        let script = """
        if application "Music" is not running then
            return ""
        end if

        tell application "Music"
            if player state is stopped then
                return ""
            end if

            set t to current track

            set trackData to (name of t as text) & "||" & (artist of t as text) & "||" & (album of t as text) & "||" & (duration of t as text) & "||" & (player position as text) & "||" & (player state as text)

            return trackData
        end tell
        """

        guard let appleScript = NSAppleScript(
            source: script
        ) else {
            errorMessage = "Could not create AppleScript."
            return
        }

        var error: NSDictionary?

        let result = appleScript.executeAndReturnError(&error)

        if let error {
            errorMessage = error.description
            return
        }

        guard let output = result.stringValue,
              !output.isEmpty else {
            updateTrack(nil)
            onPlaybackUpdate?(nil)
            errorMessage = nil
            return
        }

        let components = output.components(
            separatedBy: "||"
        )

        guard components.count == 6,
              let durationSeconds = Double(components[3]),
              let position = Double(components[4]) else {
            errorMessage = "Invalid track information."
            return
        }

        // Apple Music reports duration in milliseconds.
        let duration = durationSeconds

        let track = Track(
            title: components[0],
            artist: components[1],
            album: components[2],
            duration: duration,
            position: position,
            isPlaying: components[5] == "playing"
        )

        updateTrack(track)
        onPlaybackUpdate?(track)
        errorMessage = nil
    }

    private func updateTrack(_ newTrack: Track?) {

        let previousTrackID = currentTrack?.id
        let newTrackID = newTrack?.id

        currentTrack = newTrack

        if previousTrackID != newTrackID {
            onTrackChanged?(newTrack)
        }
    }

    deinit {
        pollingTask?.cancel()
    }
}
