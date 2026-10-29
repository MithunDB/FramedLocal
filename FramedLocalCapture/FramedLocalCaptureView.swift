import AVFoundation
import AVKit
import Foundation
import LockedCameraCapture
import SwiftUI
import UIKit

struct FramedLocalCaptureView: UIViewControllerRepresentable {
    let session: LockedCameraCaptureSession

    func makeUIViewController(context: Context) -> FramedLocalCaptureViewController {
        FramedLocalCaptureViewController(session: session)
    }

    func updateUIViewController(_ controller: FramedLocalCaptureViewController, context: Context) {}
}

private enum CapturePipelineError: Error, Sendable {
    case cameraUnavailable
    case cannotAddCamera
    case cannotAddPhotoOutput
    case photoFailed(String)
    case fileWriteFailed(String)

    var userMessage: String {
        switch self {
        case .cameraUnavailable: "Camera unavailable"
        case .cannotAddCamera, .cannotAddPhotoOutput: "Camera setup failed"
        case .photoFailed(let detail), .fileWriteFailed(let detail): detail
        }
    }
}

/// Owns all capture-session state on one serial queue, including photo file I/O.
private final class LockedCameraCapturePipeline: @unchecked Sendable {
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()

    private let queue = DispatchQueue(label: "local.mithundb.framed.lock-camera", qos: .userInitiated)
    private let contentDirectory: URL
    private var activeInput: AVCaptureDeviceInput?
    private var cameraPosition: AVCaptureDevice.Position = .back
    private var photoDelegate: LockedCameraPhotoDelegate?

    init(contentDirectory: URL) {
        self.contentDirectory = contentDirectory
    }

    func start(completion: @escaping @MainActor @Sendable (Result<Void, CapturePipelineError>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureSession(position: .back)
                self.session.startRunning()
                Task { @MainActor in completion(.success(())) }
            } catch let error as CapturePipelineError {
                Task { @MainActor in completion(.failure(error)) }
            } catch {
                Task { @MainActor in completion(.failure(.cameraUnavailable)) }
            }
        }
    }

    func switchCamera(completion: @escaping @MainActor @Sendable (Result<AVCaptureDevice.Position, CapturePipelineError>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            let nextPosition: AVCaptureDevice.Position = self.cameraPosition == .back ? .front : .back
            do {
                try self.configureSession(position: nextPosition)
                self.session.startRunning()
                Task { @MainActor in completion(.success(nextPosition)) }
            } catch let error as CapturePipelineError {
                Task { @MainActor in completion(.failure(error)) }
            } catch {
                Task { @MainActor in completion(.failure(.cameraUnavailable)) }
            }
        }
    }

    func updatePhotoRotation(_ angle: CGFloat, mirrored: Bool) {
        queue.async { [weak self] in
            guard let connection = self?.photoOutput.connection(with: .video),
                  connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping @MainActor @Sendable (Result<URL, CapturePipelineError>) -> Void) {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else {
                Task { @MainActor in completion(.failure(.cameraUnavailable)) }
                return
            }
            let delegate = LockedCameraPhotoDelegate(contentDirectory: self.contentDirectory) { [weak self] result in
                Task { @MainActor in completion(result) }
                self?.queue.async { [weak self] in self?.photoDelegate = nil }
            }
            self.photoDelegate = delegate
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configureSession(position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
        if let activeInput {
            session.removeInput(activeInput)
            self.activeInput = nil
        }
        if session.outputs.contains(photoOutput) { session.removeOutput(photoOutput) }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw CapturePipelineError.cameraUnavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CapturePipelineError.cannotAddCamera }
        session.addInput(input)
        activeInput = input
        guard session.canAddOutput(photoOutput) else { throw CapturePipelineError.cannotAddPhotoOutput }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        cameraPosition = position
    }
}

private final class LockedCameraPhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let contentDirectory: URL
    private let completion: @Sendable (Result<URL, CapturePipelineError>) -> Void

    init(contentDirectory: URL, completion: @escaping @Sendable (Result<URL, CapturePipelineError>) -> Void) {
        self.contentDirectory = contentDirectory
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil, let imageData = photo.fileDataRepresentation() else {
            completion(.failure(.photoFailed(error?.localizedDescription ?? "Capture failed · try again")))
            return
        }
        let fileURL = contentDirectory.appendingPathComponent("FramedLocal-\(UUID().uuidString).jpg")
        do {
            try FileManager.default.createDirectory(at: contentDirectory, withIntermediateDirectories: true)
            try imageData.write(to: fileURL, options: .atomic)
            completion(.success(fileURL))
        } catch {
            completion(.failure(.fileWriteFailed("Could not save capture · try again")))
        }
    }
}

@MainActor
final class FramedLocalCaptureViewController: UIViewController {
    private let lockedSession: LockedCameraCaptureSession
    private let capturePipeline: LockedCameraCapturePipeline
    private var cameraPosition: AVCaptureDevice.Position = .back
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var captureInteraction: AVCaptureEventInteraction?
    private let statusLabel = UILabel()
    private let switchCameraButton = UIButton(type: .system)
    private let captureButton = UIButton(type: .system)
    private let openAppButton = UIButton(type: .system)
    private var isCapturing = false

    init(session: LockedCameraCaptureSession) {
        lockedSession = session
        capturePipeline = LockedCameraCapturePipeline(contentDirectory: session.sessionContentURL)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FramedLocalCaptureViewController is created in code.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureInterface()
        configureCaptureInteraction()
        startCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        updateCaptureOrientation()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        capturePipeline.stop()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in self?.updateCaptureOrientation() })
    }

    private func configureInterface() {
        view.backgroundColor = UIColor(red: 0.025, green: 0.075, blue: 0.12, alpha: 1)
        previewLayer = AVCaptureVideoPreviewLayer(session: capturePipeline.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)

        statusLabel.text = "FRAMEDLOCAL"
        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        statusLabel.layer.cornerRadius = 15
        statusLabel.clipsToBounds = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        switchCameraButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        switchCameraButton.tintColor = .white
        switchCameraButton.backgroundColor = UIColor.black.withAlphaComponent(0.36)
        switchCameraButton.layer.cornerRadius = 23
        switchCameraButton.translatesAutoresizingMaskIntoConstraints = false
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        view.addSubview(switchCameraButton)

        var captureConfiguration = UIButton.Configuration.filled()
        captureConfiguration.baseBackgroundColor = UIColor(red: 0.20, green: 0.72, blue: 0.92, alpha: 1)
        captureConfiguration.baseForegroundColor = .white
        captureConfiguration.image = UIImage(systemName: "camera.shutter.button.fill")
        captureConfiguration.title = "Capture"
        captureButton.configuration = captureConfiguration
        captureButton.layer.cornerRadius = 29
        captureButton.clipsToBounds = true
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(captureButton)

        var openConfiguration = UIButton.Configuration.filled()
        openConfiguration.baseBackgroundColor = UIColor.black.withAlphaComponent(0.45)
        openConfiguration.baseForegroundColor = .white
        openConfiguration.title = "Open FramedLocal"
        openAppButton.configuration = openConfiguration
        openAppButton.layer.cornerRadius = 19
        openAppButton.clipsToBounds = true
        openAppButton.translatesAutoresizingMaskIntoConstraints = false
        openAppButton.addTarget(self, action: #selector(openMainApp), for: .touchUpInside)
        view.addSubview(openAppButton)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.heightAnchor.constraint(equalToConstant: 34),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 138),
            switchCameraButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            switchCameraButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            switchCameraButton.widthAnchor.constraint(equalToConstant: 46),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 46),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -25),
            captureButton.heightAnchor.constraint(equalToConstant: 58),
            captureButton.widthAnchor.constraint(equalToConstant: 158),
            openAppButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openAppButton.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -14),
            openAppButton.heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    private func configureCaptureInteraction() {
        let interaction = AVCaptureEventInteraction { [weak self] event in
            guard event.phase == .ended else { return }
            Task { @MainActor [weak self] in self?.capturePhoto() }
        }
        view.addInteraction(interaction)
        captureInteraction = interaction
        captureInteraction?.isEnabled = false
    }

    private func startCamera() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            statusLabel.text = "Unlock to enable camera access"
            captureButton.isEnabled = false
            return
        }
        capturePipeline.start { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.captureInteraction?.isEnabled = true
                self.statusLabel.text = "READY"
                self.updateCaptureOrientation()
            case .failure(let error):
                self.statusLabel.text = error.userMessage
                self.captureButton.isEnabled = false
            }
        }
    }

    private func updateCaptureOrientation() {
        guard let orientation = view.window?.windowScene?.interfaceOrientation else { return }
        let angle = rotationAngle(for: orientation)
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = cameraPosition == .front
            }
        }
        capturePipeline.updatePhotoRotation(angle, mirrored: cameraPosition == .front)
    }

    private func rotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .landscapeLeft: 0
        case .portraitUpsideDown: 270
        case .landscapeRight: 180
        default: 90
        }
    }

    @objc private func switchCamera() {
        captureInteraction?.isEnabled = false
        capturePipeline.switchCamera { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let position):
                self.cameraPosition = position
                self.updateCaptureOrientation()
                self.captureInteraction?.isEnabled = true
                self.statusLabel.text = "READY"
            case .failure(let error):
                self.statusLabel.text = error.userMessage
                self.captureInteraction?.isEnabled = true
            }
        }
    }

    @objc private func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        captureInteraction?.isEnabled = false
        statusLabel.text = "CAPTURING"
        capturePipeline.capturePhoto { [weak self] result in
            guard let self else { return }
            self.isCapturing = false
            self.captureInteraction?.isEnabled = true
            switch result {
            case .success:
                self.statusLabel.text = "Captured · open FramedLocal to edit"
            case .failure(let error):
                self.statusLabel.text = error.userMessage
            }
        }
    }

    @objc private func openMainApp() {
        Task {
            do {
                let activity = NSUserActivity(activityType: NSUserActivityTypeLockedCameraCapture)
                try await lockedSession.openApplication(for: activity)
            } catch {
                statusLabel.text = "Unlock to continue in FramedLocal"
            }
        }
    }
}
