import SwiftData
import SwiftUI

struct GalleryView: View {
    @Query(sort: \FilmRoll.monthKey, order: .reverse) private var rolls: [FilmRoll]
    @Environment(\.modelContext) private var modelContext

    private var service: RollService { RollService(modelContext: modelContext) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(rolls, id: \.monthKey) { roll in
                    NavigationLink {
                        RollDetailView(
                            roll: roll,
                            imagesVisible: service.imagesAreVisible(for: roll)
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(monthLabel(roll.monthKey))
                                    .font(.headline)
                                Text(statusLine(for: roll))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(roll.shotCount)/\(RollConstants.maxShotsPerRoll)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Galerie")
        }
    }

    private func monthLabel(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]) else { return key }
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "fr_FR")
        guard let date = cal.date(from: DateComponents(year: y, month: m)) else { return key }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "LLLL yyyy"
        return fmt.string(from: date).capitalized
    }

    private func statusLine(for roll: FilmRoll) -> String {
        switch roll.displayState {
        case .activeShooting:
            return "En cours — clichés masqués"
        case .awaitingDevelopment:
            return "À développer"
        case .developed:
            return roll.shotCount == RollConstants.maxShotsPerRoll ? "Pellicule complète" : "Développée (mois écoulé)"
        }
    }
}
