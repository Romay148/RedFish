import Foundation
import UIKit

enum PhotoStorage {
    private static let rollsFolderName = "FilmRolls"

    static var rollsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(rollsFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func rollDirectory(rollId: UUID) -> URL {
        let dir = rollsDirectory.appendingPathComponent(rollId.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fileURL(rollId: UUID, index: Int) -> URL {
        rollDirectory(rollId: rollId).appendingPathComponent(String(format: "shot_%02d.jpg", index))
    }

    /// Nom relatif stocké en base (sous-dossier uuid / fichier)
    static func relativeName(rollId: UUID, index: Int) -> String {
        "\(rollId.uuidString)/shot_\(String(format: "%02d", index)).jpg"
    }

    static func absoluteURL(forRelativePath relative: String) -> URL {
        rollsDirectory.appendingPathComponent(relative)
    }

    static func saveJPEG(_ image: UIImage, rollId: UUID, index: Int) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            throw PhotoStorageError.encodingFailed
        }
        let url = fileURL(rollId: rollId, index: index)
        try data.write(to: url, options: .atomic)
        return relativeName(rollId: rollId, index: index)
    }

    static func deleteRollFiles(rollId: UUID) {
        let dir = rollDirectory(rollId: rollId)
        try? FileManager.default.removeItem(at: dir)
    }

    enum PhotoStorageError: Error {
        case encodingFailed
    }
}
