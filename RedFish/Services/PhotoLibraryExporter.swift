import Foundation
import Photos
import UIKit

enum PhotoLibraryExportResult: Equatable {
    case success(savedCount: Int)
    case emptyRoll
    case permissionDenied
    case failed(message: String)
}

@MainActor
final class PhotoLibraryExporter {
    static let shared = PhotoLibraryExporter()

    private init() {}

    func exportDevelopedRoll(_ roll: FilmRoll) async -> PhotoLibraryExportResult {
        let images = roll.sortedShots().compactMap {
            PhotoStorage.shared.loadImage(monthKey: roll.monthKey, relativeFileName: $0.relativeFileName)
        }
        guard images.isEmpty == false else { return .emptyRoll }

        let permission = await requestPhotoLibraryPermissionIfNeeded()
        guard permission else { return .permissionDenied }

        do {
            let collection = try await fetchOrCreateAlbum(named: albumName(for: roll.monthKey))
            let identifiers = try await createAssets(from: images)
            guard identifiers.isEmpty == false else {
                return .failed(message: "Aucune image n'a pu être exportée.")
            }
            try await addAssets(with: identifiers, to: collection)
            return .success(savedCount: identifiers.count)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    private func albumName(for monthKey: String) -> String {
        "RedFish \(monthKey)"
    }

    private func requestPhotoLibraryPermissionIfNeeded() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch current {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return status == .authorized || status == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func fetchOrCreateAlbum(named name: String) async throws -> PHAssetCollection {
        if let existing = fetchAlbum(named: name) { return existing }
        let placeholder = try await createAlbum(named: name)
        guard let created = fetchAlbum(localIdentifier: placeholder.localIdentifier) else {
            throw NSError(domain: "PhotoLibraryExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Album introuvable après création."])
        }
        return created
    }

    private func fetchAlbum(named name: String) -> PHAssetCollection? {
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var match: PHAssetCollection?
        fetch.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == name {
                match = collection
                stop.pointee = true
            }
        }
        return match
    }

    private func fetchAlbum(localIdentifier: String) -> PHAssetCollection? {
        PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    private func createAlbum(named name: String) async throws -> PHObjectPlaceholder {
        try await withCheckedThrowingContinuation { continuation in
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                placeholder = request.placeholderForCreatedAssetCollection
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success, let placeholder {
                    continuation.resume(returning: placeholder)
                } else {
                    continuation.resume(throwing: NSError(domain: "PhotoLibraryExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Impossible de créer l'album Photos."]))
                }
            }
        }
    }

    private func createAssets(from images: [UIImage]) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            var placeholders: [PHObjectPlaceholder] = []
            PHPhotoLibrary.shared().performChanges({
                for image in images {
                    guard let data = image.jpegData(compressionQuality: 0.95) else { continue }
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: data, options: nil)
                    if let placeholder = request.placeholderForCreatedAsset {
                        placeholders.append(placeholder)
                    }
                }
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: placeholders.map(\.localIdentifier))
                } else {
                    continuation.resume(throwing: NSError(domain: "PhotoLibraryExporter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Échec de création des photos dans la photothèque."]))
                }
            }
        }
    }

    private func addAssets(with identifiers: [String], to collection: PHAssetCollection) async throws {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                if let request = PHAssetCollectionChangeRequest(for: collection) {
                    request.addAssets(fetch)
                }
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "PhotoLibraryExporter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Échec d'ajout des photos dans l'album."]))
                }
            }
        }
    }
}
