import SwiftUI
import SwiftData

struct CameraCaptureView: View {
    @Bindable var roll: FilmRoll
    @Environment(\.modelContext) private var modelContext
    @StateObject private var camera = CameraManager()
    @State private var isCapturing = false
    @State private var errorMessage: String?
    @State private var showDevelopSheet = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.authorizationDenied {
                Text("Autorisez l'accès à la caméra dans Réglages.")
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding()
            } else if let msg = camera.setupFailedMessage {
                Text(msg)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding()
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    Text("\(roll.shots.count)/\(FilmRoll.capacity)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 1)
                        .padding(.bottom, 24)

                    Button {
                        takePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 4)
                                .frame(width: 76, height: 76)
                            Circle()
                                .fill(canShoot ? Color.white : Color.white.opacity(0.35))
                                .frame(width: 62, height: 62)
                        }
                    }
                    .disabled(!canShoot || isCapturing)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            camera.checkAuthorizationAndConfigure()
            camera.startSessionIfNeeded()
        }
        .onDisappear {
            camera.stopSession()
        }
        .alert("Erreur", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showDevelopSheet) {
            DevelopRollSheet(roll: roll)
        }
        .safeAreaInset(edge: .top) {
            if roll.isFull && !roll.isDeveloped {
                Button {
                    showDevelopSheet = true
                } label: {
                    Text("Développer le rouleau")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
    }

    private var canShoot: Bool {
        !roll.isDeveloped && roll.shots.count < FilmRoll.capacity && !roll.isFull
    }

    private func takePhoto() {
        guard canShoot, !isCapturing else { return }
        isCapturing = true
        let nextIndex = roll.shots.count + 1
        camera.capturePhoto { result in
            defer { isCapturing = false }
            switch result {
            case .failure(let err):
                errorMessage = err.localizedDescription
            case .success(let image):
                do {
                    let rel = try PhotoStorage.saveJPEG(image, rollId: roll.id, index: nextIndex)
                    let shot = Shot(index: nextIndex, relativeFileName: rel, filmRoll: roll)
                    modelContext.insert(shot)
                    try modelContext.save()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
