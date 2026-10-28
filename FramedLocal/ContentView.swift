import AVFoundation
import Observation
import SwiftUI
import UIKit
import PhotosUI
import CoreVideo
import CoreMotion

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = CameraController()
    @State private var selectedPreset: FilmPreset = .natural
    @State private var selectedFrame: FrameLayout = .whiteBorder
    @State private var includesDateStamp = true
    @State private var previewImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importTask: Task<Void, Never>?
    @State private var importTaskID = UUID()
    @State private var isRendering = false
    @State private var renderTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.authorization == .authorized && camera.importedImage == nil {
                CameraPreview(session: camera.session, rotationAngle: camera.previewRotationAngle)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { point in
                        camera.selectSubject(at: point, in: camera.previewSize)
                    }
            } else if camera.importedImage != nil {
                Color.black.ignoresSafeArea()
            } else {
                permissionContent
            }

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 28)
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
            }

            if camera.authorization == .authorized && camera.latestCapture == nil && camera.importedImage == nil {
                VStack {
                    Spacer()
                    Text(camera.guidanceText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(.bottom, 165)
                }
                .allowsHitTesting(false)
            }

            VStack {
                HStack {
                    Text("FRAMED")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(3)
                    Spacer()
                    Button {
                        camera.toggleCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 20, weight: .regular))
                            .frame(width: 44, height: 44)
                    }
            .disabled(camera.authorization != .authorized || !camera.isSessionRunning || camera.isCapturing || camera.isSaving || isImporting)

                    PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 19, weight: .regular))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Choose a photo to edit")
                    .disabled(isImporting || camera.isSaving)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.top, 12)

                Spacer()

            if !isImporting || camera.latestCapture != nil || camera.importedImage != nil {
                    VStack(spacing: 10) {
                        presetPicker
                        framePicker
                    }
                    .padding(.bottom, 20)
                }

                if let captureMessage = camera.captureMessage {
                    Text(captureMessage)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                    if camera.cameraStartupFailed {
                        Button("Retry camera") {
                            Task { await camera.startIfAuthorized() }
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)
                    }
                }
                if isImporting {
                    Button("Cancel import", action: cancelImport)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)
                }

                if camera.latestCapture != nil {
                    HStack(spacing: 18) {
                        Button("Retake") {
                            camera.discardCapture()
                            previewImage = nil
                        }
                        .foregroundStyle(.white)
                        Button("Save to Photos") {
                            camera.saveLatestCapture()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                        .disabled(camera.isSaving || isRendering || camera.renderedCapture == nil)
                    }
                    .padding(.bottom, 12)
                } else if camera.importedImage != nil {
                    HStack(spacing: 18) {
                        Button("Cancel") {
                            cancelImport()
                        }
                        .foregroundStyle(.white)
                        Button("Export New Copy") {
                            camera.saveLatestCapture()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                        .disabled(camera.isSaving || isRendering || camera.renderedCapture == nil)
                    }
                    .padding(.bottom, 12)
                }

                HStack {
                    Spacer()
                    Button {
                        if camera.latestCapture == nil && camera.importedImage == nil {
                            camera.capture()
                        }
                    } label: {
                        Circle()
                            .stroke(.white.opacity(0.85), lineWidth: 3)
                            .frame(width: 76, height: 76)
                            .overlay {
                                Circle().fill(.white).padding(7)
                            }
                    }
                    .disabled(camera.authorization != .authorized || !camera.isSessionRunning || camera.isCapturing || camera.isSaving || camera.latestCapture != nil || camera.importedImage != nil)
                    Spacer()
                }
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await camera.requestPermissionAndStart()
            await camera.startIfAuthorized()
        }
        .onChange(of: camera.latestCapture) { _, data in
            guard let data else {
                renderTask?.cancel()
                isRendering = false
                previewImage = nil
                return
            }
            renderTask?.cancel()
            renderTask = renderPreview(data)
        }
        .onChange(of: camera.importedImage) { _, data in
            guard let data else { return }
            renderTask?.cancel()
            renderTask = renderPreview(data)
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            importPhoto(item)
        }
        .onChange(of: selectedPreset) { _, _ in
            if let data = camera.latestCapture ?? camera.importedImage { renderTask?.cancel(); renderTask = renderPreview(data) }
        }
        .onChange(of: selectedFrame) { _, _ in
            if let data = camera.latestCapture ?? camera.importedImage { renderTask?.cancel(); renderTask = renderPreview(data) }
        }
        .onChange(of: includesDateStamp) { _, _ in
            if let data = camera.latestCapture ?? camera.importedImage { renderTask?.cancel(); renderTask = renderPreview(data) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await camera.requestPermissionAndStart()
                    await camera.startIfAuthorized()
                }
            } else if phase == .background {
                camera.stop()
            }
        }
        .onDisappear {
            importTask?.cancel()
            renderTask?.cancel()
            isRendering = false
            camera.stop()
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        importTask?.cancel()
        let taskID = UUID()
        importTaskID = taskID
        isImporting = true
        renderTask?.cancel()
        isRendering = false
        camera.discardCapture()
        previewImage = nil
        camera.captureMessage = "Loading selected photo…"
        importTask = Task {
            do {
                let data = try await PhotoImportService.loadJPEG(from: item)
                try Task.checkCancellation()
                await MainActor.run {
                    guard importTaskID == taskID else { return }
                    camera.importedImage = data
                    camera.captureMessage = "Original kept unchanged · edit a new copy"
                    isImporting = false
                    importTask = nil
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    guard importTaskID == taskID else { return }
                    camera.captureMessage = error.localizedDescription
                    isImporting = false
                    importTask = nil
                }
            }
        }
    }

    private func cancelImport() {
        importTask?.cancel()
        importTaskID = UUID()
        importTask = nil
        isImporting = false
        renderTask?.cancel()
        isRendering = false
        camera.discardCapture()
        previewImage = nil
    }

    @ViewBuilder
    private var permissionContent: some View {
        VStack(spacing: 14) {
            Image(systemName: camera.authorization == .denied ? "camera.fill" : "camera")
                .font(.system(size: 34, weight: .light))
            Text(camera.authorization == .denied ? "Camera access is off" : "Allow camera access")
                .font(.title3.weight(.medium))
            Text(camera.authorization == .denied
                 ? "Enable camera access in Settings to take photos."
                 : "Framed uses the camera to preview and capture photos on this device.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            if camera.authorization == .denied,
               let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: settingsURL)
                    .padding(.top, 4)
            }
        }
        .foregroundStyle(.white)
        .padding(32)
    }

    private var presetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilmPreset.allCases) { preset in
                    Button(preset.rawValue) { selectedPreset = preset }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(selectedPreset == preset ? .black : .white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(selectedPreset == preset ? Color.white : Color.white.opacity(0.16), in: Capsule())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var framePicker: some View {
        HStack(spacing: 16) {
            ForEach(FrameLayout.allCases) { frame in
                Button(frame.rawValue) { selectedFrame = frame }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(selectedFrame == frame ? .white : .white.opacity(0.62))
            }
            Toggle("Date", isOn: $includesDateStamp)
                .labelsHidden()
                .tint(.white)
                .scaleEffect(0.78)
        }
    }

    private func renderPreview(_ data: Data) -> Task<Void, Never> {
        let preset = selectedPreset
        let frame = selectedFrame
        let dateStamp = includesDateStamp
        let sourceID = camera.latestCapture.map { _ in "capture" } ?? "import"
        let taskID = UUID()
        camera.renderTaskID = taskID
        camera.renderError = nil
        isRendering = true
        return Task {
            do {
                let graded = try await FilmRenderer.shared.render(data, preset: preset)
                try Task.checkCancellation()
                let framed = try await FrameRenderer.shared.render(graded, layout: frame, dateStamp: dateStamp)
                try Task.checkCancellation()
                guard let image = UIImage(data: framed) else {
                    await MainActor.run {
                        guard camera.renderTaskID == taskID else { return }
                        camera.renderError = "The rendered preview could not be displayed."
                        camera.captureMessage = camera.renderError
                        isRendering = false
                    }
                    return
                }
                await MainActor.run {
                    guard camera.renderTaskID == taskID,
                          (camera.latestCapture != nil && sourceID == "capture") || (camera.importedImage != nil && sourceID == "import") else { return }
                    previewImage = image
                    camera.renderedCapture = framed
                    isRendering = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    guard camera.renderTaskID == taskID else { return }
                    camera.renderError = error.localizedDescription
                    camera.captureMessage = error.localizedDescription
                    isRendering = false
                }
            }
        }
    }
}

final class CameraController: NSObject, @unchecked Sendable {
    enum Authorization {
        case unknown, authorized, denied
    }

    nonisolated(unsafe) let session = AVCaptureSession()
    private let analysisOutput = AVCaptureVideoDataOutput()
    private let analysisDelegate = VideoAnalysisDelegate()
    private let compositionAnalyzer = CompositionAnalyzer()
    private let analysisQueue = DispatchQueue(label: "local.mithundb.framed.analysis-frames", qos: .userInitiated)
    private let sessionQueue = DispatchQueue(label: "local.mithundb.framed.camera-session")
    private var photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptures: [Int64: PhotoCaptureDelegate] = [:]
    private var activeInput: AVCaptureDeviceInput?
    private var isConfigured = false
    @MainActor private var isConfiguring = false
    private var useFrontCamera = false
    private var sessionIsRunning = false
    private let motionManager = CMMotionManager()
    private var deviceOrientation: UIDeviceOrientation = .portrait
    private let motionQueue = OperationQueue()
    @MainActor private var orientationObserver: NSObjectProtocol?

    @MainActor
    var authorization: Authorization = .unknown
    @MainActor
    var isCapturing = false
    @MainActor
    var captureMessage: String?
    @MainActor
    var latestCapture: Data?
    @MainActor
    var isSaving = false
    @MainActor
    var renderedCapture: Data?
    @MainActor
    var renderError: String?
    @MainActor
    var renderTaskID = UUID()
    @MainActor
    var importedImage: Data?
    @MainActor
    var guidanceText = "Searching for a subject"
    @MainActor
    var previewSize = CGSize(width: 640, height: 480)
    @MainActor
    var horizonTilt = 0.0
    @MainActor
    var previewRotationAngle: CGFloat = 90
    @MainActor
    var cameraStartupFailed = false
    @MainActor
    var isSessionRunning = false
    @MainActor
    private var lastGuidanceHapticMessage: String?

    @MainActor
    func requestPermissionAndStart() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let granted: Bool
        if status == .authorized {
            granted = true
        } else if status == .notDetermined {
            granted = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            granted = false
        }

        authorization = granted ? .authorized : .denied
    }

    @MainActor
    func startIfAuthorized() async {
        guard authorization == .authorized, !sessionIsRunning, !isConfiguring else { return }
        sessionIsRunning = true
        isConfiguring = true
        isSessionRunning = false

        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureSession(position: .back)
                self.session.startRunning()
                Task { @MainActor in
                    self.isConfiguring = false
                    self.cameraStartupFailed = false
                    self.isSessionRunning = true
                    self.startMotionUpdates()
                }
            } catch {
                Task { @MainActor in
                    self.sessionIsRunning = false
                    self.isConfiguring = false
                    self.isSessionRunning = false
                    self.cameraStartupFailed = true
                    self.captureMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    func stop() {
        motionManager.stopDeviceMotionUpdates()
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
            self.orientationObserver = nil
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        sessionIsRunning = false
        isSessionRunning = false
        isConfiguring = false
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    @MainActor
    func toggleCamera() {
        useFrontCamera.toggle()
        let position: AVCaptureDevice.Position = useFrontCamera ? .front : .back
        guard sessionIsRunning else {
            useFrontCamera.toggle()
            captureMessage = "Start the camera before switching lenses."
            return
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureSession(position: position)
            } catch {
                Task { @MainActor in self.captureMessage = error.localizedDescription }
            }
        }
    }

    @MainActor
    func capture() {
        guard !isCapturing, sessionIsRunning else {
            captureMessage = "The camera is not ready yet. Try again in a moment."
            return
        }
        isCapturing = true
        captureMessage = nil
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let delegate = PhotoCaptureDelegate()
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            settings.photoQualityPrioritization = .quality
            let captureID = settings.uniqueID
            self.inProgressPhotoCaptures[captureID] = delegate
            delegate.didCapture = { [weak self] result in
                self?.sessionQueue.async { [weak self] in
                    self?.inProgressPhotoCaptures.removeValue(forKey: captureID)
                }
                Task { @MainActor in
                    guard let self else { return }
                    self.isCapturing = false
                    switch result {
                    case .success(let data):
                        self.latestCapture = data
                        self.captureMessage = "Photo captured — tap Save to Photos"
                    case .failure(let error):
                        self.captureMessage = error.localizedDescription
                    }
                }
            }
            if let connection = self.photoOutput.connection(with: .video) {
                let angle = self.rotationAngle(for: self.deviceOrientation)
                if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            }
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    @MainActor
    func saveLatestCapture() {
        guard latestCapture != nil || importedImage != nil, !isSaving else { return }
        guard let bytes = renderedCapture else {
            captureMessage = renderError ?? "Wait for the preview to finish rendering."
            return
        }
        isSaving = true
        captureMessage = "Saving to Photos…"
        Task {
            do {
                let savedInAlbum = try await PhotoLibraryService.shared.saveJPEG(bytes)
                captureMessage = savedInAlbum ? "Saved to Photos · Framed album" : "Saved to Photos"
            } catch {
                captureMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    @MainActor
    func discardCapture() {
        renderTaskID = UUID()
        latestCapture = nil
        importedImage = nil
        renderedCapture = nil
        renderError = nil
        captureMessage = nil
    }

    @MainActor
    func selectSubject(at point: CGPoint, in viewSize: CGSize) {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        let normalized = CGPoint(x: point.x / viewSize.width, y: 1 - point.y / viewSize.height)
        captureMessage = "Finding selected subject…"
        analysisDelegate.selectSubject(normalizedPoint: normalized, orientation: visionOrientation, on: analysisQueue)
    }

    private var visionOrientation: CGImagePropertyOrientation {
        switch deviceOrientation {
        case .landscapeLeft: .up
        case .landscapeRight: .down
        case .portraitUpsideDown: .left
        default: .right
        }
    }

    private func rotationAngle(for orientation: UIDeviceOrientation) -> CGFloat {
        switch orientation {
        case .landscapeLeft: 180
        case .landscapeRight: 0
        case .portraitUpsideDown: 270
        default: 90
        }
    }

    @MainActor
    private func startMotionUpdates() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        deviceOrientation = UIDevice.current.orientation
        updateConnectionsOrientation()
        if orientationObserver == nil {
            orientationObserver = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification,
                                                                          object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let current = UIDevice.current.orientation
                guard current.isPortrait || current.isLandscape else { return }
                self.deviceOrientation = current
                self.updateConnectionsOrientation()
            }
            }
        }
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, _ in
            guard let motion else { return }
            let tilt = atan2(motion.gravity.x, motion.gravity.y)
            Task { @MainActor in self?.horizonTilt = tilt }
        }
    }

    @MainActor
    private func updateConnectionsOrientation() {
        let angle = rotationAngle(for: deviceOrientation)
        previewRotationAngle = angle
        sessionQueue.async { [weak self] in
            guard let self else { return }
            [self.photoOutput.connection(with: .video), self.analysisOutput.connection(with: .video)].forEach { connection in
                if let connection, connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }
        }
    }

    nonisolated private func configureSession(position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        if let activeInput {
            session.removeInput(activeInput)
            self.activeInput = nil
        }
        if isConfigured {
            session.removeOutput(photoOutput)
            session.removeOutput(analysisOutput)
        }

        let deviceType: AVCaptureDevice.DeviceType = position == .back ? .builtInWideAngleCamera : .builtInTrueDepthCamera
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [deviceType, .builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        guard let device = discovery.devices.first else {
            throw CameraError.cameraUnavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAddCamera }
        session.addInput(input)
        activeInput = input

        guard session.canAddOutput(photoOutput) else { throw CameraError.cannotAddPhotoOutput }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        analysisOutput.alwaysDiscardsLateVideoFrames = true
        analysisOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        analysisDelegate.analyzer = compositionAnalyzer
        analysisOutput.setSampleBufferDelegate(analysisDelegate, queue: analysisQueue)
        if let connection = analysisOutput.connection(with: .video) {
            let angle = rotationAngle(for: deviceOrientation)
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        }
        guard session.canAddOutput(analysisOutput) else { throw CameraError.cannotAddAnalysisOutput }
        session.addOutput(analysisOutput)
        analysisDelegate.onResult = { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                let message = abs(self.horizonTilt) > 0.10 && result.guidance == "Suggested framing" ? "Level the phone" : result.guidance
                self.guidanceText = message
                if message == "Hold steady" && self.lastGuidanceHapticMessage != message {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
                self.lastGuidanceHapticMessage = message
            }
        }
        isConfigured = true
    }

    private enum CameraError: LocalizedError {
        case cameraUnavailable, cannotAddCamera, cannotAddPhotoOutput, cannotAddAnalysisOutput
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: "No suitable camera is available."
            case .cannotAddCamera: "The camera could not be added to the capture session."
            case .cannotAddPhotoOutput: "Photo capture is unavailable."
            case .cannotAddAnalysisOutput: "Camera analysis is unavailable."
            }
        }
    }
}

private final class VideoAnalysisDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let stateLock = NSLock()
    private var analysisPending = false
    weak var analyzer: CompositionAnalyzer?
    var onResult: ((AnalysisResult) -> Void)?
    private var mostRecentPixelBuffer: CVPixelBuffer?

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let source = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        stateLock.lock()
        guard !analysisPending else {
            stateLock.unlock()
            return
        }
        analysisPending = true
        stateLock.unlock()
        mostRecentPixelBuffer = source
        analyzer?.analyze(source) { [weak self] result in
            self?.onResult?(result)
            guard let self else { return }
            self.stateLock.lock()
            self.analysisPending = false
            self.stateLock.unlock()
        }
    }

    func selectSubject(normalizedPoint: CGPoint, orientation: CGImagePropertyOrientation = .right,
                       on queue: DispatchQueue) {
        queue.async { [weak self] in
            guard let self, let mostRecentPixelBuffer = self.mostRecentPixelBuffer else { return }
            self.analyzer?.selectSubject(at: normalizedPoint, in: mostRecentPixelBuffer, orientation: orientation)
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    var didCapture: ((Result<Data, Error>) -> Void)?

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            didCapture?(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            didCapture?(.success(data))
        } else {
            didCapture?(.failure(CaptureError.missingData))
        }
    }

    private enum CaptureError: LocalizedError {
        case missingData
        var errorDescription: String? { "The captured photo could not be read." }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let rotationAngle: CGFloat

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection,
           connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        if let connection = uiView.previewLayer.connection,
           connection.isVideoRotationAngleSupported(rotationAngle),
           connection.videoRotationAngle != rotationAngle {
            connection.videoRotationAngle = rotationAngle
        }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
