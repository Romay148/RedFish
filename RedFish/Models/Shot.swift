import Foundation
import SwiftData

@Model
final class Shot {
    var index: Int
    /// Nom de fichier relatif au dossier Application Support (opaque)
    var relativeFileName: String
    var capturedAt: Date
    var filmRoll: FilmRoll?

    init(index: Int, relativeFileName: String, capturedAt: Date = Date(), filmRoll: FilmRoll? = nil) {
        self.index = index
        self.relativeFileName = relativeFileName
        self.capturedAt = capturedAt
        self.filmRoll = filmRoll
    }
}
