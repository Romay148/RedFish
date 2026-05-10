import Foundation
import UIKit

enum PhotoStorageError: Error {
    case writeFailed
}

/// Stockage fichiers sous Application Support / RedFish / rolls / {monthKey} / …
/// Pas `@MainActor` : les corps de `ForEach` / `ViewBuilder` sont souvent **non isolés** par le compilateur ;
/// on sérialise l’accès disque avec un verrou (appels UI toujours sur le fil principal en pratique).
final class PhotoStorage {
    static let shared = PhotoStorage()

    private let fileManager = FileManager.default
    private let lock = NSLock()

    private func baseRollsDirectoryWhileLocked() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RedFish/rolls", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func directoryURL(forMonthKey monthKey: String) -> URL {
        lock.lock()
        defer { lock.unlock() }
        let dir = baseRollsDirectoryWhileLocked().appendingPathComponent(monthKey, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func fileURL(monthKey: String, relativeFileName: String) -> URL {
        lock.lock()
        defer { lock.unlock() }
        let dir = baseRollsDirectoryWhileLocked().appendingPathComponent(monthKey, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(relativeFileName)
    }

    func saveJPEG(data: Data, monthKey: String) throws -> String {
        let name = UUID().uuidString + ".jpg"
        lock.lock()
        let dir = baseRollsDirectoryWhileLocked().appendingPathComponent(monthKey, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        lock.unlock()
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            throw PhotoStorageError.writeFailed
        }
    }

    func loadImage(monthKey: String, relativeFileName: String) -> UIImage? {
        lock.lock()
        let dir = baseRollsDirectoryWhileLocked().appendingPathComponent(monthKey, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent(relativeFileName).path
        lock.unlock()
        guard fileManager.fileExists(atPath: path) else { return nil }
        return UIImage(contentsOfFile: path)
    }

    func deleteRollFiles(monthKey: String) {
        lock.lock()
        defer { lock.unlock() }
        let dir = baseRollsDirectoryWhileLocked().appendingPathComponent(monthKey, isDirectory: true)
        try? fileManager.removeItem(at: dir)
    }
}
