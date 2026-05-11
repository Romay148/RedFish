import SwiftUI

@MainActor
struct UsernameSetupView: View {
    @EnvironmentObject private var session: SocialSessionStore
    @State private var username = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Créer ton profil") {
                    TextField("Nom d'utilisateur", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Continuer")
                        }
                    }
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .navigationTitle("Bienvenue")
            .alert("Erreur", isPresented: .constant(session.errorMessage != nil), actions: {
                Button("OK") { session.errorMessage = nil }
            }, message: {
                Text(session.errorMessage ?? "")
            })
        }
    }

    private func save() {
        isSaving = true
        Task {
            await session.setUsername(username)
            isSaving = false
        }
    }
}
