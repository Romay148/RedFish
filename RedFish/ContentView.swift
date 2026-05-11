import SwiftData
import SwiftUI

@MainActor
struct ContentView: View {
    @EnvironmentObject private var session: SocialSessionStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    private let brandColor = Color(red: 239 / 255, green: 112 / 255, blue: 129 / 255)
    private let softPinkBackground = Color(red: 255 / 255, green: 241 / 255, blue: 245 / 255)

    var body: some View {
        ZStack {
            softPinkBackground
                .ignoresSafeArea()

            TabView {
                FeedView()
                    .tabItem { Label("Fil", systemImage: "person.2.fill") }
                FriendsView()
                    .tabItem { Label("Amis", systemImage: "person.crop.circle.badge.plus") }
                CameraCaptureView()
                    .tabItem { Label("Caméra", systemImage: "camera.fill") }
                GalleryView()
                    .tabItem { Label("Galerie", systemImage: "photo.on.rectangle.angled") }
            }
            .tint(brandColor)
        }
        .sheet(isPresented: Binding(
            get: { session.isBootstrapped && session.profile == nil },
            set: { _ in }
        )) {
            UsernameSetupView()
                .environmentObject(session)
        }
        .task {
            RollService(modelContext: modelContext).ensureCurrentRoll()
            if session.isBootstrapped == false {
                await session.bootstrap()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            RollService(modelContext: modelContext).ensureCurrentRoll()
        }
    }
}

#Preview {
    let schema = Schema([FilmRoll.self, Shot.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    return ContentView()
        .modelContainer(container)
}
