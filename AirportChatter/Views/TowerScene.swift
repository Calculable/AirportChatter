import SwiftUI

struct TowerRoom: View {
    let session: TowerRoomSession
    let motion: Bool
    let portrait: Bool
    let playing: Bool
    let status: AirportStreamStatus
    let canPlay: Bool
    let onPlay: () -> Void
    let onOpenControls: () -> Void

    private func atmosphere(at date: Date) -> TowerTimeOfDay {
#if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--tower-time=") }),
           let override = TowerTimeOfDay.allCases.first(where: { argument == "--tower-time=\($0.rawValue.lowercased())" }) {
            return override
        }
#endif
        return .at(date)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, geometry.size.height * (portrait ? 2 / 3 : 1.5))
            let height = geometry.size.height
            TimelineView(.periodic(from: Date(timeIntervalSince1970: 0), by: 60)) { context in
                let period = atmosphere(at: context.date)
                ZStack {
                    Image(period.asset(portrait: portrait)).resizable()
                        .frame(width: width, height: height)
                        .accessibilityLabel("Tower Lounge. \(period.rawValue) in the tower. A postcard says: Somewhere, someone is coming home.")
                    TowerNameplate()
                        .frame(width: width * 0.25, height: height * (portrait ? 0.025 : 0.036))
                        .position(x: width * 0.5, y: height * (portrait ? 0.015 : 0.019))
                    TowerFlights(motion: motion, night: period == .night)
                        .frame(width: width * 0.80, height: height * 0.43)
                        .position(x: width * 0.5, y: height * 0.285)
                    TowerClock(session: session)
                        .frame(width: min(70, max(48, width * 0.12)), height: min(70, max(48, width * 0.12)))
                        .rotation3DEffect(.degrees(-12), axis: (x: 0, y: 1, z: 0))
                        .position(x: width * 0.922, y: height * 0.125)
                    TowerCat(motion: motion, roomWidth: width)
                        .frame(width: min(170, width * 0.285), height: min(119, width * 0.20))
                        .position(x: width * (portrait ? 0.23 : 0.265), y: height * 0.672)
                    DeskTransport(playing: playing, status: status, action: onPlay)
                        .scaleEffect(min(1.35, max(1, width / 600)))
                        .disabled(!canPlay).opacity(canPlay ? 1 : 0.6)
                        .position(x: width * 0.55, y: height * 0.686)
                    Button(action: onOpenControls) {
                        HStack(spacing: 22) {
                            PanelScrew()
                            Image(systemName: "chevron.compact.up").font(.system(size: 22, weight: .bold))
                            PanelScrew()
                        }
                        .foregroundStyle(TowerStyle.paper.opacity(0.6))
                        .padding(.horizontal, 12).frame(height: 44)
                        .background(LinearGradient(colors: [TowerStyle.metal, .black], startPoint: .top, endPoint: .bottom), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
                        .shadow(color: .black.opacity(0.8), radius: 4, y: 5)
                    }.buttonStyle(.plain).accessibilityLabel("Show station and player controls")
                        .position(x: width * 0.5, y: height * 0.92)
                }.frame(width: width, height: height).clipped()
                    .frame(width: geometry.size.width)
            }
        }
    }
}

struct TowerFlights: View {
    let motion: Bool
    let night: Bool
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !motion || scenePhase != .active)) { timeline in
            GeometryReader { geometry in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ForEach(0..<2) { index in
                    let cycle = (time + Double(index) * 40).truncatingRemainder(dividingBy: 80)
                    let progress = cycle / (index == 0 ? 23 : 19)
                    let travel = index == 0 ? progress : 1 - progress
                    HStack(spacing: 1) {
                        Image(systemName: "airplane")
                            .font(.system(size: index == 0 ? 13 : 9))
                            .scaleEffect(x: index == 0 ? 1 : -1, y: 1)
                        if night { Circle().fill(TowerStyle.amber).frame(width: 2, height: 2) }
                    }
                    .foregroundStyle(night ? Color.gray : Color(red: 0.22, green: 0.28, blue: 0.31))
                    .rotationEffect(.degrees(index == 0 ? -5 : 6))
                    .position(x: -25 + (geometry.size.width + 50) * travel,
                              y: geometry.size.height * (index == 0 ? 0.42 : 0.70) - progress * 12)
                    .opacity(motion && progress < 1 ? 0.65 : 0)
                }
            }
        }
        // The wide artwork's window posts lean inward. Leave a fully invisible
        // margin before fading in, so neither the aircraft nor its lights cross them.
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.12),
                .init(color: .white, location: 0.27),
                .init(color: .white, location: 0.73),
                .init(color: .clear, location: 0.88),
                .init(color: .clear, location: 1)
            ], startPoint: .leading, endPoint: .trailing)
        }
        .clipped().allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// A brass-rimmed clock bolted to the window upright, not a dashboard readout.
struct TowerClock: View {
    let session: TowerRoomSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSince1970: 0), by: 60)) { context in
            Button {
                guard !session.clockIsCrooked else { return }
                withAnimation(reduceMotion ? nil : .interpolatingSpring(stiffness: 65, damping: 4, initialVelocity: 9)) {
                    session.loosenClock()
                }
            } label: {
            Canvas { canvas, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = size.width / 2
                canvas.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [TowerStyle.paper, Color(red: 0.35, green: 0.24, blue: 0.13), .black]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                let face = CGRect(x: 5, y: 5, width: size.width - 10, height: size.height - 10)
                canvas.fill(Path(ellipseIn: face), with: .color(Color(red: 0.79, green: 0.74, blue: 0.61)))
                for tick in 0..<60 {
                    let angle = Double(tick) * .pi / 30
                    let outer = radius - 8
                    let inner = outer - (tick.isMultiple(of: 5) ? 4.0 : 1.5)
                    var mark = Path()
                    mark.move(to: CGPoint(x: center.x + sin(angle) * inner, y: center.y - cos(angle) * inner))
                    mark.addLine(to: CGPoint(x: center.x + sin(angle) * outer, y: center.y - cos(angle) * outer))
                    canvas.stroke(mark, with: .color(TowerStyle.ink.opacity(0.8)), lineWidth: tick.isMultiple(of: 5) ? 1.3 : 0.5)
                }
                for (number, angle) in [("12", 0.0), ("3", Double.pi / 2), ("6", Double.pi), ("9", 3 * Double.pi / 2)] {
                    let text = Text(number).font(.system(size: size.width * 0.11, weight: .bold, design: .serif)).foregroundStyle(TowerStyle.ink)
                    canvas.draw(text, at: CGPoint(x: center.x + sin(angle) * (radius - 14),
                                                  y: center.y - cos(angle) * (radius - 14)))
                }
                let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: context.date)
                let minutes = Double(components.minute ?? 0)
                let hours = Double((components.hour ?? 0) % 12) + minutes / 60
                for (angle, length, thickness) in [(hours * .pi / 6, radius * 0.42, 2.2), (minutes * .pi / 30, radius * 0.64, 1.5)] {
                    var hand = Path(); hand.move(to: center)
                    hand.addLine(to: CGPoint(x: center.x + sin(angle) * length, y: center.y - cos(angle) * length))
                    canvas.stroke(hand, with: .color(TowerStyle.ink), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                }
                canvas.fill(Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)), with: .color(TowerStyle.ink))
                var reflection = Path()
                reflection.addArc(center: center, radius: radius - 3, startAngle: .degrees(205), endAngle: .degrees(295), clockwise: false)
                canvas.stroke(reflection, with: .color(.white.opacity(0.35)), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.7), radius: 2, x: -3, y: 5)
            // Hang from the remaining upper-left nail rather than rotating
            // around the dial's center. The session owns the final resting pose.
            .rotationEffect(.degrees(session.clockIsCrooked ? 18 : 0), anchor: UnitPoint(x: 0.27, y: 0.06))
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topLeading) {
                GeometryReader { geometry in
                    Circle().fill(Color.gray.gradient).frame(width: 3, height: 3)
                        .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
                        .position(x: geometry.size.width * 0.27, y: geometry.size.height * 0.06)
                }.allowsHitTesting(false)
            }
            .accessibilityLabel(session.clockIsCrooked ? "Crooked wall clock, local time" : "Wall clock, local time")
            .accessibilityValue(context.date.formatted(date: .omitted, time: .shortened))
            .accessibilityHint(session.clockIsCrooked ? "It will be straight again after restarting the app." : "Tap to loosen a nail.")
        }
    }
}

struct DeskTransport: View {
    let playing: Bool
    let status: AirportStreamStatus
    let action: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: action) {
                ZStack {
                    Circle().fill(.black).frame(width: 118, height: 118).offset(y: 7)
                    Circle().fill(LinearGradient(colors: [Color.gray, Color(red: 0.12, green: 0.14, blue: 0.13), .black], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 118, height: 118)
                    Circle().strokeBorder(TowerStyle.paper.opacity(0.35), lineWidth: 1).frame(width: 110, height: 110)
                    Circle().fill(.black).frame(width: 97, height: 97)
                    Circle().fill(LinearGradient(colors: [TowerStyle.amber, Color(red: 0.64, green: 0.33, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 86, height: 86)
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1).frame(width: 83, height: 83)
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .black)).foregroundStyle(TowerStyle.ink)
                }
            }.buttonStyle(DeskPressStyle())
                .accessibilityLabel(playing ? "Pause both players" : "Play both players")
            DeskStatusLamp(status: status)
                .offset(y: -27)

        }
        .rotation3DEffect(.degrees(22), axis: (x: 1, y: 0, z: 0))
        .rotationEffect(.degrees(-5))
        .shadow(color: .black.opacity(0.6), radius: 5, x: 3, y: 12)
        .frame(width: 158, height: 144)
    }
}

private struct DeskPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.offset(y: configuration.isPressed ? 3 : 0)
    }
}

/// Low, domed indicator seated in a flattened metal collar on the desk.
struct DeskStatusLamp: View {
    let status: AirportStreamStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private var loading: Bool { status == .waiting || status == .reconnecting }
    private var pulses: Bool { loading && !reduceMotion && scenePhase == .active }
    private var lamp: Color {
        switch status {
        case .playing: TowerStyle.mint
        case .waiting, .reconnecting: TowerStyle.amber
        case .error: Color(red: 1, green: 0.30, blue: 0.2)
        case .paused: Color(red: 0.20, green: 0.27, blue: 0.23)
        }
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !pulses)) { context in
            let glow = pulses ? 0.35 + 0.65 * (1 - cos(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 3)) / 2 : 1
            ZStack {
                Ellipse().fill(.black.opacity(0.6)).frame(width: 32, height: 13)
                    .blur(radius: 2).offset(x: 2, y: 5)
                Ellipse().fill(.black).frame(width: 29, height: 16).offset(y: 3)
                Ellipse().fill(LinearGradient(colors: [TowerStyle.paper.opacity(0.7), .gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 29, height: 16)
                Ellipse().fill(.black).frame(width: 23, height: 12)
                Ellipse().fill(lamp.opacity(glow).gradient).frame(width: 18, height: 10).offset(y: -1)
                    .shadow(color: status == .paused ? .clear : lamp.opacity(0.6 * glow), radius: 4 + 5 * glow)
                Ellipse().fill(.white.opacity(0.45)).frame(width: 7, height: 2).offset(x: -3, y: -4)
            }.frame(width: 29, height: 22)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Airport stream: \(status.rawValue)")
    }
}

/// A physical nameplate covers the lettering on the original illustrated beam.
private struct TowerNameplate: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: geometry.size.width * 0.04) {
                rivet
                Text("TOWER LOUNGE")
                    .font(.system(size: geometry.size.height * 0.62, weight: .medium, design: .serif))
                    .tracking(geometry.size.width * 0.006)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(Color(red: 0.72, green: 0.56, blue: 0.37))
                    .shadow(color: .black, radius: 0, y: 1)
                    .frame(maxWidth: .infinity)
                rivet
            }
            .padding(.horizontal, geometry.size.width * 0.035)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(LinearGradient(colors: [Color(red: 0.16, green: 0.19, blue: 0.18), Color(red: 0.08, green: 0.10, blue: 0.10)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color(red: 0.35, green: 0.28, blue: 0.18), lineWidth: 0.6))
            .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var rivet: some View {
        Circle().fill(Color.black.opacity(0.7)).frame(width: 2, height: 2)
            .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }
}
