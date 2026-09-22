# Shared system playback experiment

This branch keeps the SoundCloud widget; no SoundCloud API credentials or native audio extraction are used.

- Native remote commands and the widget's Media Session play/pause actions forward to the same coordinator. Play and Pause are explicit, idempotent operations; next/previous select music tracks.
- The widget bridge accepts media-session commands only from the `w.soundcloud.com` security origin. The existing audio-state bridge remains restricted to the main document. It installs at document start and preserves shared transport handlers when the widget later registers or clears its own handlers; otherwise late registrations can restore music-only lock-screen controls.
- The iOS session uses `.playback`, default routing, and `.mixWithOthers` at startup and before Play. Native playback and WebKit need to coexist; the nonmixable long-form session introduced in the experiment could interrupt the other player and immediately trigger shared Pause. The forced initial long-form policy has been removed. Background audio remains enabled.
- The button below the main play control is an app-level AirPlay route picker.

This coordinates two players. It does not create one mixed audio stream, and WebKit/SoundCloud still control their own playback implementation.

The route picker does not guarantee that both sources reach the same AirPlay receiver. Restoring simultaneous playback takes priority over forcing a route-sharing policy that interrupts playback.

AirPlay follow-up (2026-09-22): tested `.playback` + `.longFormAudio` + `.mixWithOthers` in the iOS 27 simulator. `setCategory` rejected the combination with OSStatus -50; the fallback to default routing retained mixing. The trial and diagnostic logging were removed. This does not establish behavior on every physical device, but provides no validated simple routing fix for the current WebKit/native combination.

## Validation

Mac and iOS simulator builds passed. The simulator launched without an audio-session alert and displayed the route picker. Tests cover widget media-session forwarding, native/web command convergence, repeated Play/Pause, and next/previous forwarding. Built Info.plist values were checked.

Physical-device verification remains required: start both sources, choose an AirPlay receiver from the app-level picker, verify both are audible on it, lock the device, pause and resume, then disconnect AirPlay. Repeat while the airport stream is reconnecting. A simulator cannot establish real receiver routing or locked-device web-process behavior.

Run bridge tests with `node tests/SystemPlaybackBridgeChecks.js`. Compile coordinator tests on macOS with:

```sh
xcrun swiftc AirportChatter/Audio/AudioCoordinator.swift AirportChatter/Audio/SystemPlaybackController.swift AirportChatter/Data/StationRepository.swift AirportChatter/Models/Station.swift AirportChatter/Models/PlaybackState.swift tests/SystemPlaybackCoordinatorChecks.swift -o /tmp/system-playback-checks
/tmp/system-playback-checks
```

Checkpoint before this experiment: `3452133` on `main`. The local station catalog is ignored and retained in place across branch switches.
