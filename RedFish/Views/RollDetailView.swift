import SwiftData
import SwiftUI
import UIKit

@MainActor
struct RollDetailView: View {
    @EnvironmentObject private var session: SocialSessionStore
    @Bindable var roll: FilmRoll
    let imagesVisible: Bool
    @State private var isExporting = false
    @State private var isSharing = false
    @State private var exportMessage: String?
    @State private var showExportAlert = false
    @State private var showViewer = false
    @State private var selectedVisibleImageIndex = 0

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<RollConstants.maxShotsPerRoll, id: \.self) { slot in
                    slotView(index: slot)
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if imagesVisible {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            shareRollToFriendsFeed()
                        } label: {
                            if isSharing {
                                ProgressView()
                            } else {
                                Label("Partager", systemImage: "paperplane")
                            }
                        }
                        .disabled(isSharing)

                        Button {
                            exportRollToPhotoLibrary()
                        } label: {
                            if isExporting {
                                ProgressView()
                            } else {
                                Label("Exporter", systemImage: "square.and.arrow.down")
                            }
                        }
                        .disabled(isExporting)
                    }
                }
            }
        }
        .alert("Export pellicule", isPresented: $showExportAlert, actions: {
            Button("OK") { exportMessage = nil }
        }, message: {
            Text(exportMessage ?? "")
        })
        .fullScreenCover(isPresented: $showViewer) {
            RollPhotoViewer(
                images: visibleImages,
                monthKey: roll.monthKey,
                initialIndex: selectedVisibleImageIndex
            )
        }
    }

    private var title: String { roll.monthKey }
    private var visibleShots: [Shot] {
        guard imagesVisible else { return [] }
        return roll.sortedShots().filter {
            PhotoStorage.shared.loadImage(monthKey: roll.monthKey, relativeFileName: $0.relativeFileName) != nil
        }
    }
    private var visibleImages: [UIImage] {
        visibleShots.compactMap {
            PhotoStorage.shared.loadImage(monthKey: roll.monthKey, relativeFileName: $0.relativeFileName)
        }
    }

    @ViewBuilder
    private func slotView(index: Int) -> some View {
        let shot = roll.sortedShots().first { $0.index == index }
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemFill))
                .aspectRatio(1, contentMode: .fit)

            if let shot {
                if imagesVisible {
                    if let ui = PhotoStorage.shared.loadImage(monthKey: roll.monthKey, relativeFileName: shot.relativeFileName) {
                        Button {
                            openViewer(for: shot)
                        } label: {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    } else {
                        missingLabel
                    }
                } else {
                    hiddenPlaceholder
                }
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var hiddenPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "questionmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Non développé")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var missingLabel: some View {
        Image(systemName: "exclamationmark.triangle")
            .foregroundStyle(.orange)
    }

    private func openViewer(for shot: Shot) {
        guard let idx = visibleShots.firstIndex(where: { $0.index == shot.index }) else { return }
        selectedVisibleImageIndex = idx
        showViewer = true
    }

    private func exportRollToPhotoLibrary() {
        guard isExporting == false else { return }
        isExporting = true
        exportMessage = nil
        Task {
            let result = await PhotoLibraryExporter.shared.exportDevelopedRoll(roll)
            isExporting = false
            switch result {
            case .success(let savedCount):
                exportMessage = "\(savedCount) photo(s) exportée(s) dans l'app Photos."
            case .emptyRoll:
                exportMessage = "Cette pellicule ne contient aucune photo exportable."
            case .permissionDenied:
                exportMessage = "Accès Photos refusé. Autorisez RedFish dans Réglages > Confidentialité > Photos."
            case .failed(let message):
                exportMessage = "Export impossible: \(message)"
            }
            showExportAlert = true
        }
    }

    private func shareRollToFriendsFeed() {
        guard isSharing == false else { return }
        guard let token = session.accessToken else {
            exportMessage = "Connectez-vous d'abord (compte requis)."
            showExportAlert = true
            return
        }
        isSharing = true
        Task {
            do {
                try await ShareService.shared.shareRoll(roll, token: token)
                exportMessage = "Pellicule partagée avec vos amis."
            } catch {
                exportMessage = "Partage impossible: \(error.localizedDescription)"
            }
            isSharing = false
            showExportAlert = true
        }
    }
}
