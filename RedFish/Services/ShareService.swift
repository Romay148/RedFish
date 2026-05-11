import Foundation
import UIKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

@MainActor
final class ShareService {
    static let shared = ShareService()

    private init() {}

    func shareRoll(_ roll: FilmRoll, ownerUID: String, ownerUsername: String) async throws {
#if canImport(FirebaseFirestore) && canImport(FirebaseStorage)
        guard roll.displayState == .developed else {
            throw BackendError.generic("Seules les pellicules développées peuvent être partagées.")
        }

        let shots = roll.sortedShots()
        let images: [UIImage] = shots.compactMap {
            PhotoStorage.shared.loadImage(monthKey: roll.monthKey, relativeFileName: $0.relativeFileName)
        }
        guard images.isEmpty == false else {
            throw BackendError.generic("Aucune image à partager.")
        }

        let storage = Storage.storage().reference()
        var paths: [String] = []
        for image in images {
            guard let data = image.jpegData(compressionQuality: 0.92) else { continue }
            let name = UUID().uuidString + ".jpg"
            let path = "users/\(ownerUID)/rolls/\(roll.monthKey)/\(name)"
            let ref = storage.child(path)
            _ = try await ref.putDataAsync(data, metadata: nil)
            paths.append(path)
        }

        let caption = Post.fromDevelopedRoll(roll)?.caption ?? roll.monthKey
        let db = Firestore.firestore()
        try await db.collection("posts").addDocument(data: [
            "ownerUid": ownerUID,
            "ownerUsername": ownerUsername,
            "monthKey": roll.monthKey,
            "caption": caption,
            "imagePaths": paths,
            "createdAt": FieldValue.serverTimestamp(),
            "visibility": "friends"
        ])
#else
        throw BackendError.firebaseUnavailable
#endif
    }
}
