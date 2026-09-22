import SwiftUI

@main
struct AirportChatterApp: App {
    @State private var coordinator = AudioCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
        }
    }
}
