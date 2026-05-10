import SwiftData
import SwiftUI
import UIKit

@MainActor
struct RollDetailView: View {
    @Bindable var roll: FilmRoll
    let imagesVisible: Bool

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
    }

    private var title: String { roll.monthKey }

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
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
}
