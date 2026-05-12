import Foundation

@MainActor
final class FriendService {
    static let shared = FriendService()

    private let api = RedFishAPIClient.shared

    private init() {}

    func sendFriendRequest(token: String, to username: String) async throws {
        let target = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard target.isEmpty == false else {
            throw BackendError.generic("Indiquez un nom d'utilisateur.")
        }
        try await api.sendFriendRequest(token: token, targetUsername: target)
    }

    func pendingRequests(token: String) async throws -> [Friendship] {
        let dtos = try await api.fetchIncomingFriendRequests(token: token)
        return dtos.map { dto in
            Friendship(
                id: dto.id,
                fromUid: dto.fromUserId,
                fromUsername: dto.fromUsername,
                toUid: dto.toUserId,
                status: .pending,
                createdAt: dto.createdAt ?? Date(),
                acceptedAt: nil
            )
        }
    }

    func acceptRequest(token: String, requestID: String) async throws {
        try await api.acceptFriendRequest(token: token, requestId: requestID)
    }
}
