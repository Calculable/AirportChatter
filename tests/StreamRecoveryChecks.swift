// swiftc TowerLounge/Models/Station.swift TowerLounge/Models/PlaybackState.swift TowerLounge/Audio/ATCStreamPlayer.swift tests/StreamRecoveryChecks.swift -o /tmp/recovery-checks && /tmp/recovery-checks
import AVFoundation
import Foundation

@main struct StreamRecoveryChecks {
    @MainActor static func main() async {
        let station = Station(id: "test", name: "Unavailable test stream", iata: "", code: "test", streamURL: URL(fileURLWithPath: "/tmp/airportchatter-missing-\(UUID().uuidString).mp3"), region: "Test", isDefault: false)
        let radio = ATCStreamPlayer(retryDelays: [.milliseconds(20), .milliseconds(20)], connectionTimeout: .milliseconds(50))
        var failures = 0
        var recovering = false
        var loads = 0
        radio.onFailure = { _ in failures += 1 }
        radio.onRecoveryChanged = { recovering = $0 }
        radio.onReadinessChanged = { if !$0 { loads += 1 } }
        radio.select(station: station, autoPlay: true)
        for _ in 0..<100 {
            if failures > 0 { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        precondition(failures == 1, "Recovery must end in one inline failure")
        precondition(!recovering)
        let exhaustedItem = radio.player.currentItem
        try? await Task.sleep(for: .milliseconds(200))
        precondition(radio.player.currentItem === exhaustedItem, "Retries must stop at the limit")
        precondition(failures == 1)
        precondition(loads >= 3, "Initial load plus reconnects must occur")

        radio.select(station: station, autoPlay: true)
        radio.pause()
        let pausedItem = radio.player.currentItem
        try? await Task.sleep(for: .milliseconds(200))
        precondition(radio.player.currentItem === pausedItem, "Pause must cancel reconnection")
        precondition(failures == 1, "Paused items must not raise playback failures")
        radio.select(station: station, autoPlay: true)
        let staleItem = radio.player.currentItem!
        radio.select(station: station, autoPlay: false)
        NotificationCenter.default.post(name: .AVPlayerItemPlaybackStalled, object: staleItem)
        let selectedItem = radio.player.currentItem
        try? await Task.sleep(for: .milliseconds(200))
        precondition(radio.player.currentItem === selectedItem, "Old station events must be ignored")
        precondition(!recovering)

        // Switch away from actual playback, with playback notifications queued,
        // and ensure the new selection never inherits the old playing state.
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("station-switch-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: audioURL) }
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480_000)!
        buffer.frameLength = buffer.frameCapacity
        buffer.floatChannelData![0].initialize(repeating: 0, count: Int(buffer.frameLength))
        do {
            let file = try AVAudioFile(forWriting: audioURL, settings: format.settings)
            try file.write(from: buffer)
        } catch { preconditionFailure("Could not create playback fixture: \(error)") }
        let playable = Station(id: "local", name: "Local audio", iata: "", code: "local", streamURL: audioURL, region: "Test", isDefault: false)
        var state = PlaybackState()
        state.isPlaying = true
        radio.onPlayingChanged = {
            state.radioPlaying = $0
            if $0 { state.radioHasPlayedSelection = true }
        }
        radio.onRecoveryChanged = { state.radioReconnecting = $0 }
        radio.select(station: playable, autoPlay: true)
        for _ in 0..<100 {
            if state.radioPlaying { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        precondition(state.radioPlaying, "Fixture must start playing before switching")
        state.radioHasPlayedSelection = false
        state.radioPlaying = false
        radio.select(station: station, autoPlay: true)
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(10))
            precondition(!state.radioHasPlayedSelection, "New selection must not inherit old playback")
            precondition(state.airportStatus == .waiting, "Switching must show Connecting, including initial retries")
        }
        radio.pause()
        print("Bounded retries, exhaustion, pause cancellation, and stale station checks passed.")
    }
}
