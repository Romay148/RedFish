import Foundation
import SwiftData

@MainActor
final class RollService {
    static let maxShotsPerRoll = RollConstants.maxShotsPerRoll

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Clé `yyyy-MM` pour la date donnée (calendrier courant, fuseau local).
    static func monthKey(for date: Date = .now) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return String(format: "%04d-%02d", y, m)
    }

    /// Compare deux clés `yyyy-MM` : true si a est strictement avant b.
    static func monthKey(_ a: String, isBefore b: String) -> Bool {
        a < b
    }

    /// Au lancement / retour au premier plan : finalise les anciens mois, garantit une pellicule pour le mois courant.
    func ensureCurrentRoll() {
        let currentKey = Self.monthKey()
        let descriptor = FetchDescriptor<FilmRoll>(sortBy: [SortDescriptor(\.monthKey, order: .forward)])
        let rolls = (try? modelContext.fetch(descriptor)) ?? []

        for roll in rolls where Self.monthKey(roll.monthKey, isBefore: currentKey) {
            switch roll.displayState {
            case .activeShooting:
                if roll.shots.isEmpty {
                    modelContext.delete(roll)
                } else {
                    roll.displayState = .developed
                }
            case .awaitingDevelopment:
                roll.displayState = .developed
            case .developed:
                break
            }
        }

        try? modelContext.save()

        let refreshed = (try? modelContext.fetch(FetchDescriptor<FilmRoll>())) ?? []
        if refreshed.contains(where: { $0.monthKey == currentKey }) == false {
            let newRoll = FilmRoll(monthKey: currentKey, displayState: .activeShooting)
            modelContext.insert(newRoll)
            try? modelContext.save()
        }
    }

    func currentRoll() -> FilmRoll? {
        let key = Self.monthKey()
        let predicate = #Predicate<FilmRoll> { $0.monthKey == key }
        var descriptor = FetchDescriptor<FilmRoll>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func allRollsSorted() -> [FilmRoll] {
        let descriptor = FetchDescriptor<FilmRoll>(sortBy: [SortDescriptor(\.monthKey, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    enum CaptureResult {
        case success(remaining: Int)
        case rollFull
        case notInShootingState
        case saveFailed
    }

    func capturePhoto(jpegData: Data) -> CaptureResult {
        guard let roll = currentRoll() else { return .saveFailed }

        switch roll.displayState {
        case .activeShooting:
            break
        case .awaitingDevelopment, .developed:
            return .notInShootingState
        }

        let existingCount = roll.shots.count
        guard existingCount < Self.maxShotsPerRoll else { return .rollFull }

        do {
            let fileName = try PhotoStorage.shared.saveJPEG(data: jpegData, monthKey: roll.monthKey)
            let nextIndex = existingCount
            let shot = Shot(index: nextIndex, relativeFileName: fileName, roll: roll)
            modelContext.insert(shot)

            let newCount = existingCount + 1
            if newCount >= Self.maxShotsPerRoll {
                roll.displayState = .awaitingDevelopment
            }

            try modelContext.save()
            let remaining = max(0, Self.maxShotsPerRoll - newCount)
            return .success(remaining: remaining)
        } catch {
            return .saveFailed
        }
    }

    func developCurrentRoll() {
        guard let roll = currentRoll(), roll.displayState == .awaitingDevelopment else { return }
        roll.displayState = .developed
        try? modelContext.save()
    }

    func canCaptureToday() -> Bool {
        guard let roll = currentRoll() else { return false }
        return roll.displayState == .activeShooting && roll.shotCount < Self.maxShotsPerRoll
    }

    /// Vrai si les clichés de cette pellicule peuvent être affichés.
    func imagesAreVisible(for roll: FilmRoll) -> Bool {
        roll.displayState == .developed
    }
}
