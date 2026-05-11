import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class FriendService {
    static let shared = FriendService()

    private init() {}

    private func friendshipID(_ uidA: String, _ uidB: String) -> String {
        uidA < uidB ? "\(uidA)_\(uidB)" : "\(uidB)_\(uidA)"
    }

    func sendFriendRequest(from myUID: String, to username: String) async throws {
#if canImport(FirebaseFirestore)
        guard let target = try await UserProfileService.shared.findByUsername(username) else {
            throw BackendError.userNotFound
        }
        guard target.id != myUID else { throw BackendError.generic("Vous ne pouvez pas vous ajouter vous-même.") }

        let db = Firestore.firestore()
        let docID = friendshipID(myUID, target.id)
        let existing = try await db.collection("friendships").document(docID).getDocument()
        guard existing.exists == false else { throw BackendError.friendshipExists }

        try await db.collection("friendships").document(docID).setData([
            "fromUid": myUID,
            "toUid": target.id,
            "status": FriendshipStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "acceptedAt": NSNull()
        ])
#else
        throw BackendError.firebaseUnavailable
#endif
    }

    func pendingRequests(for myUID: String) async throws -> [Friendship] {
#if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let snaps = try await db.collection("friendships")
            .whereField("toUid", isEqualTo: myUID)
            .whereField("status", isEqualTo: FriendshipStatus.pending.rawValue)
            .getDocuments()
        return snaps.documents.map { doc in
            let d = doc.data()
            return Friendship(
                id: doc.documentID,
                fromUid: d["fromUid"] as? String ?? "",
                toUid: d["toUid"] as? String ?? "",
                status: .pending,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                acceptedAt: nil
            )
        }
#else
        throw BackendError.firebaseUnavailable
#endif
    }

    func acceptRequest(_ requestID: String) async throws {
#if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("friendships").document(requestID).setData([
            "status": FriendshipStatus.accepted.rawValue,
            "acceptedAt": FieldValue.serverTimestamp()
        ], merge: true)
#else
        throw BackendError.firebaseUnavailable
#endif
    }

    func acceptedFriendUIDs(for myUID: String) async throws -> [String] {
#if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let sent = try await db.collection("friendships")
            .whereField("fromUid", isEqualTo: myUID)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .getDocuments()
        let received = try await db.collection("friendships")
            .whereField("toUid", isEqualTo: myUID)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .getDocuments()

        var ids = Set<String>()
        for doc in sent.documents { ids.insert(doc.data()["toUid"] as? String ?? "") }
        for doc in received.documents { ids.insert(doc.data()["fromUid"] as? String ?? "") }
        ids.remove("")
        return Array(ids)
#else
        throw BackendError.firebaseUnavailable
#endif
    }
}
