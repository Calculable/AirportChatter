import Foundation

/// Local civil time, intentionally independent of the selected station's timezone.
enum TowerTimeOfDay: String, CaseIterable {
    case morning = "Morning", day = "Day", evening = "Evening", night = "Night"

    static func at(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Self {
        switch calendar.component(.hour, from: date) {
        case 5..<11: return .morning
        case 11..<17: return .day
        case 17..<21: return .evening
        default: return .night
        }
    }

    func asset(portrait: Bool) -> String { "Tower\(rawValue)\(portrait ? "Portrait" : "Wide")" }
}

enum TowerCatPose { case sleeping, sitting, grooming, stretching, running }

struct TowerCatMoment {
    let pose: TowerCatPose
    let travel: Double
    let facingRight: Bool
    let visible: Bool

    static func at(_ time: TimeInterval, excursionStart: TimeInterval?, motion: Bool) -> Self {
        if let start = excursionStart {
            let elapsed = max(0, time - start)
            if elapsed < 0.8 {
                return .init(pose: .running, travel: motion ? -elapsed / 0.8 : 0, facingRight: false, visible: motion)
            }
            if elapsed < 4 { return .init(pose: .running, travel: -1, facingRight: true, visible: false) }
            if elapsed < 5.2 {
                return .init(pose: .running, travel: motion ? -1 + (elapsed - 4) / 1.2 : 0, facingRight: true, visible: motion)
            }
            if elapsed < 10 { return .init(pose: .sitting, travel: 0, facingRight: false, visible: true) }
        }
        guard motion else { return .init(pose: .sleeping, travel: 0, facingRight: false, visible: true) }
        // A little activity every three minutes, then long quiet stretches.
        let cycle = Int(time / 180) % 3
        let phase = time.truncatingRemainder(dividingBy: 180)
        let pose: TowerCatPose = phase < 12 ? [.stretching, .grooming, .sitting][cycle] : .sleeping
        return .init(pose: pose, travel: 0, facingRight: false, visible: true)
    }
}
