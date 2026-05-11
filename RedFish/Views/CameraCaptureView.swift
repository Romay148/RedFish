import SwiftData
import SwiftUI

@MainActor
struct CameraCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var camera = CameraManager()
    @State private var showDevelopSheet = false
    @State private var selectedCameraID: String?
    @State private var isCapturing = false
    @State private var banner: String?

    private var rollService: RollService { RollService(modelContext: modelContext) }

    var body: some View {
        NavigationStack {
            if selectedCameraID == nil {
                cameraSelectionView
                    .navigationTitle("Choix de l'appareil")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
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
                .toolbar(content: {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button {
                            selectedCameraID = nil
                            camera.stopSession()
                        } label: {
                            Label("Appareils", systemImage: "chevron.left")
                        }
                        .tint(.white)
                    }
                    ToolbarItemGroup(placement: .principal) {
                        if let roll = rollService.currentRoll() {
                            Text("\(roll.shotCount)/\(RollConstants.maxShotsPerRoll)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.white)
                        }
                    }
                })
                .safeAreaInset(edge: .top) {
                    if let banner {
                        Text(banner)
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                    }
                }
            }
            .sheet(isPresented: $showDevelopSheet) {
                DevelopRollSheet(monthKey: RollService.monthKey()) {
                    rollService.developCurrentRoll()
                }
            }
            .onAppear {
                rollService.ensureCurrentRoll()
            }
            .onChange(of: camera.isAuthorized) { _, granted in
                if granted && selectedCameraID != nil {
                    camera.configureSessionIfNeeded()
                    camera.startSession()
                }
            }
            .onChange(of: camera.isConfigured) { _, ready in
                if ready && selectedCameraID != nil { camera.startSession() }
            }
            .onDisappear {
                camera.stopSession()
            }
        }
    }

    private var cameraSelectionView: some View {
        let monthKey = RollService.monthKey()
        let remaining = max(0, RollConstants.maxShotsPerRoll - (rollService.currentRoll()?.shotCount ?? 0))

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Vos appareils")
                    .font(.title2.bold())

                Button {
                    selectedCameraID = monthKey
                    banner = nil
                    camera.checkAuthorization()
                    if camera.isAuthorized {
                        camera.configureSessionIfNeeded()
                    }
                    camera.startSession()
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Image("appareilphotodetourne")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300, maxHeight: 220)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text(cameraName(for: monthKey))
                            .font(.headline)

                        Text("\(remaining) photos restantes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }

    private func cameraName(for monthKey: String) -> String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]) else { return "Appareil du mois" }
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "fr_FR")
        guard let date = cal.date(from: DateComponents(year: y, month: m)) else { return "Appareil du mois" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "LLLL"
        return "Appareil de \(fmt.string(from: date))"
    }

    @ViewBuilder
    private var controlBar: some View {
        let canShoot = rollService.canCaptureToday()
        let awaiting = rollService.currentRoll()?.displayState == .awaitingDevelopment

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
            Task { @MainActor in
                isCapturing = false
                switch result {
                case .success(let data):
                    let svc = RollService(modelContext: modelContext)
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
}
