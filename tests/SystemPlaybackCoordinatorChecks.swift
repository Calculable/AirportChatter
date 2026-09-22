// Compile this with AudioCoordinator.swift, SystemPlaybackController.swift, StationRepository.swift,
// Models/Station.swift and Models/PlaybackState.swift (not the real audio players).
import Foundation

@MainActor final class ATCStreamPlayer {
    static var starts = 0
    static var pauses = 0
    var onPlayingChanged: ((Bool) -> Void)?
    var onReadinessChanged: ((Bool) -> Void)?
    var onRecoveryChanged: ((Bool) -> Void)?
    var onFailure: ((String) -> Void)?
    var onConnectivityHint: ((Int?) -> Void)?
    func setVolume(_ value: Double) {}
    func select(station: Station, autoPlay: Bool) { if autoPlay { Self.starts += 1 } }
    func pause() { Self.pauses += 1 }
}
@MainActor final class SoundCloudWebPlayer {
    var onReadyChanged: ((Bool) -> Void)?
    var onPlayingChanged: ((Bool) -> Void)?
    var onFailure: ((String) -> Void)?
    var onRemoteCommand: ((PlaybackCommand) -> Void)?
    var starts = 0, pauses = 0, nexts = 0, previouses = 0
    func setVolume(_ value: Double) {}
    func play() { starts += 1 }
    func pause() { pauses += 1 }
    func next() { nexts += 1 }
    func previous() { previouses += 1 }
}
struct FixtureRepository: StationRepository {
    func loadDefaults() throws -> [Station] { [] }
    func loadUserStations() throws -> [Station] { [] }
    func saveUserStations(_ stations: [Station]) throws {}
    func allStations() throws -> [Station] { [] }
}
@main struct SystemPlaybackCoordinatorChecks {
    @MainActor static func main() {
        let model = AudioCoordinator(stationRepository: FixtureRepository())
        let station = Station(id: "fixture", name: "Fixture", iata: "", code: "fixture", streamURL: URL(string: "https://example.invalid")!, region: "Test", isDefault: false)
        model.stations = [station]
        model.playbackState.selectedStationID = station.id
        model.handlePlaybackCommand(.play)
        precondition(ATCStreamPlayer.starts == 1 && model.soundCloud.starts == 1)
        model.handlePlaybackCommand(.play)
        precondition(ATCStreamPlayer.starts == 1, "Repeated Play must not restart the radio")
        model.soundCloud.onRemoteCommand?(.pause)
        precondition(ATCStreamPlayer.pauses == 1 && model.soundCloud.pauses == 1)
        precondition(!model.playbackState.isPlaying)
        model.soundCloud.onRemoteCommand?(.play)
        precondition(ATCStreamPlayer.starts == 2 && model.playbackState.isPlaying)
        model.handlePlaybackCommand(.pause)
        model.handlePlaybackCommand(.pause)
        precondition(!model.playbackState.isPlaying, "Repeated Pause must never toggle playback on")
        model.handlePlaybackCommand(.next)
        model.handlePlaybackCommand(.previous)
        precondition(model.soundCloud.nexts == 1 && model.soundCloud.previouses == 1)
        print("Native and web system commands control both players; repeated commands are idempotent.")
    }
}
