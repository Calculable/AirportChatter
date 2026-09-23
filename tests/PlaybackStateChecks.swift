// swiftc TowerLounge/Models/PlaybackState.swift tests/PlaybackStateChecks.swift -o /tmp/playback-checks && /tmp/playback-checks
import Foundation
@main struct PlaybackStateChecks {
    static func main() {
        var state = PlaybackState()
        precondition(!state.shouldPause)
        precondition(state.airportStatus == .paused)
        state.musicPlaying = true
        precondition(state.shouldPause)
        precondition(state.playbackSummary == "Airport: Not playing · Music: Playing")
        state.radioPlaying = true
        precondition(state.airportStatus == .playing)
        precondition(state.playbackSummary == "Airport: Playing · Music: Playing")
        state.musicPlaying = false
        precondition(state.shouldPause)
        state.radioPlaying = false
        state.isPlaying = true
        precondition(state.airportStatus == .waiting)
        state.radioReconnecting = true
        precondition(state.airportStatus == .waiting, "Initial connection attempts are not reconnections")
        state.radioHasPlayedSelection = true
        precondition(state.airportStatus == .reconnecting)
        state.radioHasPlayedSelection = false
        precondition(state.airportStatus == .waiting, "Switching stations starts a fresh connection")
        state.radioReconnecting = false
        state.radioError = "Network unavailable"
        precondition(state.airportStatus == .error)
        state.radioError = nil
        precondition(state.airportStatus == .waiting)
        precondition(state.shouldPause) // A second tap cancels a pending start.
        state.isPlaying = false
        precondition(!state.shouldPause)
        print("Combined playback and airport status checks passed.")
    }
}
