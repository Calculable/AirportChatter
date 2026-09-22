import SwiftUI

struct ContentView: View {
    @Environment(AudioCoordinator.self) private var model
    @State private var stationSearch = ""
    @State private var stationFilter = StationFilter.all
    @State private var showsDiagnostics = false

    private var filteredRegions: [(region: String, stations: [Station])] {
        let query = StationSearch(stationSearch)
        return model.stationsByRegion.compactMap { bucket in
            let stations = bucket.stations.filter {
                stationFilter.matches($0) && query.matches($0)
            }
            return stations.isEmpty ? nil : (region: bucket.region, stations: stations)
        }
    }

    private var visibleStations: [Station] { filteredRegions.flatMap(\.stations) }
    private var continents: [String] { Set(model.stations.map(\.region)).sorted() }
    private var countries: [String] {
        Set(model.stations.map(\.country).filter { !$0.isEmpty }).sorted()
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selectedStationBinding) {
                ForEach(filteredRegions, id: \.region) { bucket in
                    Section(bucket.region) {
                        ForEach(bucket.stations) { station in
                            NavigationLink(value: station.id) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(station.name)
                                        Text([station.airportCode, station.locationLabel].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if station.id == model.playbackState.selectedStationID && model.playbackState.radioPlaying {
                                        Label("Now playing", systemImage: "waveform")
                                            .font(.caption)
                                            .foregroundStyle(.tint)
                                            .padding(6)
                                            .background(.tint.opacity(0.1), in: Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
            .navigationTitle("Stations")
            .searchable(text: $stationSearch, prompt: "Search stations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { filterMenu }
            }
            .overlay {
                if visibleStations.isEmpty {
                    ContentUnavailableView.search(text: stationSearch)
                }
            }
        } detail: {
            ScrollView {
                VStack(spacing: 24) {
                    player
                    airportSection
                    musicSection
                    VStack(spacing: 12) {
                        Button { showsDiagnostics = true } label: {
                            Label("Diagnostics", systemImage: "info.circle")
                        }
                        .buttonStyle(.plain)
                        Text("Personal-use prototype. Not licensed for public distribution.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                }
                .frame(maxWidth: 640)
                .padding(24)
                .frame(maxWidth: .infinity)
            }

        }
        .task { model.startIfNeeded() }
        .sheet(isPresented: $showsDiagnostics) { diagnostics }
        .alert("Stream update", isPresented: Binding(
            get: { model.playbackState.errorBanner != nil },
            set: { if !$0 { model.clearErrorBanner() } }
        )) {
            Button("OK", role: .cancel) { model.clearErrorBanner() }
        } message: {
            Text(model.playbackState.errorBanner ?? "")
        }
    }

    private var filterMenu: some View {
        Menu {
            filterOption("All stations", value: .all)
            Divider()
            ForEach(continents, id: \.self) { name in
                filterOption(name, value: .continent(name))
            }
            Divider()
            ForEach(countries, id: \.self) { name in
                filterOption(CountryFlag.label(for: name), value: .country(name))
            }
        } label: {
            Image(systemName: stationFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("Filter stations")
        .accessibilityValue(stationFilter.title)
        .help("Filter stations: \(stationFilter.title)")
    }

    private func filterOption(_ title: String, value: StationFilter) -> some View {
        Button { stationFilter = value } label: {
            if stationFilter == value {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var selectedStationBinding: Binding<String?> {
        Binding(
            get: { model.playbackState.selectedStationID },
            set: { id in
                if let station = model.stations.first(where: { $0.id == id }) {
                    model.selectStation(station)
                }
            }
        )
    }

    private var player: some View {
        VStack(spacing: 16) {
            Button { model.togglePlayback() } label: {
                Image(systemName: model.playbackState.shouldPause ? "pause.fill" : "play.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(Color.accentColor.gradient, in: Circle())
                    .shadow(color: .accentColor.opacity(0.25), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.playbackState.shouldPause ? "Pause both players" : "Play both players")
            .help(model.playbackState.shouldPause ? "Pause both players" : "Play both players")
            .disabled(model.selectedStation == nil)
            Text("Airport radio + SoundCloud")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private var airportStatus: some View {
        let status = model.playbackState.airportStatus
        let color: Color = status == .error ? .red : (status == .playing ? .green : (status == .waiting || status == .reconnecting ? .orange : .secondary))
        return HStack(spacing: 12) {
            if status == .waiting || status == .reconnecting {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: status.symbol).font(.title2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(status.rawValue).font(.headline)
                if let error = model.playbackState.radioError {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if status == .error {
                Button("Retry") { model.retryStation() }
                    .buttonStyle(.bordered)
            }
        }
        .foregroundStyle(color)
        .padding(16)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var airportSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Airport radio", systemImage: "airplane")
                .font(.headline).foregroundStyle(.tint)
            if let station = model.selectedStation {
                VStack(alignment: .leading, spacing: 5) {
                    Text(station.name).font(.title2.weight(.semibold))
                    Text([station.airportCode, station.locationLabel].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            airportStatus
            HStack {
                transportButton("Previous station", symbol: "backward.end.fill", disabled: visibleStations.isEmpty) {
                    model.moveStation(in: visibleStations, forward: false)
                }
                Spacer()
                Text("Station").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                transportButton("Next station", symbol: "forward.end.fill", disabled: visibleStations.isEmpty) {
                    model.moveStation(in: visibleStations, forward: true)
                }
            }
            volumeSlider("Airport radio volume", value: Binding(get: { model.playbackState.radioVolume }, set: { model.setRadioVolume($0) }))
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.06)))
    }

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("SoundCloud", systemImage: "music.note")
                .font(.headline).foregroundStyle(.orange)
            SoundCloudWebView(bridge: model.soundCloud)
                .frame(height: 280)
                .clipShape(.rect(cornerRadius: 14))
            HStack {
                transportButton("Previous SoundCloud track", symbol: "backward.end.fill", disabled: !model.playbackState.musicReady) {
                    model.previousTrack()
                }
                Spacer()
                Text("Track").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                transportButton("Next SoundCloud track", symbol: "forward.end.fill", disabled: !model.playbackState.musicReady) {
                    model.nextTrack()
                }
            }
            volumeSlider("SoundCloud volume", value: Binding(get: { model.playbackState.musicVolume }, set: { model.setMusicVolume($0) }))
        }
        .tint(.orange)
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.06)))
    }

    private func transportButton(_ title: String, symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 36, height: 32)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityLabel(title)
        .help(title)
        .disabled(disabled)
    }

    private func volumeSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            Slider(value: value, in: 0...1).accessibilityLabel(title)
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
        }
    }

    private var diagnostics: some View {
        NavigationStack {
            Form {
                LabeledContent("Station", value: model.selectedStation?.displayName ?? "None")
                LabeledContent("Playback", value: model.playbackState.playbackSummary)
                LabeledContent("ATC", value: model.playbackState.radioReady ? "Ready" : "Not ready")
                LabeledContent("Music", value: model.playbackState.musicReady ? "Ready" : "Not ready")
                if let checkedAt = model.selectedStation?.lastHealth?.checkedAt {
                    LabeledContent("Last checked", value: checkedAt.formatted(date: .abbreviated, time: .standard))
                }
                if let error = model.selectedStation?.lastError {
                    LabeledContent("Last error", value: error)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Diagnostics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsDiagnostics = false }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 320)
    }
}

#Preview {
    ContentView().environment(AudioCoordinator())
}
