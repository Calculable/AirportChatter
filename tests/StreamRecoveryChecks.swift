// swiftc AirportChatter/Models/Station.swift AirportChatter/Audio/ATCStreamPlayer.swift tests/StreamRecoveryChecks.swift -o /tmp/recovery-checks && /tmp/recovery-checks
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
        print("Bounded retries, exhaustion, pause cancellation, and stale station checks passed.")
    }
}
