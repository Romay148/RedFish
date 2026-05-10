import Foundation
import SwiftData

/// Vue « réseau social » locale : dérivée d’une pellicule développée (pas de backend).
struct Post: Identifiable, Hashable {
    let monthKey: String
    let caption: String
    /// Chemins relatifs pour `PhotoStorage` (même mois que la pellicule).
    let imageRelativeNames: [String]

    var id: String { monthKey }

    static func fromDevelopedRoll(_ roll: FilmRoll) -> Post? {
        guard roll.displayState == .developed else { return nil }
        let names = roll.sortedShots().map(\.relativeFileName)
        guard !names.isEmpty else { return nil }
        return Post(
            monthKey: roll.monthKey,
            caption: formattedMonthCaption(roll.monthKey),
            imageRelativeNames: names
        )
    }

    private static func formattedMonthCaption(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]) else { return key }
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "fr_FR")
        let comps = DateComponents(year: y, month: m)
        guard let date = cal.date(from: comps) else { return key }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "LLLL yyyy"
        return fmt.string(from: date).capitalized
    }
}
