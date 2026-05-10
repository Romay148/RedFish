import SwiftData
import SwiftUI

struct CameraCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var camera = CameraManager()
    @State private var rollService: RollService?
    @State private var showDevelopSheet = false
    @State private var isCapturing = false
    @State private var banner: String?

    var body: some View {
        NavigationStack {
            ZStack {
                if camera.isAuthorized && camera.isConfigured {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                        Text(camera.isAuthorized ? "Préparation de la caméra…" : "Autorisez l’accès à la caméra dans Réglages.")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .foregroundStyle(.white)
                }

                VStack {
                    Spacer()
                    controlBar
                }
                .padding(.bottom, 28)
            }
            .navigationTitle("Appareil du mois")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let roll = rollService?.currentRoll() {
                        Text("\(roll.shotCount)/\(RollConstants.maxShotsPerRoll)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if let banner {
                    Text(banner)
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showDevelopSheet) {
                DevelopRollSheet(monthKey: RollService.monthKey()) {
                    rollService?.developCurrentRoll()
                }
            }
            .onAppear {
                camera.checkAuthorization()
                if camera.isAuthorized {
                    camera.configureSessionIfNeeded()
                }
                let svc = RollService(modelContext: modelContext)
                svc.ensureCurrentRoll()
                rollService = svc
                camera.startSession()
            }
            .onChange(of: camera.isAuthorized) { _, granted in
                if granted {
                    camera.configureSessionIfNeeded()
                    camera.startSession()
                }
            }
            .onChange(of: camera.isConfigured) { _, ready in
                if ready { camera.startSession() }
            }
            .onDisappear {
                camera.stopSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                rollService?.ensureCurrentRoll()
            }
        }
    }

    @ViewBuilder
    private var controlBar: some View {
        let canShoot = rollService?.canCaptureToday() ?? false
        let awaiting = rollService?.currentRoll()?.displayState == .awaitingDevelopment

        HStack(spacing: 24) {
            if awaiting {
                Button {
                    showDevelopSheet = true
                } label: {
                    Label("Développer", systemImage: "film.stack")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
            } else {
                Button {
                    capture()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(canShoot && !isCapturing ? Color.white : Color.gray.opacity(0.5))
                            .frame(width: 58, height: 58)
                    }
                }
                .disabled(!canShoot || isCapturing)
            }
        }
        .padding()
        .background(.black.opacity(0.35), in: Capsule())
    }

    private func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        banner = nil
        camera.capturePhoto { result in
            isCapturing = false
            switch result {
            case .success(let data):
                guard let svc = rollService else { return }
                switch svc.capturePhoto(jpegData: data) {
                case .success(let remaining):
                    banner = remaining == 0 ? "Pellicule pleine — développez pour voir vos photos." : "Photo enregistrée. Reste \(remaining)."
                    if remaining == 0 {
                        showDevelopSheet = true
                    }
                case .rollFull:
                    banner = "Pellicule pleine."
                case .notInShootingState:
                    banner = "Impossible d’ajouter une photo."
                case .saveFailed:
                    banner = "Échec de l’enregistrement."
                }
            case .failure:
                banner = "Capture impossible."
            }
        }
    }
}
