import Foundation
import UIKit

@MainActor
final class ShareService {
    static let shared = ShareService()

    private let api = RedFishAPIClient.shared

    private init() {}

    func shareRoll(_ roll: FilmRoll, token: String) async throws {
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

        var jpegData: [Data] = []
        for image in images {
            guard let data = image.jpegData(compressionQuality: 0.92) else { continue }
            jpegData.append(data)
        }
        guard jpegData.isEmpty == false else {
            throw BackendError.generic("Compression JPEG impossible.")
        }

        let caption = Post.fromDevelopedRoll(roll)?.caption ?? roll.monthKey
        try await api.createPost(token: token, monthKey: roll.monthKey, caption: caption, jpegData: jpegData)
    }
}
