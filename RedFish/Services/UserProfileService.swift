import Foundation

@MainActor
final class UserProfileService {
    static let shared = UserProfileService()

    private init() {}

    private func normalize(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Valide un nom d’utilisateur (inscription ou saisie locale).
    func validate(username: String) throws -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 24 else { throw BackendError.invalidUsername }
        guard trimmed.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
            throw BackendError.invalidUsername
        }
        return trimmed
    }

    func normalizedUsername(_ username: String) -> String {
        normalize(username)
    }
}
