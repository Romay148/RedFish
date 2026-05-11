import SwiftData
import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct RedFishApp: App {
    @StateObject private var session = SocialSessionStore()
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
                .environmentObject(session)
        }
        .modelContainer(sharedModelContainer)
    }

    init() {
#if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
#endif
    }
}
