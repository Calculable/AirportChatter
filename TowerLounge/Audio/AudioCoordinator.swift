import Foundation
import Observation

#if os(iOS)
import AVFoundation
#endif

@MainActor
@Observable
final class AudioCoordinator {
    var playbackState = PlaybackState()
    var stations: [Station] = []

    let soundCloud = SoundCloudWebPlayer()

    private let stationRepository: StationRepository
    private let atcPlayer = ATCStreamPlayer()
    private let systemPlayback = SystemPlaybackController()
    private var didStart = false

    private let selectedStationKey = "airport_chatter_selected_station"
    private let radioVolumeKey = "airport_chatter_radio_volume"
    private let lastIntentKey = "airport_chatter_last_intent_playing"

    init() {
        self.stationRepository = LocalStationRepository()
        bindCallbacks()
        configureAudioSession()
    }

    init(stationRepository: StationRepository) {
        self.stationRepository = stationRepository
        bindCallbacks()
        configureAudioSession()
    }

    private func bindCallbacks() {
        systemPlayback.onCommand = { [weak self] command in self?.handlePlaybackCommand(command) }
        soundCloud.onRemoteCommand = { [weak self] command in self?.handlePlaybackCommand(command) }
        soundCloud.onReadyChanged = { [weak self] isReady in
            self?.playbackState.musicReady = isReady
        }

        soundCloud.onPlayingChanged = { [weak self] playing in
            self?.playbackState.musicPlaying = playing
            self?.updateSystemPlayback()
        }
        soundCloud.onFailure = { [weak self] message in
            self?.pausePlayback()
            self?.playbackState.errorBanner = message
        }
        atcPlayer.onPlayingChanged = { [weak self] playing in
            self?.playbackState.radioPlaying = playing
            if playing {
                self?.playbackState.radioHasPlayedSelection = true
                self?.playbackState.radioError = nil
            }
            self?.updateSystemPlayback()
        }

        atcPlayer.onRecoveryChanged = { [weak self] recovering in
            self?.playbackState.radioReconnecting = recovering
        }

        atcPlayer.onReadinessChanged = { [weak self] ready in
            self?.playbackState.radioReady = ready
        }

        atcPlayer.onFailure = { [weak self] message in
            // Radio failures remain inline; music can continue uninterrupted.
            self?.playbackState.radioError = message
            self?.markCurrentStationFailure(message)
        }

        atcPlayer.onConnectivityHint = { [weak self] code in
            self?.updateCurrentStationHealth(reachable: true, responseCode: code, hasRecentAudioEnergy: true)
        }
    }

    var selectedStation: Station? {
        guard let selectedID = playbackState.selectedStationID else { return nil }
        return stations.first(where: { $0.id == selectedID })
    }

    var stationsByRegion: [(region: String, stations: [Station])] {
        let grouped = Dictionary(grouping: stations, by: { $0.region })
        return grouped.keys.sorted().map { key in
            (region: key, stations: grouped[key, default: []].sorted { $0.name < $1.name })
        }
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true

        loadStations()
        restoreState()

        atcPlayer.setVolume(playbackState.radioVolume)

        if playbackState.selectedStationID == nil {
            playbackState.selectedStationID = stations.first?.id
        }

        if let selectedStation {
            atcPlayer.select(station: selectedStation, autoPlay: false)
        }
    }

    func togglePlayback() {
        if playbackState.shouldPause { pausePlayback() }
        else { playPlayback() }
    }

    func handlePlaybackCommand(_ command: PlaybackCommand) {
        switch command {
        case .play: playPlayback()
        case .pause: pausePlayback()
        case .toggle: togglePlayback()
        case .next: nextTrack()
        case .previous: previousTrack()
        }
    }

    private func playPlayback() {
        guard let station = selectedStation else { return }
#if os(iOS)
        do {
            try prepareAudioSession()
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            playbackState.radioError = "Could not start audio: \(error.localizedDescription)"
            return
        }
#endif
        // A repeated system Play command must not restart an already playing station.
        if !playbackState.isPlaying || playbackState.radioError != nil {
            playbackState.radioError = nil
            playbackState.radioHasPlayedSelection = false
            playbackState.isPlaying = true
            atcPlayer.select(station: station, autoPlay: true)
        }
        soundCloud.play()
        persistIntent()
        updateSystemPlayback()
    }

    private func updateSystemPlayback() {
        systemPlayback.update(station: selectedStation?.displayName,
                              playing: playbackState.radioPlaying || playbackState.musicPlaying)
    }

    private func pausePlayback() {
        playbackState.isPlaying = false
        persistIntent()
        atcPlayer.pause()
        soundCloud.pause()
        systemPlayback.update(station: selectedStation?.displayName, playing: false)
    }

    func moveStation(in visibleStations: [Station], forward: Bool) {
        guard let station = adjacentStation(in: visibleStations, selectedID: playbackState.selectedStationID, forward: forward) else { return }
        selectStation(station)
    }

    func retryStation() {
        guard let station = selectedStation else { return }
        if playbackState.isPlaying { selectStation(station) }
        else { togglePlayback() }
    }

    func previousTrack() {
        soundCloud.previous()
    }

    func nextTrack() {
        soundCloud.next()
    }

    func setRadioVolume(_ value: Double) {
        playbackState.radioVolume = value
        atcPlayer.setVolume(value)
        UserDefaults.standard.set(value, forKey: radioVolumeKey)
    }

    func clearErrorBanner() {
        playbackState.errorBanner = nil
    }

    func selectStation(_ station: Station) {
        playbackState.radioHasPlayedSelection = false
        playbackState.radioReconnecting = false
        playbackState.radioError = nil
        playbackState.radioPlaying = false
        playbackState.selectedStationID = station.id
        UserDefaults.standard.set(station.id, forKey: selectedStationKey)

        atcPlayer.select(station: station, autoPlay: playbackState.isPlaying)
        updateSystemPlayback()
    }

    private func updateCurrentStationHealth(reachable: Bool, responseCode: Int?, hasRecentAudioEnergy: Bool) {
        guard let selectedID = playbackState.selectedStationID,
              let index = stations.firstIndex(where: { $0.id == selectedID }) else {
            return
        }

        stations[index].lastHealth = StationHealthResult(
            stationID: selectedID,
            reachable: reachable,
            responseCode: responseCode,
            hasRecentAudioEnergy: hasRecentAudioEnergy,
            checkedAt: Date()
        )

        if reachable {
            stations[index].lastError = nil
        }
    }

    private func markCurrentStationFailure(_ message: String) {
        guard let selectedID = playbackState.selectedStationID,
              let index = stations.firstIndex(where: { $0.id == selectedID }) else {
            return
        }

        stations[index].lastError = message
        stations[index].lastHealth = StationHealthResult(
            stationID: selectedID,
            reachable: false,
            responseCode: nil,
            hasRecentAudioEnergy: false,
            checkedAt: Date()
        )
    }

    private func loadStations() {
        do {
            stations = try stationRepository.allStations()
        } catch {
            playbackState.errorBanner = "Could not load station list: \(error.localizedDescription)"
            stations = []
        }
    }

    private func restoreState() {
        let defaults = UserDefaults.standard

        let savedRadio = defaults.double(forKey: radioVolumeKey)
        playbackState.radioVolume = savedRadio == 0 ? 0.5 : savedRadio

        playbackState.selectedStationID = defaults.string(forKey: selectedStationKey)

        // Intentionally start paused even if the last intent was playing.
        playbackState.isPlaying = false
    }

    private func persistIntent() {
        UserDefaults.standard.set(playbackState.isPlaying, forKey: lastIntentKey)
    }

#if os(iOS)
    private func prepareAudioSession() throws {
        // The native player and WebKit use separate audio sessions. Without mixing,
        // starting either can interrupt the other and trigger our shared Pause command.
        // Do not force long-form routing: it does not combine these two players.
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,
                                                       policy: .default, options: [.mixWithOthers])
    }
#endif

    private func configureAudioSession() {
#if os(iOS)
        do {
            try prepareAudioSession()

            NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self,
                          let info = notification.userInfo,
                          let rawValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                          let interruptionType = AVAudioSession.InterruptionType(rawValue: rawValue) else {
                        return
                    }

                    if interruptionType == .began {
                        self.pausePlayback()
                    }
                }
            }
        } catch {
            playbackState.errorBanner = "Audio session error: \(error.localizedDescription)"
        }
#endif
    }
}
