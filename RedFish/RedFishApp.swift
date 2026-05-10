import SwiftData
import SwiftUI

@main
struct RedFishApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FilmRoll.self, Shot.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
