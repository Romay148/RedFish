import Foundation
import SwiftData

enum RollService {
    /// Crée un rouleau pour le mois courant s'il n'existe pas encore.
    @discardableResult
    static func ensureCurrentMonthRoll(in context: ModelContext) throws -> FilmRoll {
        let key = FilmRoll.monthKey()
        let fd = FetchDescriptor<FilmRoll>(
            predicate: #Predicate<FilmRoll> { $0.monthKey == key }
        )
        let existing = try context.fetch(fd)
        if let first = existing.first {
            return first
        }
        let roll = FilmRoll(monthKey: key)
        context.insert(roll)
        try context.save()
        return roll
    }

    /// Rouleaux non développés, du plus récent au plus ancien (par mois).
    static func undevelopedRolls(in context: ModelContext) throws -> [FilmRoll] {
        var fd = FetchDescriptor<FilmRoll>(
            predicate: #Predicate<FilmRoll> { $0.isDeveloped == false },
            sortBy: [SortDescriptor(\.monthKey, order: .reverse)]
        )
        return try context.fetch(fd)
    }

    static func developedRolls(in context: ModelContext) throws -> [FilmRoll] {
        var fd = FetchDescriptor<FilmRoll>(
            predicate: #Predicate<FilmRoll> { $0.isDeveloped == true },
            sortBy: [SortDescriptor(\.developedAt, order: .reverse)]
        )
        return try context.fetch(fd)
    }

    static func develop(roll: FilmRoll, in context: ModelContext) throws {
        guard roll.shots.count == FilmRoll.capacity else { return }
        roll.isDeveloped = true
        roll.developedAt = Date()
        try context.save()
    }
}
