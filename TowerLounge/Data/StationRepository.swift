import Foundation

protocol StationRepository {
    func loadDefaults() throws -> [Station]
    func loadUserStations() throws -> [Station]
    func saveUserStations(_ stations: [Station]) throws
    func allStations() throws -> [Station]
}

struct LocalStationRepository: StationRepository {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let userDefaultsKey = "airport_chatter_user_stations"

    func loadDefaults() throws -> [Station] {
        guard let url = Bundle.main.url(forResource: "default_stations", withExtension: "json") else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([Station].self, from: data)
    }

    func loadUserStations() throws -> [Station] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }
        return try decoder.decode([Station].self, from: data)
    }

    func saveUserStations(_ stations: [Station]) throws {
        let data = try encoder.encode(stations)
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    func allStations() throws -> [Station] {
        let defaults = try loadDefaults()
        let userStations = try loadUserStations()
        var merged = defaults
        let defaultIDs = Set(defaults.map(\.id))
        merged.append(contentsOf: userStations.filter { !defaultIDs.contains($0.id) })
        return merged
    }
}
