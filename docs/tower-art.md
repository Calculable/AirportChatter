# Tower scene

The room is the primary view. The station monitor and radio/music controls begin below it and scroll over the stationary scene, or can be reached with the small handle at the bottom of the scene. Scroll updates are isolated from catalog filtering. Both control pages remain mounted, including SoundCloud, so opening the directory does not replace its player.

## Artwork

Four scenes follow the user's local civil time, independent of the selected station:

- Morning: 05:00–10:59
- Day: 11:00–16:59
- Evening: 17:00–20:59
- Night: 21:00–04:59

Each scene has portrait and landscape artwork. The live scene checks the time each minute, using the current timezone. These are clock-based periods, not location-based sunrise/sunset calculations.

The built-in image-generation tool produced the backgrounds. All eight current asset paths and exact prompts are recorded in [tower-time-art.md](tower-time-art.md). Airport Chatter is painted on the window beam, and the quote is written on a postcard in the artwork. The former two twilight assets have been replaced by this set.

## Interactive objects

- A large physical desk button controls both players. Its adjacent flattened, domed lamp indicates airport-stream status: green for playing, amber for connecting/reconnecting, red for error, unlit for paused. Connecting/reconnecting slowly pulses on a three-second cycle, unless Reduce Motion is enabled. Detailed status remains on the receiver below.
- A brass-rimmed analog clock on the window upright displays local time, including an accessible time value. Tap it to loosen a nail: it swings about an upper-left anchor and settles 18 degrees crooked. This lives in the app's in-memory room session, surviving navigation, scrolling, time-of-day changes and window changes; relaunching resets it. Reduce Motion skips the spring animation.
- The cat rests on the desk with a contact shadow. It briefly stretches, grooms or sits every three minutes, otherwise sleeps. Tapping starts a short run off the desk; it returns after about five seconds and settles again. Reduced Motion replaces running with disappearance/return, and disables periodic animated poses.
- Small planes cross the window about every 40 seconds, taking 19–23 seconds per crossing. Their complete silhouettes and lights fade out before reaching the inward-leaning window posts. They remain clipped inside the window and are decorative, unrelated to the actual station traffic.
- Animation pauses when the app is inactive and respects the system Reduce Motion setting. The old custom sleep/motion toggle has been removed, along with the AirPlay picker. Only the settings button remains in the footer; diagnostics and the personal-use note are inside it.

The radio trace animates at up to 24 fps only while the airport stream is actually playing and the trace is visible in an active app. It becomes a flat line when paused or buffering. Reduce Motion keeps an active trace static. This is decorative activity, not an audio-level measurement or an indication that someone is speaking. Typography uses Avenir Next Condensed, system monospaced text and native fonts; no external font installation is needed. Faders support accessibility adjustment and right-to-left layouts.

## Validation

Time-of-day boundaries, timezone changes, cat departure/absence/return and Reduce Motion behavior have standalone checks in `tests/TowerAtmosphereChecks.swift`. Compile with `Models/TowerAtmosphere.swift` to run them. iOS simulator and macOS builds are checked, along with existing SoundCloud bridge checks. Layouts are inspected in simulator screenshots; physical-device touch, VoiceOver and lock-screen behavior still need manual verification.

Debug builds accept `--tower-time=morning`, `day`, `evening` or `night` to preview a scene without changing the device clock. `--tower-player` and `--tower-filter` select those control pages without starting playback. `--tower-controls` scrolls to the instruments and `--tower-crooked-clock` previews the clock's settled pose for visual checks.
