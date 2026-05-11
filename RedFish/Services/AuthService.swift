import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class AuthService {
    static let shared = AuthService()

    private init() {}

    func signInAnonymouslyIfNeeded() async throws -> String {
#if canImport(FirebaseAuth)
        if let uid = Auth.auth().currentUser?.uid { return uid }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
#else
        throw BackendError.firebaseUnavailable
#endif
    }

    var currentUID: String? {
#if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
#else
        return nil
#endif
    }
}
