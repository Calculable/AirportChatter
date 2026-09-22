// Run from the repository root:
// swiftc AirportChatter/Models/Station.swift tests/StationSearchChecks.swift -o /tmp/station-checks && /tmp/station-checks
import Foundation

@main
struct StationSearchChecks {
    static func main() throws {
        let paris = Station(id: "paris", name: "Ground Control", iata: "CDG", code: "lfpg_gnd", streamURL: URL(string: "https://example.com/paris")!, region: "Europe", isDefault: true, icao: "LFPG", location: "Paris, France")
        let boston = Station(id: "boston", name: "Boston ATIS", iata: "BOS", code: "kbos_atis", streamURL: URL(string: "https://example.com/boston")!, region: "North America", isDefault: true, icao: "KBOS", location: "Boston, Massachusetts, United States")
        precondition(paris.matches("paris ground"))
        precondition(paris.matches("FRANCE cdg"))
        precondition(boston.matches("united states KBOS"))
        precondition(paris.matches("   "))
        precondition(!paris.matches("country:France"))
        precondition(!paris.matches("-atis"))
        precondition(StationFilter.all.matches(paris))
        precondition(StationFilter.continent("Europe").matches(paris))
        precondition(!StationFilter.continent("Europe").matches(boston))
        precondition(StationFilter.country("United States").matches(boston))
        precondition(!StationFilter.country("France").matches(boston))
        let visible = [paris, boston]
        precondition(adjacentStation(in: visible, selectedID: "paris", forward: true)?.id == "boston")
        precondition(adjacentStation(in: visible, selectedID: "paris", forward: false)?.id == "boston")
        precondition(adjacentStation(in: visible, selectedID: "boston", forward: true)?.id == "paris")
        precondition(adjacentStation(in: visible, selectedID: "filtered-out", forward: true)?.id == "paris")
        precondition(adjacentStation(in: visible, selectedID: "filtered-out", forward: false)?.id == "boston")
        precondition(adjacentStation(in: [], selectedID: "paris", forward: true) == nil)
        precondition(adjacentStation(in: [paris], selectedID: "paris", forward: false)?.id == "paris")
        let catalogPath = "AirportChatter/Data/default_stations.json"
        if FileManager.default.fileExists(atPath: catalogPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: "AirportChatter/Data/default_stations.json"))
            let stations = try JSONDecoder().decode([Station].self, from: data)
            precondition(CountryFlag.emoji(for: "Switzerland") == "🇨🇭")
            precondition(CountryFlag.emoji(for: "United States") == "🇺🇸")
            precondition(CountryFlag.emoji(for: "Unknown") == "")
            let missingFlags = Set(stations.map(\.country)).filter { !$0.isEmpty && CountryFlag.emoji(for: $0).isEmpty }
            precondition(missingFlags.isEmpty, "Missing country flags: \(missingFlags)")
            precondition(stations.contains { $0.matches("Switzerland") })
            precondition(stations.contains { $0.matches("Asia") })
        } else {
            print("Local catalog absent; skipped catalog-specific checks.")
        }
        print("Plain search, geographic filters, navigation edge cases, and catalog decoding passed.")
    }
}
