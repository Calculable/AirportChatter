import Observation

/// Playful room changes survive navigation and new windows, but never persist to disk.
@MainActor @Observable
final class TowerRoomSession {
    private(set) var clockIsCrooked = false

    func loosenClock() {
        clockIsCrooked = true
    }
}
