import AVFoundation
import Foundation

@MainActor
final class ATCStreamPlayer {
    let player = AVPlayer()
    var onPlayingChanged: ((Bool) -> Void)?
    var onReadinessChanged: ((Bool) -> Void)?
    var onRecoveryChanged: ((Bool) -> Void)?
    var onFailure: ((String) -> Void)?
    var onConnectivityHint: ((Int?) -> Void)?

    private var station: Station?
    private var wantsPlayback = false
    private var attempts = 0
    private var hasPlayedCurrentItem = false
    private var playbackObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var notifications: [NSObjectProtocol] = []
    private var recoveryTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var stableTask: Task<Void, Never>?

    private let retryDelays: [Duration]
    private let connectionTimeout: Duration
    private let stablePlaybackWindow: Duration

    init(retryDelays: [Duration] = [.seconds(4), .seconds(8), .seconds(16), .seconds(30)],
         connectionTimeout: Duration = .seconds(25), stablePlaybackWindow: Duration = .seconds(30)) {
        self.retryDelays = retryDelays
        self.connectionTimeout = connectionTimeout
        self.stablePlaybackWindow = stablePlaybackWindow
        player.automaticallyWaitsToMinimizeStalling = true
    }

    deinit {
        notifications.forEach(NotificationCenter.default.removeObserver)
        recoveryTask?.cancel()
        timeoutTask?.cancel()
        stableTask?.cancel()
    }

    func setVolume(_ value: Double) { player.volume = Float(max(0, min(1, value))) }

    func pause() {
        wantsPlayback = false
        cancelTasks()
        player.pause()
        onRecoveryChanged?(false)
    }

    func select(station: Station, autoPlay: Bool) {
        cancelTasks()
        self.station = station
        wantsPlayback = autoPlay
        attempts = 0
        onRecoveryChanged?(false)
        loadStation()
    }

    private func cancelTasks() {
        recoveryTask?.cancel(); recoveryTask = nil
        timeoutTask?.cancel(); timeoutTask = nil
        stableTask?.cancel(); stableTask = nil
    }

    private func loadStation() {
        guard let station else { return }
        timeoutTask?.cancel()
        // Stop observing the old item before replacing it. AVPlayer's playing
        // state can outlive that item, and already queued callbacks can arrive
        // after a station switch.
        playbackObservation = nil
        player.pause()
        onReadinessChanged?(false)
        onPlayingChanged?(false)
        notifications.forEach(NotificationCenter.default.removeObserver)
        notifications.removeAll()
        statusObservation = nil
        hasPlayedCurrentItem = false
        let item = AVPlayerItem(url: station.streamURL)
        player.replaceCurrentItem(with: item)
        playbackObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player.currentItem === item else { return }
                self.playbackChanged()
            }
        }
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player.currentItem === item else { return }
                switch item.status {
                case .readyToPlay: self.onReadinessChanged?(true)
                case .failed: self.handleFailure(item.error, item: item)
                default: self.onReadinessChanged?(false)
                }
            }
        }
        observe(.AVPlayerItemPlaybackStalled, item: item) { owner in
            owner.scheduleRecovery("The station is not sending audio.")
        }
        observe(.AVPlayerItemFailedToPlayToEndTime, item: item) { owner in
            owner.handleFailure(item.error, item: item)
        }
        observe(.AVPlayerItemDidPlayToEndTime, item: item) { owner in
            owner.scheduleRecovery("The live stream ended.")
        }
        observe(.AVPlayerItemNewAccessLogEntry, item: item) { owner in
            owner.onConnectivityHint?(nil)
        }
        guard wantsPlayback else { return }
        player.play()
        // Readiness alone does not mean that audio has actually started.
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.connectionTimeout ?? .seconds(25))
            guard !Task.isCancelled, let self, self.player.currentItem === item,
                  self.player.timeControlStatus != .playing else { return }
            self.scheduleRecovery("The station did not start playing.")
        }
    }

    private func observe(_ name: Notification.Name, item: AVPlayerItem, action: @escaping @MainActor (ATCStreamPlayer) -> Void) {
        notifications.append(NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.player.currentItem === item else { return }
                action(self)
            }
        })
    }

    private func playbackChanged() {
        let playing = player.timeControlStatus == .playing
            && player.currentItem?.status == .readyToPlay && wantsPlayback
        onPlayingChanged?(playing)
        if playing {
            hasPlayedCurrentItem = true
            recoveryTask?.cancel(); recoveryTask = nil
            timeoutTask?.cancel(); timeoutTask = nil
            onRecoveryChanged?(false)
            onReadinessChanged?(true)
            if stableTask == nil {
                stableTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: self?.stablePlaybackWindow ?? .seconds(30))
                    guard !Task.isCancelled, let self else { return }
                    self.attempts = 0
                    self.stableTask = nil
                }
            }
        } else {
            stableTask?.cancel(); stableTask = nil
            if wantsPlayback && hasPlayedCurrentItem && player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                // Let AVPlayer buffer first; reconnect only if it remains stuck.
                scheduleRecovery("The station is taking too long to resume.")
            }
        }
    }

    private func handleFailure(_ error: Error?, item: AVPlayerItem) {
        guard wantsPlayback else { return }
        let status = item.errorLog()?.events.last?.errorStatusCode ?? 0
        if [401, 403, 404, 410, 429].contains(status) {
            finishRecovery(status == 429 ? "Station busy. Please wait before retrying." : "Station unavailable (HTTP \(status)).")
        } else {
            scheduleRecovery(error?.localizedDescription ?? "Station connection lost.")
        }
    }

    private func scheduleRecovery(_ message: String) {
        guard wantsPlayback, recoveryTask == nil else { return }
        timeoutTask?.cancel(); timeoutTask = nil
        onRecoveryChanged?(true)
        recoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.wantsPlayback && !Task.isCancelled {
                guard self.attempts < self.retryDelays.count else {
                    self.finishRecovery("\(message) Try again or choose another station.")
                    return
                }
                let delay = self.retryDelays[self.attempts]
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, self.wantsPlayback else { return }
                if self.player.timeControlStatus == .playing {
                    self.onRecoveryChanged?(false)
                    self.recoveryTask = nil
                    return
                }
                self.attempts += 1
                self.loadStation()
                try? await Task.sleep(for: self.connectionTimeout)
                guard !Task.isCancelled else { return }
            }
        }
    }

    private func finishRecovery(_ message: String) {
        wantsPlayback = false
        cancelTasks()
        player.pause()
        onPlayingChanged?(false)
        onReadinessChanged?(false)
        onRecoveryChanged?(false)
        onFailure?(message)
    }
}
