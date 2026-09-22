import Foundation
#if os(iOS)
import MediaPlayer
#endif

enum PlaybackCommand: String {
    case play, pause, toggle, next, previous
}

/// Owns the app's system controls; the widget's media-session bridge forwards here too.
@MainActor
final class SystemPlaybackController {
    var onCommand: ((PlaybackCommand) -> Void)?
#if os(iOS)
    private var targets: [(MPRemoteCommand, Any)] = []

    init() {
        let center = MPRemoteCommandCenter.shared()
        bind(center.playCommand, to: .play)
        bind(center.pauseCommand, to: .pause)
        bind(center.stopCommand, to: .pause)
        bind(center.togglePlayPauseCommand, to: .toggle)
        bind(center.nextTrackCommand, to: .next)
        bind(center.previousTrackCommand, to: .previous)
        center.changePlaybackPositionCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
    }

    deinit {
        for (command, target) in targets { command.removeTarget(target) }
    }

    private func bind(_ command: MPRemoteCommand, to action: PlaybackCommand) {
        command.isEnabled = true
        let target = command.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onCommand?(action) }
            return .success
        }
        targets.append((command, target))
    }
#endif

    func update(station: String?, playing: Bool) {
#if os(iOS)
        guard let station else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: station,
            MPMediaItemPropertyArtist: "Airport radio + SoundCloud",
            MPMediaItemPropertyAlbumTitle: "AirportChatter",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
#endif
    }
}
