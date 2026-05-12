import Foundation

enum BackendError: LocalizedError {
    case notAuthenticated
    case usernameTaken
    case invalidUsername
    case userNotFound
    case friendshipExists
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Utilisateur non authentifié."
        case .usernameTaken:
            return "Ce nom d'utilisateur est déjà pris."
        case .invalidUsername:
            return "Nom d'utilisateur invalide."
        case .userNotFound:
            return "Utilisateur introuvable."
        case .friendshipExists:
            return "Une relation d'amitié existe déjà."
        case .generic(let message):
            return message
        }
    }
}
