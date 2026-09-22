import SwiftUI

// Shared materials keep the controls feeling like equipment on the same desk.
enum TowerStyle {
    static let ink = Color(red: 0.035, green: 0.08, blue: 0.09)
    static let metal = Color(red: 0.16, green: 0.23, blue: 0.25)
    static let mint = Color(red: 0.60, green: 0.89, blue: 0.77)
    static let amber = Color(red: 1, green: 0.72, blue: 0.40)
    static let paper = Color(red: 0.91, green: 0.87, blue: 0.75)
    static func type(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
    static func display(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-DemiBold", size: size, relativeTo: .title2) }
}

struct Engraving: View {
    let text: String
    var color: Color = TowerStyle.paper.opacity(0.65)
    var body: some View {
        Text(text.uppercased()).font(TowerStyle.type(10)).tracking(2).foregroundStyle(color)
    }
}

struct PanelScrew: View {
    var body: some View {
        Circle().fill(.black.opacity(0.6)).frame(width: 8, height: 8)
            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
            .overlay(Rectangle().fill(.white.opacity(0.2)).frame(width: 4, height: 1).rotationEffect(.degrees(-35)))
            .accessibilityHidden(true)
    }
}

struct EquipmentPanel<Content: View>: View {
    let label: String
    var accent: Color = TowerStyle.mint
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                PanelScrew()
                Engraving(text: label)
                Spacer(minLength: 2)
                Circle().fill(accent).frame(width: 5, height: 5).shadow(color: accent.opacity(0.6), radius: 4)
                PanelScrew()
            }
            content
            HStack { PanelScrew(); Spacer(); Capsule().fill(.black.opacity(0.5)).frame(width: 48, height: 3); Spacer(); PanelScrew() }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [TowerStyle.metal, Color(red: 0.08, green: 0.13, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.65), radius: 0, y: 7)
                .shadow(color: .black.opacity(0.5), radius: 18, y: 16)
        }
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.16), lineWidth: 1))
    }
}

struct CRTScreen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(TowerStyle.ink)
            .overlay {
                Canvas { context, size in
                    var lines = Path()
                    for y in stride(from: 0.0, through: size.height, by: 4) {
                        lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(lines, with: .color(.black.opacity(0.12)), lineWidth: 1)
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.black.opacity(0.7), lineWidth: 3))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(TowerStyle.mint.opacity(0.1), lineWidth: 1).padding(3))
    }
}

struct ConsoleKeyStyle: ButtonStyle {
    var lit = false
    var accent: Color = TowerStyle.mint
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TowerStyle.type(11))
            .foregroundStyle(lit ? TowerStyle.ink : TowerStyle.paper)
            .padding(.horizontal, 14).frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(lit ? accent.gradient : Color(red: 0.23, green: 0.30, blue: 0.31).gradient)
                    .shadow(color: .black.opacity(0.85), radius: 0, y: configuration.isPressed ? 1 : 4)
            }
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(lit ? 0.3 : 0.12)))
            .offset(y: configuration.isPressed ? 3 : 0)
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ConsoleFader: View {
    let title: String
    @Binding var value: Double
    var accent: Color = TowerStyle.mint
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Engraving(text: title)
                Spacer()
                Text("\(Int(value * 100))").font(TowerStyle.type(10)).monospacedDigit().foregroundStyle(accent)
            }
            GeometryReader { proxy in
                let travel = max(1, proxy.size.width - 32)
                let position = layoutDirection == .rightToLeft ? 1 - value : value
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<21) { index in
                            Rectangle().fill(TowerStyle.paper.opacity(index.isMultiple(of: 5) ? 0.4 : 0.17))
                                .frame(width: 1, height: index.isMultiple(of: 5) ? 20 : 12)
                            if index < 20 { Spacer(minLength: 0) }
                        }
                    }.padding(.horizontal, 16)
                    Capsule().fill(.black.opacity(0.8)).frame(height: 6).padding(.horizontal, 16)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [.gray, TowerStyle.paper, .gray], startPoint: .top, endPoint: .bottom))
                        .frame(width: 32, height: 27)
                        .overlay(Rectangle().fill(TowerStyle.ink).frame(width: 2, height: 17))
                        .shadow(color: .black.opacity(0.8), radius: 3, y: 3)
                        .offset(x: travel * position)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { event in
                    let amount = min(1, max(0, (event.location.x - 16) / travel))
                    value = layoutDirection == .rightToLeft ? 1 - amount : amount
                })
            }.frame(height: 44)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.05)
            case .decrement: value = max(0, value - 0.05)
            @unknown default: break
            }
        }
    }
}

/// Decorative activity trace driven by playback state, not sampled audio levels.
struct RadioTrace: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = true
    private var animates: Bool { active && !reduceMotion && scenePhase == .active && visible }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !animates)) { timeline in
            Canvas { context, size in
                let time = animates ? timeline.date.timeIntervalSinceReferenceDate : 0
                let intensity = 0.3 + 0.7 * pow(0.5 + 0.5 * sin(time * 1.3), 2)
                var line = Path()
                for i in 0...160 {
                    let progress = Double(i) / 160
                    let x = size.width * progress
                    let envelope = pow(sin(progress * .pi), 2)
                    let carrier = sin(progress * 105 - time * 13)
                        + 0.38 * sin(progress * 183 + time * 9)
                        + 0.18 * sin(progress * 267 - time * 17)
                    let amplitude = active ? carrier * envelope * intensity * size.height * 0.28 : 0
                    let point = CGPoint(x: x, y: size.height / 2 + amplitude)
                    if i == 0 { line.move(to: point) } else { line.addLine(to: point) }
                }
                if active {
                    context.stroke(line, with: .color(TowerStyle.mint.opacity(0.12)), lineWidth: 4)
                }
                context.stroke(line, with: .color(TowerStyle.mint.opacity(active ? 0.85 : 0.22)), lineWidth: 1.3)
            }
        }
        .frame(height: 30)
        .onScrollVisibilityChange(threshold: 0.01) { visible = $0 }
        .accessibilityHidden(true)
    }
}
