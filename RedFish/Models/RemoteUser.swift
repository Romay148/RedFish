import Foundation

struct RemoteUser: Identifiable, Hashable, Sendable {
    let id: String
    let username: String
    let usernameNormalized: String
    let createdAt: Date
}
