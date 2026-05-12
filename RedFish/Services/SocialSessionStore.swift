import Foundation

@MainActor
final class SocialSessionStore: ObservableObject {
    @Published var uid: String?
    @Published var profile: RemoteUser?
    /// Jeton JWT pour les appels API (persisté dans le Keychain entre lancements).
    @Published private(set) var accessToken: String?
    @Published var isBootstrapped = false
    @Published var errorMessage: String?

    private let api = RedFishAPIClient.shared

    func bootstrap() async {
        errorMessage = nil
        guard let token = TokenKeychain.read() else {
            accessToken = nil
            uid = nil
            profile = nil
            isBootstrapped = true
            return
        }
        accessToken = token
        do {
            let me = try await api.fetchMe(token: token)
            applyAuth(token: token, user: me)
            isBootstrapped = true
        } catch {
            TokenKeychain.delete()
            accessToken = nil
            uid = nil
            profile = nil
            isBootstrapped = true
        }
    }

    private func applyAuth(token: String, user: RedFishAPIClient.AuthUserDTO) {
        accessToken = token
        uid = user.id
        let norm = user.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        profile = RemoteUser(
            id: user.id,
            username: user.username,
            usernameNormalized: norm,
            createdAt: user.createdAt ?? Date()
        )
    }

    func login(username: String, password: String) async {
        do {
            let r = try await api.login(username: username, password: password)
            try TokenKeychain.save(r.accessToken)
            applyAuth(token: r.accessToken, user: r.user)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(username: String, password: String) async {
        do {
            let r = try await api.register(username: username, password: password)
            try TokenKeychain.save(r.accessToken)
            applyAuth(token: r.accessToken, user: r.user)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        TokenKeychain.delete()
        accessToken = nil
        uid = nil
        profile = nil
    }
}
