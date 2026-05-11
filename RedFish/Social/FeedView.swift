import SwiftData
import SwiftUI
import UIKit

@MainActor
struct FeedView: View {
    @EnvironmentObject private var session: SocialSessionStore
    @State private var shareImages: [UIImage] = []
    @State private var showShare = false
    @State private var remotePosts: [RemotePost] = []
    @State private var imageCache: [String: [UIImage]] = [:]
    @State private var loading = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    ProgressView("Chargement du fil…")
                } else if remotePosts.isEmpty {
                    ContentUnavailableView(
                        "Fil vide",
                        systemImage: "person.2",
                        description: Text("Ajoutez un ami puis partagez une pellicule pour voir le fil.")
                    )
                } else {
                    ForEach(remotePosts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(post.ownerUsername)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(post.caption)
                                    .font(.headline)
                                }
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
                                    ForEach(Array((imageCache[post.id] ?? []).enumerated()), id: \.offset) { _, ui in
                                            Image(uiImage: ui)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Fil")
            .task {
                await reloadFeed()
            }
            .refreshable {
                await reloadFeed()
            }
            .sheet(isPresented: $showShare) {
                ActivityView(activityItems: shareImages)
            }
            .alert("Fil", isPresented: .constant(message != nil), actions: {
                Button("OK") { message = nil }
            }, message: {
                Text(message ?? "")
            })
        }
    }

    private func sharePost(_ post: RemotePost) {
        let imgs = imageCache[post.id] ?? []
        guard !imgs.isEmpty else { return }
        shareImages = imgs
        showShare = true
    }

    private func reloadFeed() async {
        guard let myUID = session.uid else { return }
        loading = true
        do {
            let posts = try await FeedService.shared.fetchFriendsPosts(myUID: myUID)
            remotePosts = posts
            var cache: [String: [UIImage]] = [:]
            for post in posts {
                cache[post.id] = await FeedService.shared.loadImages(for: post)
            }
            imageCache = cache
            message = nil
        } catch {
            message = error.localizedDescription
        }
        loading = false
    }
}

/// UIKit bridge pour `UIActivityViewController`.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
