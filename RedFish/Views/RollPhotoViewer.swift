import SwiftUI
import UIKit

struct RollPhotoViewer: View {
    let images: [UIImage]
    let monthKey: String
    let initialIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int

    init(images: [UIImage], monthKey: String, initialIndex: Int) {
        self.images = images
        self.monthKey = monthKey
        self.initialIndex = initialIndex
        _selection = State(initialValue: max(0, min(initialIndex, max(0, images.count - 1))))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if images.isEmpty {
                    Text("Aucune image")
                        .foregroundStyle(.white)
                } else {
                    TabView(selection: $selection) {
                        ForEach(Array(images.enumerated()), id: \.offset) { idx, uiImage in
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .tag(idx)
                                .padding()
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .navigationTitle(monthKey)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                HStack {
                    Button("Fermer") { dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    if images.isEmpty == false {
                        Text("\(selection + 1)/\(images.count)")
                            .font(.headline.monospacedDigit())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.45), in: Capsule())
            }
        }
    }
}
