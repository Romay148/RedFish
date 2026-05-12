import Foundation

/// Base de l’API REST (sans slash final). Modifie ici si ton VPS utilise un autre chemin.
enum RedFishAPIConfig {
    static let baseURLString = "https://rbm-test-utilisateur.sbs/RedFish/api/v1"

    static var baseURL: URL {
        URL(string: baseURLString)!
    }
}
