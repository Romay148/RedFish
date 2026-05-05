import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<FilmRoll> { $0.isDeveloped == false },
        sort: [SortDescriptor(\.monthKey, order: .reverse)]
    )
    private var undevelopedRolls: [FilmRoll]

    @State private var selectedRollId: UUID?

    var body: some View {
        TabView {
            NavigationStack {
                VStack(spacing: 0) {
                    rollSelector
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    if let roll = selectedRoll {
                        CameraCaptureView(roll: roll)
                            .id(roll.id)
                    } else {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                    }
                }
                .background(Color.black)
                .navigationTitle("RedFish")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.black, for: .navigationBar)
                .onAppear {
                    bootstrapRolls()
                }
                .onChange(of: undevelopedRolls.map(\.id)) { _, _ in
                    syncSelectionAfterRollChange()
                }
            }
            .tabItem {
                Label("Caméra", systemImage: "camera.fill")
            }

            GalleryView()
                .tabItem {
                    Label("Galerie", systemImage: "photo.on.rectangle")
                }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private var selectedRoll: FilmRoll? {
        guard let id = selectedRollId else { return undevelopedRolls.first }
        return undevelopedRolls.first(where: { $0.id == id }) ?? undevelopedRolls.first
    }

    private var rollSelector: some View {
        HStack {
            Text("Rouleau")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                ForEach(undevelopedRolls, id: \.id) { roll in
                    Button {
                        selectedRollId = roll.id
                    } label: {
                        HStack {
                            Text(roll.displayMonthTitle)
                            Text("(\(roll.shots.count)/\(FilmRoll.capacity))")
                            if roll.id == selectedRoll?.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedRoll?.displayMonthTitle ?? "—")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .disabled(undevelopedRolls.isEmpty)
        }
        .padding(12)
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func bootstrapRolls() {
        do {
            try RollService.ensureCurrentMonthRoll(in: modelContext)
            if selectedRollId == nil {
                selectedRollId = undevelopedRolls.first?.id
            }
        } catch {
            // échec persistance — rare
        }
    }

    private func syncSelectionAfterRollChange() {
        guard let id = selectedRollId else {
            selectedRollId = undevelopedRolls.first?.id
            return
        }
        if !undevelopedRolls.contains(where: { $0.id == id }) {
            selectedRollId = undevelopedRolls.first?.id
        }
    }
}

#Preview {
    let schema = Schema([FilmRoll.self, Shot.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    return ContentView()
        .modelContainer(container)
}
