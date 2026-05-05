import SwiftUI
import SwiftData

@main
struct RedFishApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FilmRoll.self, Shot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Impossible de créer le stockage: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
