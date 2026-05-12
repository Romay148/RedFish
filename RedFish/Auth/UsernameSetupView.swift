import SwiftUI

@MainActor
struct UsernameSetupView: View {
    @EnvironmentObject private var session: SocialSessionStore
    @State private var username = ""
    @State private var password = ""
    @State private var isRegisterMode = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section(isRegisterMode ? "Créer un compte" : "Connexion") {
                    TextField("Nom d'utilisateur", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Mot de passe", text: $password)
                }
                Section {
                    Button {
                        submit()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(isRegisterMode ? "S'inscrire" : "Se connecter")
                        }
                    }
                    .disabled(!canSubmit || isSaving)

                    Button {
                        isRegisterMode.toggle()
                        session.errorMessage = nil
                    } label: {
                        Text(isRegisterMode ? "J'ai déjà un compte" : "Créer un compte")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Compte RedFish")
            .alert("Erreur", isPresented: .constant(session.errorMessage != nil), actions: {
                Button("OK") { session.errorMessage = nil }
            }, message: {
                Text(session.errorMessage ?? "")
            })
        }
    }

    private var canSubmit: Bool {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return u.isEmpty == false && password.isEmpty == false
    }

    private func submit() {
        isSaving = true
        Task {
            if isRegisterMode {
                do {
                    _ = try UserProfileService.shared.validate(username: username)
                    await session.register(username: username, password: password)
                } catch {
                    session.errorMessage = error.localizedDescription
                }
            } else {
                await session.login(username: username, password: password)
            }
            isSaving = false
        }
    }
}
