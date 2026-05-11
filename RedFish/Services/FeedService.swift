import Foundation
import UIKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

@MainActor
final class FeedService {
    static let shared = FeedService()

    private init() {}

    func fetchFriendsPosts(myUID: String) async throws -> [RemotePost] {
#if canImport(FirebaseFirestore)
        var allowedUIDs = try await FriendService.shared.acceptedFriendUIDs(for: myUID)
        allowedUIDs.append(myUID)
        guard allowedUIDs.isEmpty == false else { return [] }

        let db = Firestore.firestore()
        // Firestore limite 'in' à 10 valeurs, suffisant pour V1 à très faible volume.
        let chunk = Array(allowedUIDs.prefix(10))
        let snaps = try await db.collection("posts")
            .whereField("ownerUid", in: chunk)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        return snaps.documents.map { doc in
            let d = doc.data()
            return RemotePost(
                id: doc.documentID,
                ownerUid: d["ownerUid"] as? String ?? "",
                ownerUsername: d["ownerUsername"] as? String ?? "Inconnu",
                monthKey: d["monthKey"] as? String ?? "",
                caption: d["caption"] as? String ?? "",
                imagePaths: d["imagePaths"] as? [String] ?? [],
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                visibility: d["visibility"] as? String ?? "friends"
            )
        }
#else
        throw BackendError.firebaseUnavailable
#endif
    }

    func loadImages(for post: RemotePost) async -> [UIImage] {
#if canImport(FirebaseStorage)
        var images: [UIImage] = []
        for path in post.imagePaths {
            do {
                let data = try await Storage.storage().reference(withPath: path).data(maxSize: 20 * 1024 * 1024)
                if let img = UIImage(data: data) { images.append(img) }
            } catch {
                continue
            }
        }
        return images
#else
        return []
#endif
    }
}
