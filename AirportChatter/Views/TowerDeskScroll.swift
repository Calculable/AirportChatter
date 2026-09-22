import SwiftUI

/// Keeps scroll updates local instead of re-filtering the station catalog every frame.
struct TowerDeskScroll<Room: View, Controls: View>: View {
    let roomHeight: CGFloat
    @ViewBuilder var room: (@escaping () -> Void) -> Room
    @ViewBuilder var controls: Controls
    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(spacing: 0) {
                    room {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
                            scroll.scrollTo("instruments", anchor: .top)
                        }
                    }
                    .frame(height: roomHeight)
                    // Offset only the scene back to its original viewport position.
                    // It stays within the scroll view, so exposed props remain tappable.
                    .offset(y: max(0, offset))
                    .zIndex(0)
                    controls.zIndex(1)
                }
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, value in
                offset = value
            }
#if DEBUG
            .task {
                if ProcessInfo.processInfo.arguments.contains("--tower-controls") {
                    await Task.yield()
                    scroll.scrollTo("instruments", anchor: .top)
                }
            }
#endif
        }
    }
}
