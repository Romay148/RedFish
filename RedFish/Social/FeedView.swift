import SwiftData
import SwiftUI
import UIKit

struct FeedView: View {
    @Query(sort: \FilmRoll.monthKey, order: .reverse) private var rolls: [FilmRoll]
    @State private var shareImages: [UIImage] = []
    @State private var showShare = false

    private var posts: [Post] {
        rolls.compactMap { Post.fromDevelopedRoll($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if posts.isEmpty {
                    ContentUnavailableView(
                        "Fil vide",
                        systemImage: "person.2",
                        description: Text("Développez une pellicule pour voir vos souvenirs ici.")
                    )
                } else {
                    ForEach(posts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(post.caption)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    sharePost(post)
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .buttonStyle(.borderless)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(post.imageRelativeNames, id: \.self) { name in
                                        if let ui = PhotoStorage.shared.loadImage(monthKey: post.monthKey, relativeFileName: name) {
                                            Image(uiImage: ui)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Fil")
            .sheet(isPresented: $showShare) {
                ActivityView(activityItems: shareImages)
            }
        }
    }

    private func sharePost(_ post: Post) {
        let imgs = post.imageRelativeNames.compactMap {
            PhotoStorage.shared.loadImage(monthKey: post.monthKey, relativeFileName: $0)
        }
        guard !imgs.isEmpty else { return }
        shareImages = imgs
        showShare = true
    }
}

/// UIKit bridge pour `UIActivityViewController`.
@MainActor
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
