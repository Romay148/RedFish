import Foundation
import SwiftData

@Model
final class FilmRoll {
    /// Clé stable `yyyy-MM` pour le mois calendaire.
    @Attribute(.unique) var monthKey: String
    var displayStateRaw: String
    @Relationship(deleteRule: .cascade, inverse: \Shot.roll)
    var shots: [Shot]

    init(monthKey: String, displayState: RollDisplayState = .activeShooting) {
        self.monthKey = monthKey
        self.displayStateRaw = displayState.rawValue
        self.shots = []
    }

    var displayState: RollDisplayState {
        get { RollDisplayState(rawValue: displayStateRaw) ?? .activeShooting }
        set { displayStateRaw = newValue.rawValue }
    }

    var shotCount: Int { shots.count }
    var isFull: Bool { shotCount >= RollConstants.maxShotsPerRoll }

    func sortedShots() -> [Shot] {
        shots.sorted { $0.index < $1.index }
    }
}
