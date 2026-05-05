import Foundation
import SwiftData

@Model
final class FilmRoll {
    var id: UUID
    /// Clé calendaire du rouleau mensuel, ex. "2026-05"
    var monthKey: String
    var createdAt: Date
    var isDeveloped: Bool
    var developedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Shot.filmRoll)
    var shots: [Shot]

    init(
        id: UUID = UUID(),
        monthKey: String,
        createdAt: Date = Date(),
        isDeveloped: Bool = false,
        developedAt: Date? = nil,
        shots: [Shot] = []
    ) {
        self.id = id
        self.monthKey = monthKey
        self.createdAt = createdAt
        self.isDeveloped = isDeveloped
        self.developedAt = developedAt
        self.shots = shots
    }

    var shotsCount: Int { shots.count }
    var isFull: Bool { shots.count >= FilmRoll.capacity }
    static let capacity = 30

    static func monthKey(for date: Date = Date()) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return String(format: "%04d-%02d", y, m)
    }

    /// Libellé lisible pour `monthKey` au format `yyyy-MM`.
    var displayMonthTitle: String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]) else { return monthKey }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = 1
        let cal = Calendar.current
        guard let date = cal.date(from: comps) else { return monthKey }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f.string(from: date).capitalized
    }
}
