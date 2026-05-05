import SwiftUI
import UIKit

struct RollDetailView: View {
    let roll: FilmRoll

    private var sortedShots: [Shot] {
        roll.shots.sorted { $0.index < $1.index }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(sortedShots, id: \.persistentModelID) { shot in
                    DiskImageView(relativePath: shot.relativeFileName)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                }
            }
        }
        .navigationTitle(roll.displayMonthTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black)
    }
}

struct DiskImageView: View {
    let relativePath: String

    var body: some View {
        GeometryReader { geo in
            let url = PhotoStorage.absoluteURL(forRelativePath: relativePath)
            if let ui = UIImage(contentsOfFile: url.path) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
