import Foundation

/// État d’affichage / métier d’une pellicule mensuelle.
enum RollDisplayState: String, Codable, Sendable {
    /// Moins de 30 photos : captures possibles, images non visibles.
    case activeShooting
    /// 30 photos prises : attente de l’action « développer » pour révéler.
    case awaitingDevelopment
    /// Photos visibles (développement manuel, pellicule complète, ou passage de mois / partiel auto).
    case developed
}
