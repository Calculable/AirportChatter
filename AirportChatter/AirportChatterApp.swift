import SwiftUI

@main
struct AirportChatterApp: App {
    @State private var coordinator = AudioCoordinator()
    @State private var roomSession = TowerRoomSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                .environment(roomSession)
        }
    }
}
