//
//  Track.swift
//  SwiftScrobble
//
//  Created by Byte Neko on 11/11/2026.
//


import Foundation

struct Track: Identifiable, Equatable {

    let title: String
    let artist: String
    let album: String

    // All times are measured in seconds
    let duration: Double
    let position: Double

    let isPlaying: Bool

    var id: String {
        "\(artist)-\(title)-\(album)"
    }

    // Last.fm's minimum listening threshold
    var scrobbleThreshold: Double {
        min(duration / 2, 240)
    }

    var isValid: Bool {
        !title.isEmpty &&
        !artist.isEmpty &&
        duration > 30
    }
}
