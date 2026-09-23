// swiftc TowerLounge/Models/TowerAtmosphere.swift tests/TowerAtmosphereChecks.swift -o /tmp/tower-checks && /tmp/tower-checks
import Foundation

@main struct TowerAtmosphereChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let cases: [(Int, Int, TowerTimeOfDay)] = [
            (0, 0, .night), (4, 59, .night), (5, 0, .morning), (10, 59, .morning),
            (11, 0, .day), (16, 59, .day), (17, 0, .evening), (20, 59, .evening),
            (21, 0, .night), (23, 59, .night)
        ]
        for (hour, minute, expected) in cases {
            let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: hour, minute: minute))!
            precondition(TowerTimeOfDay.at(date, calendar: calendar) == expected)
        }
        let instant = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 4))!
        calendar.timeZone = TimeZone(secondsFromGMT: 2 * 3600)!
        precondition(TowerTimeOfDay.at(instant, calendar: calendar) == .morning, "Use local civil time, not UTC")
        calendar.timeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        precondition(TowerTimeOfDay.at(instant, calendar: calendar) == .night)

        let outbound = TowerCatMoment.at(100.4, excursionStart: 100, motion: true)
        precondition(outbound.pose == .running && outbound.travel < 0 && !outbound.facingRight)
        precondition(!TowerCatMoment.at(102, excursionStart: 100, motion: true).visible)
        let returning = TowerCatMoment.at(104.5, excursionStart: 100, motion: true)
        precondition(returning.visible && returning.facingRight && returning.travel < 0)
        let home = TowerCatMoment.at(106, excursionStart: 100, motion: true)
        precondition(home.visible && home.travel == 0 && home.pose == .sitting)
        precondition(TowerCatMoment.at(190, excursionStart: nil, motion: true).pose == .grooming)
        precondition(TowerCatMoment.at(200, excursionStart: nil, motion: true).pose == .sleeping)
        let reduced = TowerCatMoment.at(104.5, excursionStart: 100, motion: false)
        precondition(reduced.travel == 0, "Reduce Motion must never move the cat across the screen")
        precondition(TowerCatMoment.at(106, excursionStart: 100, motion: false).visible)
        precondition(TowerCatMoment.at(360, excursionStart: nil, motion: false).pose == .sleeping)
        print("Local-time boundaries, timezone changes, cat excursions, quiet intervals and Reduce Motion passed.")
    }
}
