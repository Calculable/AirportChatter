import SwiftUI

@main
struct TowerLoungeApp: App {
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
