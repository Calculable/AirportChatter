import Foundation

struct PlaybackState {
    // Requested playback is separate from the two players' observed state.
    var isPlaying = false
    var radioReconnecting = false
    var radioHasPlayedSelection = false
    var radioError: String?
    var airportStatus: AirportStreamStatus {
        if radioError != nil { return .error }
        if radioPlaying { return .playing }
        if radioReconnecting && radioHasPlayedSelection { return .reconnecting }
        if isPlaying { return .waiting }
        return .paused
    }
    var radioPlaying = false
    var musicPlaying = false
    var shouldPause: Bool { isPlaying || radioPlaying || musicPlaying }
    var playbackSummary: String {
        let radio = radioPlaying ? "Playing" : "Not playing"
        let music = musicPlaying ? "Playing" : "Not playing"
        return "Airport: \(radio) · Music: \(music)"
    }
    var selectedStationID: String?
    var radioVolume: Double = 0.5
    var musicReady = false
    var radioReady = false
    var errorBanner: String?
}

enum AirportStreamStatus: String {
    case playing = "Playing live"
    case reconnecting = "Reconnecting quietly"
    case waiting = "Connecting"
    case paused = "Paused"
    case error = "Stream error"

    var symbol: String {
        switch self {
        case .playing: return "waveform"
        case .waiting, .reconnecting: return "antenna.radiowaves.left.and.right"
        case .paused: return "pause.circle"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
