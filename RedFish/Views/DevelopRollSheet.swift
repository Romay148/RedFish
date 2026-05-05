import SwiftUI
import SwiftData

struct DevelopRollSheet: View {
    @Bindable var roll: FilmRoll
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Comme un vrai jetable : après développement, vos 30 photos seront visibles dans la Galerie, dans l’ordre.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    do {
                        try RollService.develop(roll: roll, in: modelContext)
                        dismiss()
                    } catch {
                        // conservé minimal ; erreurs rares (disque plein, etc.)
                    }
                } label: {
                    Text("Développer")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(roll.shots.count != FilmRoll.capacity)

                Spacer()
            }
            .padding(.top, 24)
            .background(Color.black)
            .navigationTitle("Développer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
