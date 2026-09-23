import SwiftUI

struct ContentView: View {
    @Environment(AudioCoordinator.self) private var model
    @Environment(TowerRoomSession.self) private var roomSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stationSearch = ""
    @State private var stationFilter = StationFilter.all
    @State private var showsDiagnostics = false
    @State private var showsFilter = false
    @State private var deskPage = DeskPage.stations
    @FocusState private var searchFocused: Bool

    private enum DeskPage { case stations, player }
    init() {
#if DEBUG
        // Deterministic visual checks without changing saved station or playback intent.
        let arguments = ProcessInfo.processInfo.arguments
        _deskPage = State(initialValue: arguments.contains("--tower-player") ? .player : .stations)
        _showsFilter = State(initialValue: arguments.contains("--tower-filter"))
#endif
    }
    private var motion: Bool { !reduceMotion }
    private var filteredRegions: [(region: String, stations: [Station])] {
        let query = StationSearch(stationSearch)
        return model.stationsByRegion.compactMap { bucket in
            let stations = bucket.stations.filter { stationFilter.matches($0) && query.matches($0) }
            return stations.isEmpty ? nil : (region: bucket.region, stations: stations)
        }
    }
    private var visibleStations: [Station] { filteredRegions.flatMap(\.stations) }
    private var continents: [String] { Set(model.stations.map(\.region)).sorted() }
    private var countries: [String] { Set(model.stations.map(\.country).filter { !$0.isEmpty }).sorted() }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 850
            let portrait = geometry.size.width < 650 || geometry.size.width < geometry.size.height * 0.9
            let sceneHeight = min(geometry.size.width * (portrait ? 1.5 : 2 / 3), max(480, geometry.size.height * 0.88))
            ZStack {
                TowerStyle.ink.ignoresSafeArea()
                TowerDeskScroll(roomHeight: sceneHeight) { openControls in
                    TowerRoom(session: roomSession, motion: motion, portrait: portrait,
                              playing: model.playbackState.shouldPause,
                              status: model.playbackState.airportStatus,
                              canPlay: model.selectedStation != nil,
                              onPlay: { model.togglePlayback() },
                              onOpenControls: openControls)
                } controls: {
                    VStack(spacing: 22) {
                        deskNavigation(wide: wide).id("instruments")
                        let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 26)) : AnyLayout(VStackLayout(spacing: 0))
                        layout {
                            stationMonitor(wide: wide)
                                .frame(maxWidth: wide ? 470 : .infinity)
                                .frame(height: !wide && deskPage != .stations ? 0 : nil, alignment: .top)
                                .opacity(!wide && deskPage != .stations ? 0 : 1)
                                .clipped()
                                .allowsHitTesting(wide || deskPage == .stations)
                                .accessibilityHidden(!wide && deskPage != .stations)
                            // Both pages stay mounted so browsing never replaces the music player.
                            playerConsole
                                .frame(maxWidth: .infinity)
                                .frame(height: !wide && deskPage != .player ? 0 : nil, alignment: .top)
                                .opacity(!wide && deskPage != .player ? 0 : 1)
                                .clipped()
                                .allowsHitTesting(wide || deskPage == .player)
                                .accessibilityHidden(!wide && deskPage != .player)
                        }
                        footer
                    }
                    .padding(.horizontal, wide ? 40 : 18).padding(.vertical, 24)
                    .frame(maxWidth: 1200).frame(maxWidth: .infinity)
                }
                if let error = model.playbackState.errorBanner {
                    Color.black.opacity(0.65).ignoresSafeArea()
                    EquipmentPanel(label: "Incoming message", accent: TowerStyle.amber) {
                        Text(error).font(TowerStyle.type(14)).foregroundStyle(TowerStyle.paper)
                        Button("ACKNOWLEDGE") { model.clearErrorBanner() }
                            .buttonStyle(ConsoleKeyStyle(lit: true, accent: TowerStyle.amber))
                    }.frame(maxWidth: 360).padding(24)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(TowerStyle.mint)
        .task {
            model.startIfNeeded()
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--tower-crooked-clock") { roomSession.loosenClock() }
#endif
        }
        .sheet(isPresented: $showsDiagnostics) { diagnostics }
    }

    private func deskNavigation(wide: Bool) -> some View {
        HStack(spacing: 10) {
            Button { deskPage = .stations; searchFocused = false } label: {
                HStack(spacing: 8) { Image(systemName: "display"); Text("STATIONS") }
            }.buttonStyle(ConsoleKeyStyle(lit: deskPage == .stations || wide))
            Button { deskPage = .player; searchFocused = false } label: {
                HStack(spacing: 8) { Image(systemName: "slider.horizontal.3"); Text("PLAYER") }
            }.buttonStyle(ConsoleKeyStyle(lit: deskPage == .player, accent: TowerStyle.amber))
            Spacer(minLength: 0)
        }
    }

    private func stationMonitor(wide: Bool) -> some View {
        VStack(spacing: 0) {
            EquipmentPanel(label: "Worldwide receiver  /  CRT–01") {
                CRTScreen {
                    VStack(spacing: 0) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Engraving(text: showsFilter ? "Choose your airspace" : "Signal directory", color: TowerStyle.mint.opacity(0.65))
                                Text(showsFilter ? "AIRSPACE FILTER" : "FIND A FREQUENCY")
                                    .font(TowerStyle.display(24)).foregroundStyle(TowerStyle.mint)
                            }
                            Spacer(minLength: 0)
                            Button { showsFilter.toggle(); searchFocused = false } label: {
                                Image(systemName: showsFilter ? "xmark" : "line.3.horizontal.decrease")
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(stationFilter == .all ? TowerStyle.mint : TowerStyle.amber)
                                    .background(TowerStyle.mint.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
                            }.buttonStyle(.plain)
                                .accessibilityLabel(showsFilter ? "Close filter" : "Filter stations")
                                .accessibilityValue(stationFilter.title)
                        }.padding(16)
                        if showsFilter {
                            filterList.frame(height: wide ? 415 : 310)
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass").font(.system(size: 13))
                                TextField("Search stations…", text: $stationSearch)
                                    .font(TowerStyle.type(13)).textFieldStyle(.plain)
                                    .focused($searchFocused).autocorrectionDisabled()
                                    .accessibilityLabel("Search stations")
                                if !stationSearch.isEmpty {
                                    Button { stationSearch = "" } label: {
                                        Image(systemName: "xmark.circle.fill").frame(width: 30, height: 36)
                                    }.buttonStyle(.plain).accessibilityLabel("Clear search")
                                }
                            }
                            .foregroundStyle(TowerStyle.mint)
                            .padding(.horizontal, 12).frame(height: 44)
                            .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(TowerStyle.mint.opacity(0.2)))
                            .padding(.horizontal, 14).padding(.bottom, 8)
                            stationList.frame(height: wide ? 363 : 258)
                        }
                        HStack {
                            Circle().fill(TowerStyle.mint).frame(width: 4, height: 4)
                            Text(stationFilter == .all ? "ALL AIRSPACE" : stationFilter.title.uppercased()).lineLimit(1)
                            Spacer()
                            Text("\(visibleStations.count) FEEDS").monospacedDigit()
                        }.font(TowerStyle.type(9)).foregroundStyle(TowerStyle.mint.opacity(0.65))
                            .padding(14).background(.black.opacity(0.2))
                    }
                }
                HStack {
                    Engraving(text: "Select a station to tune in")
                    Spacer()
                    Image(systemName: "globe.europe.africa").foregroundStyle(TowerStyle.mint.opacity(0.4))
                }
            }
            // Monitor pedestal and foot, rather than a floating app card.
            Rectangle().fill(LinearGradient(colors: [.black.opacity(0.8), TowerStyle.metal], startPoint: .leading, endPoint: .trailing))
                .frame(width: 88, height: 18)
            RoundedRectangle(cornerRadius: 4).fill(TowerStyle.metal.gradient).frame(width: 160, height: 7)
                .shadow(color: .black.opacity(0.8), radius: 6, y: 4)
            if !wide {
                Button { deskPage = .player } label: {
                    HStack {
                        Circle().fill(model.playbackState.radioPlaying ? TowerStyle.mint : TowerStyle.amber).frame(width: 6, height: 6)
                        Text(model.selectedStation?.displayName ?? "Open listening console").lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }.buttonStyle(ConsoleKeyStyle()).padding(.top, 16)
            }
        }
    }

    private var stationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(filteredRegions, id: \.region) { bucket in
                    Section {
                        ForEach(bucket.stations) { station in
                            stationRow(station)
                        }
                    } header: {
                        HStack {
                            Text(bucket.region.uppercased()).tracking(1.5)
                            Rectangle().fill(TowerStyle.mint.opacity(0.15)).frame(height: 1)
                        }.font(TowerStyle.type(9)).foregroundStyle(TowerStyle.mint.opacity(0.5))
                            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 6)
                    }
                }
                if visibleStations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash").font(.title)
                        Text("No frequencies found").font(TowerStyle.type(14))
                        Text("Try another name or airspace.").font(TowerStyle.type(11))
                        Button("CLEAR SEARCH & FILTER") { stationSearch = ""; stationFilter = .all }
                            .buttonStyle(ConsoleKeyStyle())
                    }.foregroundStyle(TowerStyle.mint).frame(maxWidth: .infinity).padding(.vertical, 40)
                }
            }.padding(.bottom, 12)
        }.scrollIndicators(.hidden)
    }

    private func stationRow(_ station: Station) -> some View {
        let selected = station.id == model.playbackState.selectedStationID
        return Button {
            model.selectStation(station)
            deskPage = .player
            searchFocused = false
        } label: {
            HStack(spacing: 12) {
                Text(station.airportCode.isEmpty ? "—" : station.airportCode)
                    .font(TowerStyle.display(21)).foregroundStyle(selected ? TowerStyle.amber : TowerStyle.mint)
                    .lineLimit(1).minimumScaleFactor(0.65)
                    .frame(width: 49, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    Text(station.name).font(TowerStyle.type(12)).foregroundStyle(TowerStyle.paper).lineLimit(2)
                    Text(station.locationLabel).font(TowerStyle.type(9)).foregroundStyle(TowerStyle.mint.opacity(0.6)).lineLimit(1)
                }
                Spacer(minLength: 0)
                if selected && model.playbackState.radioPlaying {
                    Image(systemName: "waveform").font(.system(size: 14)).foregroundStyle(TowerStyle.mint)
                        .accessibilityLabel("Now playing")
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(TowerStyle.mint.opacity(0.3))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(selected ? TowerStyle.mint.opacity(0.09) : .clear)
            .overlay(alignment: .leading) { if selected { Rectangle().fill(TowerStyle.amber).frame(width: 2) } }
            .overlay(alignment: .bottom) { Rectangle().fill(TowerStyle.mint.opacity(0.06)).frame(height: 1).padding(.horizontal, 16) }
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var filterList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                filterOption("All stations", value: .all)
                filterDivider("CONTINENTS")
                ForEach(continents, id: \.self) { filterOption($0, value: .continent($0)) }
                filterDivider("COUNTRIES")
                ForEach(countries, id: \.self) { filterOption(CountryFlag.label(for: $0), value: .country($0)) }
            }
        }.scrollIndicators(.hidden)
    }

    private func filterDivider(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(TowerStyle.mint.opacity(0.2)).frame(height: 1)
            Engraving(text: title, color: TowerStyle.mint.opacity(0.45))
        }.padding(14)
    }

    private func filterOption(_ title: String, value: StationFilter) -> some View {
        Button { stationFilter = value; showsFilter = false } label: {
            HStack {
                Text(title).font(TowerStyle.type(12))
                Spacer()
                if stationFilter == value { Image(systemName: "checkmark") }
            }.foregroundStyle(stationFilter == value ? TowerStyle.amber : TowerStyle.mint)
                .padding(.horizontal, 16).frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(stationFilter == value ? .isSelected : [])
    }

    private var playerConsole: some View {
        VStack(spacing: 20) {
            airportInstrument
            musicInstrument
        }
    }

    private var airportInstrument: some View {
        EquipmentPanel(label: "Air traffic receiver") {
            CRTScreen {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(model.selectedStation?.airportCode ?? "—").font(TowerStyle.display(38)).foregroundStyle(TowerStyle.mint)
                        Spacer()
                        Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 22, weight: .ultraLight)).foregroundStyle(TowerStyle.mint.opacity(0.5))
                    }
                    Text(model.selectedStation?.name ?? "Select a station on the monitor")
                        .font(TowerStyle.type(13)).foregroundStyle(TowerStyle.paper).fixedSize(horizontal: false, vertical: true)
                    Text(model.selectedStation?.locationLabel ?? "Worldwide listening")
                        .font(TowerStyle.type(10)).foregroundStyle(TowerStyle.mint.opacity(0.6))
                    RadioTrace(active: model.playbackState.radioPlaying)
                    airportStatus
                }.padding(17)
            }
            Link("Airport audio provided by LiveATC.net ↗", destination: AppLinks.liveATC)
                .font(TowerStyle.type(12))
                .foregroundStyle(TowerStyle.mint)
            HStack(spacing: 14) {
                transportButton("Previous station", symbol: "backward.end.fill", disabled: visibleStations.isEmpty) { model.moveStation(in: visibleStations, forward: false) }
                Spacer()
                Engraving(text: "Tune station")
                Spacer()
                transportButton("Next station", symbol: "forward.end.fill", disabled: visibleStations.isEmpty) { model.moveStation(in: visibleStations, forward: true) }
            }
            ConsoleFader(title: "Radio level", value: Binding(get: { model.playbackState.radioVolume }, set: { model.setRadioVolume($0) }))
        }
    }

    private var airportStatus: some View {
        let status = model.playbackState.airportStatus
        let color: Color = status == .error ? Color(red: 1, green: 0.48, blue: 0.40) : status == .playing ? TowerStyle.mint : TowerStyle.amber
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Circle().fill(color).frame(width: 7, height: 7).shadow(color: color.opacity(0.6), radius: 5)
                Text(status.rawValue.uppercased()).font(TowerStyle.type(12)).tracking(1)
                Spacer(minLength: 0)
                if status == .error {
                    Button("RETRY") { model.retryStation() }.buttonStyle(ConsoleKeyStyle())
                }
            }.foregroundStyle(color)
            if let error = model.playbackState.radioError {
                Text(error).font(TowerStyle.type(11)).foregroundStyle(TowerStyle.paper.opacity(0.7))
            }
        }.accessibilityElement(children: .contain)
    }

    private var musicInstrument: some View {
        EquipmentPanel(label: "SoundCloud listening deck", accent: TowerStyle.amber) {
            // Keep the official player visible and interactive; its artwork and
            // playback state belong to SoundCloud, not a simulated cassette.
            SoundCloudWebView(bridge: model.soundCloud)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.75), lineWidth: 4).allowsHitTesting(false))
            HStack {
                transportButton("Previous SoundCloud track", symbol: "backward.end.fill", disabled: !model.playbackState.musicReady) { model.previousTrack() }
                Spacer()
                Engraving(text: "Change track")
                Spacer()
                transportButton("Next SoundCloud track", symbol: "forward.end.fill", disabled: !model.playbackState.musicReady) { model.nextTrack() }
            }
            ConsoleFader(title: "Music level", value: Binding(get: { model.playbackState.musicVolume }, set: { model.setMusicVolume($0) }), accent: TowerStyle.amber)
        }
    }

    private func transportButton(_ title: String, symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 18) }
            .buttonStyle(ConsoleKeyStyle()).accessibilityLabel(title).help(title)
            .disabled(disabled).opacity(disabled ? 0.35 : 1)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            Link("Airport audio: LiveATC.net ↗", destination: AppLinks.liveATC)
                .font(TowerStyle.type(12))
                .foregroundStyle(TowerStyle.mint)
            Text("For personal use only. Not licensed for public distribution.")
                .font(TowerStyle.type(11))
                .foregroundStyle(TowerStyle.paper.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Link("Privacy & support", destination: AppLinks.privacy)
                .font(TowerStyle.type(12))
                .foregroundStyle(TowerStyle.paper)
            Button { showsDiagnostics = true } label: {
                Image(systemName: "gearshape").frame(width: 18)
            }
            .buttonStyle(ConsoleKeyStyle())
            .accessibilityLabel("Settings and diagnostics")
        }
    }

    private var diagnostics: some View {
        ScrollView {
            EquipmentPanel(label: "Settings & diagnostics") {
                VStack(alignment: .leading, spacing: 20) {
                    Link("Idea inspired by Listen to the Clouds ↗", destination: AppLinks.inspiration)
                        .font(TowerStyle.type(12)).foregroundStyle(TowerStyle.mint)
                    Text("Personal listening only. Not licensed for public distribution.").font(TowerStyle.type(11)).foregroundStyle(TowerStyle.paper.opacity(0.65))
                    Text("For entertainment only. Audio may be delayed or unavailable. Never use it for navigation, flight operations, or safety decisions.")
                        .font(TowerStyle.type(12)).foregroundStyle(TowerStyle.paper)
                    Text("Airport audio is provided by LiveATC.net and its feed contributors. Tower Lounge is an independent project; no endorsement by LiveATC, SoundCloud, or an aviation authority is implied.")
                        .font(TowerStyle.type(12)).foregroundStyle(TowerStyle.paper)
                    VStack(alignment: .leading, spacing: 14) {
                        Link("Tower Lounge privacy policy ↗", destination: AppLinks.privacy)
                        Link("Contact Tower Lounge ↗", destination: AppLinks.contact)
                        Link("LiveATC privacy policy ↗", destination: AppLinks.liveATCPrivacy)
                        Link("LiveATC terms of use ↗", destination: AppLinks.liveATCTerms)
                        Link("Visit & support LiveATC ↗", destination: AppLinks.liveATC)
                        Link("SoundCloud privacy policy ↗", destination: AppLinks.soundCloudPrivacy)
                        Link("SoundCloud cookies & choices ↗", destination: AppLinks.soundCloudCookies)
                    }.font(TowerStyle.type(12)).foregroundStyle(TowerStyle.mint)
                    Text("The embedded SoundCloud player connects to SoundCloud when it loads, even before music starts. Its privacy and cookie policies apply.")
                        .font(TowerStyle.type(11)).foregroundStyle(TowerStyle.paper.opacity(0.75))
                    diagnostic("STATION", model.selectedStation?.displayName ?? "None")
                    diagnostic("PLAYBACK", model.playbackState.playbackSummary)
                    diagnostic("AIRPORT RECEIVER", model.playbackState.radioReady ? "Ready" : "Not ready")
                    diagnostic("MUSIC DECK", model.playbackState.musicReady ? "Ready" : "Not ready")
                    if let error = model.selectedStation?.lastError { diagnostic("LAST ERROR", error) }
                    if let checkedAt = model.selectedStation?.lastHealth?.checkedAt {
                        diagnostic("LAST CHECKED", checkedAt.formatted(date: .abbreviated, time: .standard))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                Button("CLOSE PANEL") { showsDiagnostics = false }.buttonStyle(ConsoleKeyStyle(lit: true))
            }.padding(24)
        }
        .background(TowerStyle.ink)
        .frame(minWidth: 300, minHeight: 400)
        .presentationDragIndicator(.visible)
    }

    private func diagnostic(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Engraving(text: title)
            Text(value).font(TowerStyle.type(13)).foregroundStyle(TowerStyle.mint)
        }
    }
}

#Preview { ContentView().environment(AudioCoordinator()).environment(TowerRoomSession()) }
