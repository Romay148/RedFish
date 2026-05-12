import Foundation

struct RemotePost: Identifiable, Hashable, Sendable {
    let id: String
    let ownerUid: String
    let ownerUsername: String
    let monthKey: String
    let caption: String
    let imagePaths: [String]
    let createdAt: Date
    let visibility: String
}
