import SwiftUI

private enum AuthScreenMode: String, CaseIterable, Identifiable {
    case login = "Connexion"
    case register = "Inscription"
    var id: String { rawValue }
}

/// Écran de connexion / inscription (API VPS).
@MainActor
struct UsernameSetupView: View {
    @EnvironmentObject private var session: SocialSessionStore
    @FocusState private var focusedField: Field?

    @State private var mode: AuthScreenMode = .login
    @State private var username = ""
    @State private var password = ""
    @State private var isSaving = false

    private enum Field {
        case username, password
    }

    private let brand = Color(red: 239 / 255, green: 112 / 255, blue: 129 / 255)
    private let brandDeep = Color(red: 210 / 255, green: 78 / 255, blue: 98 / 255)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 255 / 255, green: 248 / 255, blue: 250 / 255),
                    Color(red: 255 / 255, green: 236 / 255, blue: 242 / 255),
                    Color(red: 252 / 255, green: 228 / 255, blue: 236 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 12)
                        .padding(.bottom, 28)

                    Picker("", selection: $mode) {
                        ForEach(AuthScreenMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)
                    .onChange(of: mode) { _, _ in
                        session.errorMessage = nil
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        fieldBlock(
                            title: "Nom d'utilisateur",
                            hint: "3 à 24 caractères : lettres, chiffres, . _ -",
                            content: {
                                TextField("", text: $username, prompt: Text("ex. alice").foregroundStyle(.tertiary))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .username)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                            }
                        )

                        fieldBlock(
                            title: "Mot de passe",
                            hint: mode == .register ? "Au moins 6 caractères (règle serveur)." : " ",
                            content: {
                                SecureField("", text: $password, prompt: Text("••••••••").foregroundStyle(.tertiary))
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.go)
                                    .onSubmit { if canSubmit { submit() } }
                            }
                        )
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.background.opacity(0.92))
                            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
                    }
                    .padding(.top, 22)

                    Button(action: submit) {
                        HStack(spacing: 10) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(mode == .register ? "Créer mon compte" : "Se connecter")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(canSubmit && !isSaving ? AnyShapeStyle(LinearGradient(
                                    colors: [brand, brandDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )) : AnyShapeStyle(Color.gray.opacity(0.35)))
                        }
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || isSaving)
                    .padding(.top, 24)

                    Text(apiFootnote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                        .padding(.horizontal, 8)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert("Connexion", isPresented: .constant(session.errorMessage != nil), actions: {
            Button("OK") { session.errorMessage = nil }
        }, message: {
            Text(session.errorMessage ?? "")
        })
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [brand.opacity(0.35), brand.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                Image(systemName: "camera.aperture")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: [brand, brandDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            Text("RedFish")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(mode == .register ? "Rejoins le fil entre amis." : "Bienvenue — connecte-toi pour continuer.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var apiFootnote: String {
        let base = RedFishAPIConfig.baseURLString
        return "Serveur : \(base)"
    }

    @ViewBuilder
    private func fieldBlock(title: String, hint: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                }
            if hint.trimmingCharacters(in: .whitespaces).isEmpty == false {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var canSubmit: Bool {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return u.isEmpty == false && password.isEmpty == false
    }

    private func submit() {
        focusedField = nil
        isSaving = true
        Task {
            if mode == .register {
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

#Preview {
    UsernameSetupView()
        .environmentObject(SocialSessionStore())
}
