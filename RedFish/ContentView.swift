import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            CameraCaptureView()
                .tabItem { Label("Caméra", systemImage: "camera.fill") }
            GalleryView()
                .tabItem { Label("Galerie", systemImage: "photo.on.rectangle.angled") }
            FeedView()
                .tabItem { Label("Fil", systemImage: "person.2.fill") }
        }
        .task {
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
