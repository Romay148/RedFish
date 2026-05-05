import AVFoundation
import SwiftUI
import UIKit

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "com.redfish.camera.session")

    @Published var authorizationDenied = false
    @Published var setupFailedMessage: String?

    private var photoContinuation: ((Result<UIImage, Error>) -> Void)?

    func checkAuthorizationAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.authorizationDenied = true
                    }
                }
            }
        default:
            authorizationDenied = true
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()
            session.sessionPreset = .photo

            do {
                if let existing = videoDeviceInput {
                    session.removeInput(existing)
                }
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    DispatchQueue.main.async { self.setupFailedMessage = "Caméra indisponible." }
                    session.commitConfiguration()
                    return
                }
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                    videoDeviceInput = input
                }
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                    photoOutput.maxPhotoQualityPrioritization = .quality
                }
            } catch {
                DispatchQueue.main.async { self.setupFailedMessage = error.localizedDescription }
                session.commitConfiguration()
                return
            }

            session.commitConfiguration()
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard session.isRunning else {
                DispatchQueue.main.async { completion(.failure(CameraError.sessionNotRunning)) }
                return
            }
            let settings: AVCapturePhotoSettings
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }
            self.photoContinuation = completion
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func startSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, !session.isRunning else { return }
            session.startRunning()
        }
    }

    enum CameraError: LocalizedError {
        case sessionNotRunning
        case noImageData

        var errorDescription: String? {
            switch self {
            case .sessionNotRunning: return "La caméra n'est pas prête."
            case .noImageData: return "Impossible de lire la photo."
            }
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            DispatchQueue.main.async { self.photoContinuation?(.failure(error)); self.photoContinuation = nil }
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.photoContinuation?(.failure(CameraError.noImageData))
                self.photoContinuation = nil
            }
            return
        }
        let fixed = image.fixedOrientation()
        DispatchQueue.main.async {
            self.photoContinuation?(.success(fixed))
            self.photoContinuation = nil
        }
    }
}

private extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}
