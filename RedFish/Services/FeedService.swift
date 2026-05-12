import Foundation
import UIKit

@MainActor
final class FeedService {
    static let shared = FeedService()

    private let api = RedFishAPIClient.shared

    private init() {}

    func fetchFeed(token: String) async throws -> [RemotePost] {
        let dtos = try await api.fetchFeed(token: token)
        return dtos.map { dto in
            RemotePost(
                id: dto.id,
                ownerUid: dto.ownerId,
                ownerUsername: dto.ownerUsername,
                monthKey: dto.monthKey,
                caption: dto.caption,
                imagePaths: dto.imageUrls,
                createdAt: dto.createdAt ?? Date(),
                visibility: dto.visibility ?? "friends"
            )
        }
    }

    /// `imagePaths` contient des URL HTTPS absolues renvoyées par l’API.
    func loadImages(for post: RemotePost, token: String?) async -> [UIImage] {
        var images: [UIImage] = []
        for urlString in post.imagePaths {
            do {
                let img = try await api.downloadImage(from: urlString, token: token)
                images.append(img)
            } catch {
                continue
            }
        }
        return images
    }
}
