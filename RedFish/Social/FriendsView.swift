import SwiftUI

@MainActor
struct FriendsView: View {
    @EnvironmentObject private var session: SocialSessionStore
    @State private var username = ""
    @State private var pending: [Friendship] = []
    @State private var isSending = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Ajouter un ami") {
                    HStack {
                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Envoyer") { sendRequest() }
                            .disabled(
                                username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || isSending
                                    || session.accessToken == nil
                            )
                    }
                }

                Section("Demandes reçues") {
                    if pending.isEmpty {
                        Text("Aucune demande en attente")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pending) { request in
                            HStack {
                                Text(request.fromUsername ?? request.fromUid)
                                    .font(.caption)
                                Spacer()
                                Button("Accepter") {
                                    accept(request)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Amis")
            .toolbar {
                if session.accessToken != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Déconnexion") { session.logout() }
                    }
                }
            }
            .task { await refreshPending() }
            .refreshable { await refreshPending() }
            .alert("Info", isPresented: .constant(message != nil), actions: {
                Button("OK") { message = nil }
            }, message: {
                Text(message ?? "")
            })
        }
    }

    private func sendRequest() {
        guard let token = session.accessToken else { return }
        isSending = true
        Task {
            do {
                try await FriendService.shared.sendFriendRequest(token: token, to: username)
                username = ""
                message = "Demande envoyée."
            } catch {
                message = error.localizedDescription
            }
            isSending = false
            await refreshPending()
        }
    }

    private func accept(_ request: Friendship) {
        Task {
            do {
                guard let token = session.accessToken else { return }
                try await FriendService.shared.acceptRequest(token: token, requestID: request.id)
                message = "Demande acceptée."
            } catch {
                message = error.localizedDescription
            }
            await refreshPending()
        }
    }

    private func refreshPending() async {
        guard let token = session.accessToken else { return }
        do {
            pending = try await FriendService.shared.pendingRequests(token: token)
        } catch {
            message = error.localizedDescription
        }
    }
}
