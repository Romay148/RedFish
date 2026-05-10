import SwiftUI

struct DevelopRollSheet: View {
    let monthKey: String
    let onFinish: () -> Void

    @State private var revealed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Pellicule \(monthKey)")
                    .font(.headline)
                Image(systemName: "film.stack")
                    .font(.system(size: 72))
                    .opacity(revealed ? 1 : 0.4)
                    .scaleEffect(revealed ? 1.08 : 0.92)
                    .animation(.spring(response: 0.45, dampingFraction: 0.65), value: revealed)

                Text(revealed ? "Vos 30 photos sont prêtes." : "Développement en cours…")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if revealed {
                    Button("Voir la galerie") {
                        onFinish()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Développement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    revealed = true
                }
            }
        }
    }
}

#Preview {
    DevelopRollSheet(monthKey: "2026-05") {}
}
