import SwiftUI
import SwiftData

struct GalleryView: View {
    @Query(
        filter: #Predicate<FilmRoll> { $0.isDeveloped == true },
        sort: [SortDescriptor(\.developedAt, order: .reverse)]
    )
    private var developedRolls: [FilmRoll]

    var body: some View {
        NavigationStack {
            Group {
                if developedRolls.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Aucun rouleau développé pour l’instant.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(developedRolls, id: \.id) { roll in
                            NavigationLink {
                                RollDetailView(roll: roll)
                            } label: {
                                GalleryRow(roll: roll)
                            }
                            .listRowBackground(Color(red: 0.07, green: 0.07, blue: 0.08))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("Galerie")
        }
    }
}

private struct GalleryRow: View {
    let roll: FilmRoll

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(roll.displayMonthTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let d = roll.developedAt {
                    Text(d, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(roll.shots.count) photos")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let first = roll.shots.sorted(by: { $0.index < $1.index }).first {
            DiskImageView(relativePath: first.relativeFileName)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.25))
        }
    }
}
