# Shared system playback experiment

This branch keeps the SoundCloud widget; no SoundCloud API credentials or native audio extraction are used.

- Native remote commands and the widget's Media Session play/pause actions forward to the same coordinator. Play and Pause are explicit, idempotent operations; next/previous select music tracks.
- The widget bridge accepts media-session commands only from its `w.soundcloud.com` frame. The existing audio-state bridge remains restricted to the main document.
- The iOS session uses `.playback` with `.longFormAudio`. The initial route policy in Info.plist is also `LongFormAudio`, and background audio remains enabled.
- The button below the main play control is an app-level AirPlay route picker.

This coordinates two players. It does not create one mixed audio stream, and WebKit/SoundCloud still control their own playback implementation.

## Validation

Mac and iOS simulator builds passed. The simulator launched without an audio-session alert and displayed the route picker. Tests cover widget media-session forwarding, native/web command convergence, repeated Play/Pause, and next/previous forwarding. Built Info.plist values were checked.

Physical-device verification remains required: start both sources, choose an AirPlay receiver from the app-level picker, verify both are audible on it, lock the device, pause and resume, then disconnect AirPlay. Repeat while the airport stream is reconnecting. A simulator cannot establish real receiver routing or locked-device web-process behavior.

Run bridge tests with `node tests/SystemPlaybackBridgeChecks.js`. Compile coordinator tests on macOS with:

```sh
xcrun swiftc AirportChatter/Audio/AudioCoordinator.swift AirportChatter/Audio/SystemPlaybackController.swift AirportChatter/Data/StationRepository.swift AirportChatter/Models/Station.swift AirportChatter/Models/PlaybackState.swift tests/SystemPlaybackCoordinatorChecks.swift -o /tmp/system-playback-checks
/tmp/system-playback-checks
```

Checkpoint before this experiment: `3452133` on `main`. The local station catalog is ignored and retained in place across branch switches.
