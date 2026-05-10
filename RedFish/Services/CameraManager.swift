import AVFoundation
import Combine
import Foundation
import UIKit

/// Session caméra hors `@MainActor` pour que les délégués `AVFoundation` puissent accéder au verrou de capture.
final class CameraManager: NSObject, ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var isConfigured = false
    @Published private(set) var lastError: String?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.redfish.camera.session")
    private let captureLock = NSLock()
    private var inFlightCapture: (@Sendable (Result<Data, Error>) -> Void)?

    private var photoOutput: AVCapturePhotoOutput?
    private var videoInput: AVCaptureDeviceInput?

    override init() {
        super.init()
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.isAuthorized = true }
            configureSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.configureSessionIfNeeded() }
                }
            }
        default:
            DispatchQueue.main.async { self.isAuthorized = false }
        }
    }

    func configureSessionIfNeeded() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty == false {
                DispatchQueue.main.async { self.isConfigured = true }
                return
            }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            defer { self.session.commitConfiguration() }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                DispatchQueue.main.async { self.lastError = "Caméra indisponible" }
                return
            }
            self.session.addInput(input)
            self.videoInput = input

            let output = AVCapturePhotoOutput()
            guard self.session.canAddOutput(output) else {
                DispatchQueue.main.async { self.lastError = "Sortie photo indisponible" }
                return
            }
            self.session.addOutput(output)
            self.photoOutput = output

            DispatchQueue.main.async {
                self.isConfigured = true
                self.lastError = nil
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning == false else { return }
            self.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, let photoOutput = self.photoOutput else {
                DispatchQueue.main.async { completion(.failure(CameraError.notConfigured)) }
                return
            }
            self.captureLock.lock()
            self.inFlightCapture = completion
            self.captureLock.unlock()
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

enum CameraError: LocalizedError {
    case notConfigured
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Session non configurée"
        case .captureFailed: return "Échec de la capture"
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        captureLock.lock()
        let handler = inFlightCapture
        inFlightCapture = nil
        captureLock.unlock()
        guard let handler else { return }

        if let error {
            DispatchQueue.main.async { handler(.failure(error)) }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { handler(.failure(CameraError.captureFailed)) }
            return
        }
        DispatchQueue.main.async { handler(.success(data)) }
    }
}
