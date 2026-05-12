import Foundation
import UIKit

private struct APIErrorEnvelope: Decodable {
    let error: String?
}

@MainActor
final class RedFishAPIClient {
    static let shared = RedFishAPIClient()

    private let urlSession: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let d = formatter.date(from: str) { return d }
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            if let d = f2.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date invalide: \(str)")
        }
        jsonDecoder = decoder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        jsonEncoder = encoder
    }

    private func url(for path: String) -> URL {
        var base = RedFishAPIConfig.baseURLString
        if base.hasSuffix("/") { base.removeLast() }
        let p = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "\(base)/\(p)")!
    }

    private func throwIfNeeded(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.generic("Réponse HTTP invalide")
        }
        guard (200 ... 299).contains(http.statusCode) else {
            if let env = try? jsonDecoder.decode(APIErrorEnvelope.self, from: data), let msg = env.error, !msg.isEmpty {
                throw BackendError.generic(msg)
            }
            throw BackendError.generic("Erreur serveur (\(http.statusCode))")
        }
    }

    // MARK: - Auth

    struct AuthUserDTO: Decodable {
        let id: String
        let username: String
        let createdAt: Date?
    }

    struct AuthTokenDTO: Decodable {
        let accessToken: String
        let tokenType: String?
        let expiresIn: Int?
        let user: AuthUserDTO
    }

    private struct LoginBody: Encodable {
        let username: String
        let password: String
    }

    func register(username: String, password: String) async throws -> AuthTokenDTO {
        try await postAuth(path: "auth/register", username: username, password: password)
    }

    func login(username: String, password: String) async throws -> AuthTokenDTO {
        try await postAuth(path: "auth/login", username: username, password: password)
    }

    private func postAuth(path: String, username: String, password: String) async throws -> AuthTokenDTO {
        var req = URLRequest(url: url(for: path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try jsonEncoder.encode(LoginBody(username: username, password: password))
        let (data, resp) = try await urlSession.data(for: req)
        try throwIfNeeded(data: data, response: resp)
        return try jsonDecoder.decode(AuthTokenDTO.self, from: data)
    }

    // MARK: - Me

    func fetchMe(token: String) async throws -> AuthUserDTO {
        var req = URLRequest(url: url(for: "me"))
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await urlSession.data(for: req)
        try throwIfNeeded(data: data, response: resp)
        return try jsonDecoder.decode(AuthUserDTO.self, from: data)
    }

    // MARK: - Friends

    private struct FriendRequestBody: Encodable {
        let targetUsername: String
    }

    struct IncomingFriendRequestDTO: Decodable {
        let id: String
        let fromUserId: String
        let fromUsername: String?
        let toUserId: String
        let status: String
        let createdAt: Date?
    }

    private struct IncomingListDTO: Decodable {
        let requests: [IncomingFriendRequestDTO]
    }

    func sendFriendRequest(token: String, targetUsername: String) async throws {
        var req = URLRequest(url: url(for: "friends/requests"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try jsonEncoder.encode(FriendRequestBody(targetUsername: targetUsername))
        let (data, resp) = try await urlSession.data(for: req)
        try throwIfNeeded(data: data, response: resp)
    }

    func fetchIncomingFriendRequests(token: String) async throws -> [IncomingFriendRequestDTO] {
        var req = URLRequest(url: url(for: "friends/requests/incoming"))
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await urlSession.data(for: req)
        try throwIfNeeded(data: data, response: resp)
        let list = try jsonDecoder.decode(IncomingListDTO.self, from: data)
        return list.requests
    }

    func acceptFriendRequest(token: String, requestId: String) async throws {
        var req = URLRequest(url: url(for: "friends/requests/\(requestId)/accept"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await urlSession.data(for: req)
        try throwIfNeeded(data: data, response: resp)
    }

    // MARK: - Feed

    struct FeedPostDTO: Decodable {
        let id: String
        let ownerId: String
        let ownerUsername: String
        let monthKey: String
        let caption: String
        let imageUrls: [String]
        let createdAt: Date?
        let visibility: String?
    }

    private struct FeedEnvelope: Decodable {
        let posts: [FeedPostDTO]
    }

    func fetchFeed(token: String) async throws -> [FeedPostDTO] {
        var req = URLRequest(url: url(for: "feed"))
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await urlSession.data(for: req)
        try throwIfNeeded(data: data, response: resp)
        let env = try jsonDecoder.decode(FeedEnvelope.self, from: data)
        return env.posts
    }

    func downloadImage(from urlString: String, token: String?) async throws -> UIImage {
        guard let u = URL(string: urlString) else {
            throw BackendError.generic("URL image invalide")
        }
        var req = URLRequest(url: u)
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await urlSession.data(for: req)
        try throwIfNeeded(data: data, response: resp)
        guard let img = UIImage(data: data) else {
            throw BackendError.generic("Image invalide")
        }
        return img
    }

    // MARK: - Posts (multipart)

    func createPost(token: String, monthKey: String, caption: String, jpegData: [Data]) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        appendField(name: "month_key", value: monthKey)
        appendField(name: "caption", value: caption)

        for (idx, data) in jpegData.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            let filename = "shot-\(idx).jpg"
            body.append(
                "Content-Disposition: form-data; name=\"images\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!
            )
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: url(for: "posts"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = body

        let (data, resp) = try await urlSession.data(for: req)
        try throwIfNeeded(data: data, response: resp)
    }
}
