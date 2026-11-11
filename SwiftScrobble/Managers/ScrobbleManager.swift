//
//  ScrobbleManager.swift
//  SwiftScrobble
//
//  Created by Byte Neko on 11/11/2026.
//

import Foundation
import Combine

@MainActor
final class ScrobbleManager: ObservableObject {

    @Published private(set) var currentTrack: Track?
    @Published private(set) var listenedSeconds: Double = 0
    @Published private(set) var isEligible = false

    private let service = LastFMService()
    private let keychain = KeychainManager()

    private var lastSampleTime: TimeInterval?
    private var trackStartTimestamp: Int?
    private var scrobbleSubmitted = false
    private var submissionInProgress = false
    private var lastNowPlayingTrackID: String?

    func observe(_ track: Track?) {
        let now = ProcessInfo.processInfo.systemUptime

        guard let track else {
            reset()
            return
        }

        // A new track has started.
        if currentTrack?.id != track.id {
            currentTrack = track
            listenedSeconds = 0
            isEligible = false
            scrobbleSubmitted = false
            submissionInProgress = false

            lastSampleTime = now
            trackStartTimestamp = Int(Date().timeIntervalSince1970)

            if track.isPlaying {
                updateNowPlaying(track)
            }

            return
        }

        let wasPlaying = currentTrack?.isPlaying == true

        // Count only time spent actively playing.
        if wasPlaying && track.isPlaying,
           let previousTime = lastSampleTime {

            let elapsed = now - previousTime

            if elapsed > 0 && elapsed <= 5 {
                listenedSeconds += elapsed
            }
        }

        lastSampleTime = now
        currentTrack = track

        // Update Now Playing when playback resumes.
        if !wasPlaying && track.isPlaying {
            updateNowPlaying(track)
        }

        checkEligibility()
    }

    private func updateNowPlaying(_ track: Track) {
        guard let sessionKey = keychain.read(key: "session") else {
            return
        }

        guard lastNowPlayingTrackID != track.id else {
            return
        }

        lastNowPlayingTrackID = track.id

        Task {
            do {
                try await service.updateNowPlaying(
                    track: track,
                    sessionKey: sessionKey
                )
                print("Now Playing updated: \(track.artist) - \(track.title)")
            } catch {
                print("Now Playing error: \(error.localizedDescription)")
            }
        }
    }

    private func checkEligibility() {
        guard
            let track = currentTrack,
            track.isValid,
            track.isPlaying,
            !scrobbleSubmitted,
            !submissionInProgress
        else {
            return
        }

        guard listenedSeconds >= track.scrobbleThreshold else {
            return
        }

        guard
            let sessionKey = keychain.read(key: "session"),
            let timestamp = trackStartTimestamp
        else {
            return
        }

        isEligible = true
        submissionInProgress = true

        Task {
            do {
                try await service.scrobble(
                    track: track,
                    timestamp: timestamp,
                    sessionKey: sessionKey
                )

                scrobbleSubmitted = true
                print("Scrobbled: \(track.artist) - \(track.title)")
                print("Listened: \(Int(listenedSeconds)) seconds")

            } catch {
                print("Scrobble error: \(error.localizedDescription)")
            }

            submissionInProgress = false
        }
    }

    private func reset() {
        currentTrack = nil
        listenedSeconds = 0
        isEligible = false
        lastSampleTime = nil
        trackStartTimestamp = nil
        scrobbleSubmitted = false
        submissionInProgress = false
        lastNowPlayingTrackID = nil
    }
}
