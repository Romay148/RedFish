import Foundation
import UIKit

enum PhotoStorageError: Error {
    case writeFailed
}

/// Stockage fichiers sous Application Support / RedFish / rolls / {monthKey} / …
@MainActor
final class PhotoStorage {
    static let shared = PhotoStorage()

    private let fileManager = FileManager.default

    private var baseRollsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RedFish/rolls", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func directoryURL(forMonthKey monthKey: String) -> URL {
        let dir = baseRollsDirectory.appendingPathComponent(monthKey, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func fileURL(monthKey: String, relativeFileName: String) -> URL {
        directoryURL(forMonthKey: monthKey).appendingPathComponent(relativeFileName)
    }

    func saveJPEG(data: Data, monthKey: String) throws -> String {
        let name = UUID().uuidString + ".jpg"
        let url = fileURL(monthKey: monthKey, relativeFileName: name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            throw PhotoStorageError.writeFailed
        }
    }

    func loadImage(monthKey: String, relativeFileName: String) -> UIImage? {
        let url = fileURL(monthKey: monthKey, relativeFileName: relativeFileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func deleteRollFiles(monthKey: String) {
        let dir = directoryURL(forMonthKey: monthKey)
        try? fileManager.removeItem(at: dir)
    }
}
