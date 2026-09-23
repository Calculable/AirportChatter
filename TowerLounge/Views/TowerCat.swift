import SwiftUI

struct TowerCat: View {
    let motion: Bool
    let roomWidth: CGFloat
    @State private var excursionStarted: Date?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: excursionStarted == nil ? 0.1 : 1 / 24,
                                paused: !motion || scenePhase != .active)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let moment = TowerCatMoment.at(time, excursionStart: excursionStarted?.timeIntervalSinceReferenceDate, motion: motion)
            Button { excursionStarted = .now } label: {
                Canvas { canvas, size in
                    canvas.scaleBy(x: size.width / 120, y: size.height / 84)
                    let shadow = CGRect(x: 12, y: 68, width: moment.pose == .sitting || moment.pose == .grooming ? 70 : 96, height: 12)
                    canvas.drawLayer { layer in
                        layer.addFilter(.blur(radius: 3))
                        layer.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(0.48)))
                    }
                    if moment.facingRight {
                        canvas.translateBy(x: 120, y: 0); canvas.scaleBy(x: -1, y: 1)
                    }
                    drawCat(in: &canvas, pose: moment.pose, time: motion ? time : 0)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .offset(x: roomWidth * 0.62 * moment.travel)
                .opacity(moment.visible ? 1 : 0)
                .allowsHitTesting(excursionStarted == nil)
                .accessibilityLabel("Tower cat. Tap to send her exploring; she returns in a few seconds.")
                .accessibilityHidden(!moment.visible)
        }
        .task(id: excursionStarted) {
            guard excursionStarted != nil else { return }
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            excursionStarted = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { excursionStarted = nil }
        }
    }

    private func drawCat(in ctx: inout GraphicsContext, pose: TowerCatPose, time: Double) {
        let fur = Color(red: 0.73, green: 0.42, blue: 0.22)
        let light = Color(red: 0.95, green: 0.67, blue: 0.37)
        let dark = Color(red: 0.39, green: 0.22, blue: 0.14)
        let breath = sin(time * 1.5) * 0.8
        var head = CGPoint(x: 14, y: 44)
        var body = CGRect(x: 29, y: 41 - breath, width: 70, height: 31 + breath)
        var tail = Path()
        var feet = Path()
        switch pose {
        case .sleeping:
            tail.move(to: CGPoint(x: 91, y: 57))
            tail.addCurve(to: CGPoint(x: 48, y: 70), control1: CGPoint(x: 116, y: 75), control2: CGPoint(x: 66, y: 78))
        case .sitting, .grooming:
            head = CGPoint(x: 30, y: pose == .grooming ? 20 : 10)
            body = CGRect(x: 35, y: 30, width: 43, height: 43)
            tail.move(to: CGPoint(x: 74, y: 57)); tail.addQuadCurve(to: CGPoint(x: 99, y: 68), control: CGPoint(x: 109, y: 49))
            feet.move(to: CGPoint(x: 43, y: 48)); feet.addLine(to: CGPoint(x: 42, y: 69))
            feet.move(to: CGPoint(x: 62, y: 47)); feet.addLine(to: CGPoint(x: 66, y: 69))
        case .stretching:
            head = CGPoint(x: 9, y: 44)
            body = CGRect(x: 36, y: 34, width: 63, height: 25)
            feet.move(to: CGPoint(x: 44, y: 48)); feet.addLine(to: CGPoint(x: 24, y: 69))
            feet.move(to: CGPoint(x: 87, y: 49)); feet.addLine(to: CGPoint(x: 100, y: 69))
            tail.move(to: CGPoint(x: 94, y: 41)); tail.addQuadCurve(to: CGPoint(x: 103, y: 15), control: CGPoint(x: 120, y: 26))
        case .running:
            let stride = sin(time * 22) * 11
            head = CGPoint(x: 10, y: 30 + abs(stride) * 0.1)
            body = CGRect(x: 34, y: 35, width: 64, height: 25)
            for (x, phase) in [(42.0, 1.0), (52.0, -1.0), (82.0, -1.0), (91.0, 1.0)] {
                feet.move(to: CGPoint(x: x, y: 51)); feet.addLine(to: CGPoint(x: x + stride * phase, y: 70 - abs(stride) * 0.2))
            }
            tail.move(to: CGPoint(x: 93, y: 40)); tail.addQuadCurve(to: CGPoint(x: 117, y: 26), control: CGPoint(x: 110, y: 42))
        }
        ctx.stroke(tail, with: .color(fur), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        ctx.stroke(feet, with: .color(fur), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        ctx.fill(Path(ellipseIn: body), with: .linearGradient(Gradient(colors: [light, fur]), startPoint: body.origin, endPoint: CGPoint(x: body.maxX, y: body.maxY)))
        for x in stride(from: body.minX + 15, through: body.maxX - 10, by: 12) {
            var stripe = Path(); stripe.move(to: CGPoint(x: x, y: body.minY + 3))
            stripe.addQuadCurve(to: CGPoint(x: x - 3, y: body.minY + 12), control: CGPoint(x: x + 1, y: body.minY + 8))
            ctx.stroke(stripe, with: .color(dark.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        // Closed eyes and tucked muzzle for the sleeping pose; small raised paw for grooming.
        var ears = Path()
        ears.move(to: CGPoint(x: head.x + 2, y: head.y + 10))
        ears.addLine(to: CGPoint(x: head.x + 3, y: head.y - 9))
        ears.addLine(to: CGPoint(x: head.x + 16, y: head.y + 1))
        ears.addLine(to: CGPoint(x: head.x + 27, y: head.y - 8))
        ears.addLine(to: CGPoint(x: head.x + 32, y: head.y + 13)); ears.closeSubpath()
        ctx.fill(ears, with: .color(fur))
        ctx.fill(Path(ellipseIn: CGRect(x: head.x, y: head.y, width: 35, height: 27)), with: .linearGradient(Gradient(colors: [light, fur]), startPoint: head, endPoint: CGPoint(x: head.x + 35, y: head.y + 27)))
        ctx.fill(Path(ellipseIn: CGRect(x: head.x + 9, y: head.y + 16, width: 16, height: 9)), with: .color(TowerStyle.paper.opacity(0.5)))
        for x in [head.x + 9, head.x + 25] {
            if pose == .sleeping || pose == .grooming || pose == .stretching {
                var eye = Path(); eye.move(to: CGPoint(x: x - 3, y: head.y + 13))
                eye.addQuadCurve(to: CGPoint(x: x + 3, y: head.y + 13), control: CGPoint(x: x, y: head.y + 16))
                ctx.stroke(eye, with: .color(dark), lineWidth: 1.3)
            } else {
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: head.y + 10, width: 3, height: 6)), with: .color(TowerStyle.ink))
            }
        }
        ctx.fill(Path(ellipseIn: CGRect(x: head.x + 16, y: head.y + 18, width: 3, height: 2)), with: .color(dark))
        if pose == .grooming {
            let pawY = 45 + sin(time * 3) * 2
            var paw = Path(); paw.move(to: CGPoint(x: 65, y: 56)); paw.addLine(to: CGPoint(x: 58, y: pawY))
            ctx.stroke(paw, with: .color(light), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        }
    }
}
