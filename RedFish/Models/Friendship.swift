import Foundation

enum FriendshipStatus: String, Codable, Sendable {
    case pending
    case accepted
}

struct Friendship: Identifiable, Hashable, Sendable {
    let id: String
    let fromUid: String
    let fromUsername: String?
    let toUid: String
    let status: FriendshipStatus
    let createdAt: Date
    let acceptedAt: Date?
}
