import Foundation

enum BackendError: LocalizedError {
    case firebaseUnavailable
    case notAuthenticated
    case usernameTaken
    case invalidUsername
    case userNotFound
    case friendshipExists
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            return "Firebase n'est pas configuré dans cette build."
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
