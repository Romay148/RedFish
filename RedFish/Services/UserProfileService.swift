import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class UserProfileService {
    static let shared = UserProfileService()

    private init() {}

    private func normalize(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func validate(username: String) throws -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 24 else { throw BackendError.invalidUsername }
        guard trimmed.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
            throw BackendError.invalidUsername
        }
        return trimmed
    }

    func fetchMyProfile(uid: String) async throws -> RemoteUser? {
#if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let snap = try await db.collection("users").document(uid).getDocument()
        guard let data = snap.data() else { return nil }
        let username = data["username"] as? String ?? ""
        let normalized = data["usernameNormalized"] as? String ?? normalize(username)
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return RemoteUser(id: uid, username: username, usernameNormalized: normalized, createdAt: createdAt)
#else
        throw BackendError.firebaseUnavailable
#endif
    }

    func ensureUsername(uid: String, username: String) async throws -> RemoteUser {
#if canImport(FirebaseFirestore)
        let validated = try validate(username: username)
        let normalized = normalize(validated)
        let db = Firestore.firestore()
        let existing = try await db.collection("users")
            .whereField("usernameNormalized", isEqualTo: normalized)
            .getDocuments()
        if existing.documents.contains(where: { $0.documentID != uid }) {
            throw BackendError.usernameTaken
        }
        try await db.collection("users").document(uid).setData([
            "username": validated,
            "usernameNormalized": normalized,
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true)
        return RemoteUser(id: uid, username: validated, usernameNormalized: normalized, createdAt: Date())
#else
        throw BackendError.firebaseUnavailable
#endif
    }

    func findByUsername(_ username: String) async throws -> RemoteUser? {
#if canImport(FirebaseFirestore)
        let normalized = normalize(username)
        let db = Firestore.firestore()
        let snaps = try await db.collection("users")
            .whereField("usernameNormalized", isEqualTo: normalized)
            .limit(to: 1)
            .getDocuments()
        guard let first = snaps.documents.first else { return nil }
        let data = first.data()
        let uname = data["username"] as? String ?? normalized
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return RemoteUser(id: first.documentID, username: uname, usernameNormalized: normalized, createdAt: createdAt)
#else
        throw BackendError.firebaseUnavailable
#endif
    }
}
