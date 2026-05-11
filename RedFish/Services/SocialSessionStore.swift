import Foundation

@MainActor
final class SocialSessionStore: ObservableObject {
    @Published var uid: String?
    @Published var profile: RemoteUser?
    @Published var isBootstrapped = false
    @Published var errorMessage: String?

    func bootstrap() async {
        do {
            let uid = try await AuthService.shared.signInAnonymouslyIfNeeded()
            self.uid = uid
            self.profile = try await UserProfileService.shared.fetchMyProfile(uid: uid)
            self.isBootstrapped = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            self.isBootstrapped = true
        }
    }

    func setUsername(_ username: String) async {
        guard let uid else { return }
        do {
            profile = try await UserProfileService.shared.ensureUsername(uid: uid, username: username)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
