import Foundation

struct StationHealthResult: Codable, Hashable {
    let stationID: String
    let reachable: Bool
    let responseCode: Int?
    let hasRecentAudioEnergy: Bool
    let checkedAt: Date
}

struct Station: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let iata: String
    let code: String
    let streamURL: URL
    let region: String
    let isDefault: Bool
    var icao: String?
    var location: String?
    var lastHealth: StationHealthResult?
    var lastError: String?

    var displayName: String {
        airportCode.isEmpty ? name : "\(name) (\(airportCode))"
    }

    var airportCode: String {
        iata.isEmpty ? (icao ?? "") : iata
    }

    var country: String {
        guard region != "Oceanic / HF" else { return "" }
        let parts = (location ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        if parts.last == "Republic of", parts.count >= 2 { return parts[parts.count - 2] }
        return parts.last ?? ""
    }

    var locationLabel: String {
        [CountryFlag.emoji(for: country), location ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }

    func matches(_ query: String) -> Bool {
        StationSearch(query).matches(self)
    }
}

enum StationFilter: Equatable {
    case all
    case continent(String)
    case country(String)

    var title: String {
        switch self {
        case .all: return "All stations"
        case .continent(let name), .country(let name): return name
        }
    }

    func matches(_ station: Station) -> Bool {
        switch self {
        case .all: return true
        case .continent(let name): return station.region == name
        case .country(let name): return station.country == name
        }
    }
}

struct StationSearch {
    private let terms: [String]

    init(_ query: String) {
        terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    func matches(_ station: Station) -> Bool {
        let text = [station.name, station.iata, station.icao ?? "", station.location ?? "", station.region, station.code].joined(separator: " ")
        return terms.allSatisfy { text.localizedStandardContains($0) }
    }
}

/// Uses exactly the same ordering as the visible overview, including wraparound.
func adjacentStation(in stations: [Station], selectedID: String?, forward: Bool) -> Station? {
    guard !stations.isEmpty else { return nil }
    guard let index = stations.firstIndex(where: { $0.id == selectedID }) else {
        return forward ? stations.first : stations.last
    }
    return stations[(index + (forward ? 1 : stations.count - 1)) % stations.count]
}

enum CountryFlag {
    // Catalog names that differ from Foundation's English region names.
    private static let aliases = ["Curacao": "CW", "Bonaire": "BQ", "Saba": "BQ", "Saint Martin": "MF", "North Macedonia": "MK", "Trinidad and Tobago": "TT"]
    private static let codes: [String: String] = {
        let english = Locale(identifier: "en_US")
        var result: [String: String] = [:]
        for region in Locale.Region.isoRegions where region.identifier.count == 2 {
            if let name = english.localizedString(forRegionCode: region.identifier) {
                result[name] = region.identifier
            }
        }
        return result.merging(aliases) { _, alias in alias }
    }()

    static func emoji(for country: String) -> String {
        guard let code = codes[country] else { return "" }
        return String(String.UnicodeScalarView(code.unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }))
    }

    static func label(for country: String) -> String {
        [emoji(for: country), country].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
