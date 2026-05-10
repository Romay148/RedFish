import Foundation
import SwiftData

@Model
final class Shot {
    var index: Int
    /// Nom de fichier relatif au dossier stockage du mois (ex: `uuid.jpg`).
    var relativeFileName: String
    var createdAt: Date
    var roll: FilmRoll?

    init(index: Int, relativeFileName: String, createdAt: Date = .now, roll: FilmRoll? = nil) {
        self.index = index
        self.relativeFileName = relativeFileName
        self.createdAt = createdAt
        self.roll = roll
    }
}
