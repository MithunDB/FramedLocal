import AVFoundation
import Combine
import SwiftUI
import UIKit
import PhotosUI
import CoreVideo
import CoreMotion
import ImageIO

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraController()
    @State private var selectedPreset: FilmPreset = .natural
    @State private var selectedCropAspect: CropAspect = .original
    @State private var cropPosition = CropPosition.center
    @State private var selectedFrame: FrameLayout = .whiteBorder
    @State private var includesDateStamp = true
    @State private var editorStampDate = Date()
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
                CameraPreview(session: camera.session, rotationAngle: camera.previewRotationAngle,
                              isMirrored: camera.isFrontCamera) { capturePoint in
                    camera.selectSubject(atCaptureDevicePoint: capturePoint)
                }
                    .ignoresSafeArea()
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

                    Button {
                        camera.setHapticsEnabled(!camera.hapticsEnabled)
                    } label: {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 18, weight: .regular))
                            .overlay(alignment: .topTrailing) {
                                if !camera.hapticsEnabled {
                                    Image(systemName: "slash.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .offset(x: 5, y: -4)
                                }
                            }
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(camera.hapticsEnabled ? "Turn guidance haptics off" : "Turn guidance haptics on")
                    .accessibilityValue(camera.hapticsEnabled ? "On" : "Off")

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
                        cropAspectPicker
                        cropPositionControl
                        framePicker
                    }
                    .disabled(camera.isSaving)
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
                            restartCamera()
                        }
                        .foregroundStyle(.white)
                        .disabled(camera.isSaving)
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
                        .disabled(camera.isSaving)
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            Task { await FilmRenderer.shared.clearCaches() }
        }
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
            camera.stop()
            editorStampDate = Date()
            cropPosition = .center
            renderTask?.cancel()
            renderTask = renderPreview(data)
        }
        .onChange(of: camera.importedImage) { _, data in
            guard let data else { return }
            camera.stop()
            editorStampDate = Date()
            cropPosition = .center
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
        .onChange(of: selectedCropAspect) { _, _ in
            cropPosition = .center
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
            importTaskID = UUID()
            importTask = nil
            isImporting = false
            renderTask?.cancel()
            renderTask = nil
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
        restartCamera()
    }

    private func restartCamera() {
        Task {
            await camera.requestPermissionAndStart()
            await camera.startIfAuthorized()
        }
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

    private var cropAspectPicker: some View {
        HStack(spacing: 16) {
            ForEach(CropAspect.allCases) { aspect in
                Button(aspect.rawValue) { selectedCropAspect = aspect }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(selectedCropAspect == aspect ? .white : .white.opacity(0.62))
                    .accessibilityAddTraits(selectedCropAspect == aspect ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private var cropPositionControl: some View {
        if let axis = currentCropMovementAxis {
            HStack(spacing: 10) {
                Text(axis == .horizontal ? "Horizontal" : "Vertical")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                Slider(value: cropPositionBinding(for: axis), in: -1...1, onEditingChanged: { isEditing in
                    if !isEditing { renderCurrentSource() }
                })
                    .tint(.white)
                    .accessibilityLabel("Crop position")
                Button("Center") {
                    cropPosition = .center
                    renderCurrentSource()
                }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 28)
        }
    }

    private var currentCropMovementAxis: CropMovementAxis? {
        guard let data = camera.latestCapture ?? camera.importedImage,
              let sourceAspect = CropGeometry.sourceAspectRatio(from: data) else { return nil }
        return selectedCropAspect.movementAxis(for: sourceAspect)
    }

    private func cropPositionBinding(for axis: CropMovementAxis) -> Binding<Double> {
        Binding(
            get: { axis == .horizontal ? cropPosition.horizontal : cropPosition.vertical },
            set: { value in
                cropPosition = axis == .horizontal
                    ? CropPosition(horizontal: value, vertical: cropPosition.vertical)
                    : CropPosition(horizontal: cropPosition.horizontal, vertical: value)
            }
        )
    }

    private func renderCurrentSource() {
        guard let data = camera.latestCapture ?? camera.importedImage else { return }
        renderTask?.cancel()
        renderTask = renderPreview(data)
    }

    private func renderPreview(_ data: Data) -> Task<Void, Never> {
        let preset = selectedPreset
        let cropAspect = selectedCropAspect
        let cropPosition = self.cropPosition
        let frame = selectedFrame
        let dateStamp = includesDateStamp
        let stampDate = editorStampDate
        let sourceID = camera.latestCapture.map { _ in "capture" } ?? "import"
        let taskID = UUID()
        camera.renderTaskID = taskID
        camera.renderError = nil
        camera.renderedCapture = nil
        previewImage = nil
        isRendering = true
        return Task {
            do {
                let graded = try await FilmRenderer.shared.render(data, preset: preset,
                                                                  cropAspect: cropAspect,
                                                                  cropPosition: cropPosition)
                try Task.checkCancellation()
                let framed = try await FrameRenderer.shared.render(graded, layout: frame,
                                                                   dateStamp: dateStamp, stampDate: stampDate)
                try Task.checkCancellation()
                let cgImage = try await PreviewImageDecoder.shared.decode(framed)
                await MainActor.run {
                    guard camera.renderTaskID == taskID,
                          (camera.latestCapture != nil && sourceID == "capture") || (camera.importedImage != nil && sourceID == "import") else { return }
                    previewImage = UIImage(cgImage: cgImage)
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

final class CameraController: NSObject, ObservableObject, @unchecked Sendable {
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
    nonisolated private let sessionGeneration = SessionGeneration()
    @MainActor private var selectionGeneration = SessionGeneration()
    @MainActor private var hasInstalledSessionObservers = false
    @MainActor private var interruptionObservers: [NSObjectProtocol] = []
    @MainActor private var isConfiguring = false
    @MainActor @Published private(set) var isFrontCamera = false
    @MainActor private var sessionIsRunning = false
    private let motionManager = CMMotionManager()
    @MainActor private var deviceOrientation: UIDeviceOrientation = .portrait
    private let motionQueue = OperationQueue()
    @MainActor private var orientationObserver: NSObjectProtocol?

    @MainActor @Published
    var authorization: Authorization = .unknown
    @MainActor @Published
    var isCapturing = false
    @MainActor @Published
    var captureMessage: String?
    @MainActor @Published
    var latestCapture: Data?
    @MainActor @Published
    var isSaving = false
    @MainActor @Published
    var renderedCapture: Data?
    @MainActor @Published
    var renderError: String?
    @MainActor @Published
    var renderTaskID = UUID()
    @MainActor @Published
    var importedImage: Data?
    @MainActor @Published
    var guidanceText = "Searching for a subject"
    @MainActor @Published
    private(set) var hapticsEnabled = UserDefaults.standard.object(forKey: "FramedLocal.guidanceHapticsEnabled") as? Bool ?? true
    @MainActor @Published
    var horizonTilt: Double?
    @MainActor @Published
    var previewRotationAngle: CGFloat = 90
    @MainActor @Published
    var cameraStartupFailed = false
    @MainActor @Published
    var isSessionRunning = false
    @MainActor
    private var lastGuidanceHapticMessage: String?
    @MainActor
    private var horizonGuidanceState = HorizonGuidanceState()

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
    func setHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "FramedLocal.guidanceHapticsEnabled")
    }

    @MainActor
    private func installSessionObserversIfNeeded() {
        guard !hasInstalledSessionObservers else { return }
        hasInstalledSessionObservers = true
        let center = NotificationCenter.default
        interruptionObservers.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleSessionInterruption() }
        })
        interruptionObservers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleSessionInterruptionEnded() }
        })
        interruptionObservers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
            let domain = error?.domain ?? "AVFoundation"
            let code = error?.code ?? 0
            let message = error?.localizedDescription ?? "The camera stopped unexpectedly."
            Task { @MainActor [weak self] in
                self?.handleSessionRuntimeError(domain: domain, code: code, message: message)
            }
        })
    }

    @MainActor
    private func handleSessionInterruption() {
        guard sessionIsRunning else { return }
        analysisDelegate.pause()
        isSessionRunning = false
        captureMessage = "Camera temporarily unavailable. It will resume when available."
    }

    @MainActor
    private func handleSessionInterruptionEnded() {
        switch SessionRecoveryPolicy.interruptionEnded(shouldBeRunning: sessionIsRunning) {
        case .ignore: return
        case .resumeAutomatically:
            resumeSessionAfterSystemEvent(failureMessage: "Camera did not resume. Tap Retry camera.")
        case .showRetry: return
        }
    }

    @MainActor
    private func handleSessionRuntimeError(domain: String, code: Int, message: String) {
        let isMediaServicesReset = domain == AVFoundationErrorDomain
            && code == AVError.mediaServicesWereReset.rawValue
        switch SessionRecoveryPolicy.runtimeError(shouldBeRunning: sessionIsRunning,
                                                  mediaServicesWereReset: isMediaServicesReset) {
        case .ignore:
            return
        case .resumeAutomatically:
            resumeSessionAfterSystemEvent(failureMessage: "Camera could not resume after a system reset. Tap Retry camera.")
        case .showRetry:
            _ = sessionGeneration.advance()
            analysisDelegate.pause()
            sessionIsRunning = false
            isSessionRunning = false
            isConfiguring = false
            cameraStartupFailed = true
            captureMessage = "Camera stopped unexpectedly: \(message)"
        }
    }

    @MainActor
    private func resumeSessionAfterSystemEvent(failureMessage: String) {
        let generation = sessionGeneration.advance()
        let visionOrientation = self.visionOrientation
        isConfiguring = true
        analysisDelegate.pause()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.sessionGeneration.isCurrent(generation) else { return }
            if !self.session.isRunning { self.session.startRunning() }
            guard self.sessionGeneration.isCurrent(generation) else {
                if self.session.isRunning { self.session.stopRunning() }
                return
            }
            let resumed = self.session.isRunning
            if resumed {
                self.analysisDelegate.resume(on: self.analysisQueue, orientation: visionOrientation,
                                             while: { [weak self] in self?.sessionGeneration.isCurrent(generation) ?? false }) {
                    Task { @MainActor in
                        guard self.sessionGeneration.isCurrent(generation) else { return }
                        self.isConfiguring = false
                        self.isSessionRunning = true
                        self.cameraStartupFailed = false
                        self.captureMessage = nil
                        self.startMotionUpdates()
                    }
                }
            } else {
                Task { @MainActor in
                    guard self.sessionGeneration.isCurrent(generation) else { return }
                    self.isConfiguring = false
                    self.isSessionRunning = false
                    self.sessionIsRunning = false
                    self.cameraStartupFailed = true
                    self.captureMessage = failureMessage
                }
            }
        }
    }

    @MainActor
    func startIfAuthorized() async {
        guard authorization == .authorized, !sessionIsRunning, !isConfiguring else { return }
        installSessionObserversIfNeeded()
        sessionIsRunning = true
        isConfiguring = true
        isSessionRunning = false
        let generation = sessionGeneration.advance()
        let visionOrientation = self.visionOrientation
        analysisDelegate.pause()
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        let angle = rotationAngle(for: deviceOrientation)

        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureSession(position: position, rotationAngle: angle)
                guard self.sessionGeneration.isCurrent(generation) else { return }
                self.session.startRunning()
                guard self.sessionGeneration.isCurrent(generation) else {
                    if self.session.isRunning { self.session.stopRunning() }
                    return
                }
                self.analysisDelegate.resume(on: self.analysisQueue, orientation: visionOrientation,
                                             while: { [weak self] in self?.sessionGeneration.isCurrent(generation) ?? false }) {
                    Task { @MainActor in
                        guard self.sessionGeneration.isCurrent(generation) else { return }
                        self.isConfiguring = false
                        self.cameraStartupFailed = false
                        self.isSessionRunning = true
                        self.startMotionUpdates()
                    }
                }
            } catch {
                Task { @MainActor in
                    guard self.sessionGeneration.isCurrent(generation) else { return }
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
        _ = sessionGeneration.advance()
        analysisDelegate.pause()
        clearSubjectSelection()
        horizonTilt = nil
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
        isFrontCamera.toggle()
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        let angle = rotationAngle(for: deviceOrientation)
        guard sessionIsRunning else {
            isFrontCamera.toggle()
            captureMessage = "Start the camera before switching lenses."
            return
        }
        isSessionRunning = false
        isConfiguring = true
        cameraStartupFailed = false
        let generation = sessionGeneration.advance()
        let visionOrientation = self.visionOrientation
        analysisDelegate.pause()
        clearSubjectSelection()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureSession(position: position, rotationAngle: angle)
                self.analysisDelegate.resume(on: self.analysisQueue, orientation: visionOrientation,
                                             while: { [weak self] in self?.sessionGeneration.isCurrent(generation) ?? false }) {
                    Task { @MainActor in
                        guard self.sessionGeneration.isCurrent(generation) else { return }
                        self.isConfiguring = false
                        self.isSessionRunning = true
                    }
                }
            } catch {
                Task { @MainActor in
                    guard self.sessionGeneration.isCurrent(generation) else { return }
                    self.isFrontCamera = position == .back
                    self.isConfiguring = false
                    self.sessionIsRunning = false
                    self.isSessionRunning = false
                    self.cameraStartupFailed = true
                    self.captureMessage = error.localizedDescription
                }
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
        let angle = rotationAngle(for: deviceOrientation)
        let mirrored = isFrontCamera
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
                if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = mirrored
                }
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
                captureMessage = PhotoSaveDestination.statusMessage(savedInAlbum: savedInAlbum)
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
    func selectSubject(atCaptureDevicePoint point: CGPoint) {
        guard isSessionRunning else { return }
        let selectionToken = selectionGeneration.advance()
        let normalized = VisionTapPointMapper.visionPoint(fromCaptureDevicePoint: point,
                                                          orientation: visionOrientation)
        captureMessage = "Finding selected subject…"
        analysisDelegate.selectSubject(normalizedPoint: normalized, orientation: visionOrientation,
                                       on: analysisQueue) { [weak self] didSelect in
            Task { @MainActor [weak self] in
                guard let self, self.selectionGeneration.isCurrent(selectionToken) else { return }
                self.captureMessage = SubjectSelectionFeedback.message(didSelectSubject: didSelect)
            }
        }
    }

    @MainActor
    private func clearSubjectSelection() {
        _ = selectionGeneration.advance()
        analysisDelegate.clearSelection(on: analysisQueue)
        if captureMessage == "Finding selected subject…"
            || captureMessage == "Tracking selected subject"
            || captureMessage == "No subject found — try tapping closer" {
            captureMessage = nil
        }
    }

    @MainActor private var visionOrientation: CGImagePropertyOrientation {
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
            let gravityX = motion.gravity.x
            let gravityY = motion.gravity.y
            Task { @MainActor in
                guard let self else { return }
                self.horizonTilt = HorizonLeveling.angle(gravityX: gravityX, gravityY: gravityY,
                                                         orientation: self.deviceOrientation)
            }
        }
    }

    @MainActor
    private func updateConnectionsOrientation() {
        let angle = rotationAngle(for: deviceOrientation)
        let mirrored = isFrontCamera
        analysisDelegate.updateOrientation(visionOrientation, on: analysisQueue)
        previewRotationAngle = angle
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if let photoConnection = self.photoOutput.connection(with: .video),
               photoConnection.isVideoRotationAngleSupported(angle) {
                photoConnection.videoRotationAngle = angle
            }
            // Keep analysis pixels in sensor orientation; Vision receives the matching EXIF orientation.
            if let analysisConnection = self.analysisOutput.connection(with: .video),
               analysisConnection.isVideoRotationAngleSupported(0) {
                analysisConnection.videoRotationAngle = 0
            }
            if let photoConnection = self.photoOutput.connection(with: .video),
               photoConnection.isVideoMirroringSupported {
                photoConnection.automaticallyAdjustsVideoMirroring = false
                photoConnection.isVideoMirrored = mirrored
            }
            if let analysisConnection = self.analysisOutput.connection(with: .video),
               analysisConnection.isVideoMirroringSupported {
                // Match Vision coordinates to the unmirrored capture-device point.
                analysisConnection.automaticallyAdjustsVideoMirroring = false
                analysisConnection.isVideoMirrored = false
            }
        }
    }

    nonisolated private func configureSession(position: AVCaptureDevice.Position, rotationAngle angle: CGFloat) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        do {
            session.sessionPreset = .photo

            if let activeInput {
                session.removeInput(activeInput)
                self.activeInput = nil
            }
            if session.outputs.contains(photoOutput) { session.removeOutput(photoOutput) }
            if session.outputs.contains(analysisOutput) { session.removeOutput(analysisOutput) }

            let deviceTypes: [AVCaptureDevice.DeviceType] = position == .back
                ? [.builtInWideAngleCamera]
                : [.builtInTrueDepthCamera, .builtInWideAngleCamera]
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: position
            )
            guard let device = discovery.devices.first else { throw CameraError.cameraUnavailable }
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CameraError.cannotAddCamera }
            session.addInput(input)
            activeInput = input

            if let previewConnection = session.connections.first(where: { $0.inputPorts.contains(where: { $0.mediaType == .video }) }),
               previewConnection.isVideoMirroringSupported {
                previewConnection.automaticallyAdjustsVideoMirroring = false
                previewConnection.isVideoMirrored = position == .front
            }

            guard session.canAddOutput(photoOutput) else { throw CameraError.cannotAddPhotoOutput }
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            analysisOutput.alwaysDiscardsLateVideoFrames = true
            // Keep Vision and metric sampling on preview-sized frames, not sensor-resolution frames.
            analysisOutput.automaticallyConfiguresOutputBufferDimensions = true
            analysisOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            analysisDelegate.analyzer = compositionAnalyzer
            analysisOutput.setSampleBufferDelegate(analysisDelegate, queue: analysisQueue)
            if let connection = analysisOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(0) { connection.videoRotationAngle = 0 }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
            }
            guard session.canAddOutput(analysisOutput) else { throw CameraError.cannotAddAnalysisOutput }
            session.addOutput(analysisOutput)
            analysisDelegate.onResult = { [weak self] result in
                guard let self else { return }
                Task { @MainActor in
                    let levelHintIsStable = self.horizonGuidanceState.shouldShowLevelHint(
                        angle: self.horizonTilt, at: CFAbsoluteTimeGetCurrent())
                    let message = levelHintIsStable && result.guidance == "Suggested framing"
                        ? "Level the phone" : result.guidance
                    self.guidanceText = message
                    if GuidanceHaptics.shouldTrigger(message: message,
                                                     previousMessage: self.lastGuidanceHapticMessage,
                                                     enabled: self.hapticsEnabled) {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                    self.lastGuidanceHapticMessage = message
                }
            }
            isConfigured = true
        } catch {
            if let activeInput, session.inputs.contains(where: { $0 === activeInput }) {
                session.removeInput(activeInput)
                self.activeInput = nil
            }
            if session.outputs.contains(photoOutput) { session.removeOutput(photoOutput) }
            if session.outputs.contains(analysisOutput) { session.removeOutput(analysisOutput) }
            isConfigured = false
            throw error
        }
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

final class SessionGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0

    func advance() -> UInt64 {
        lock.lock()
        value &+= 1
        let currentValue = value
        lock.unlock()
        return currentValue
    }

    func isCurrent(_ candidate: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value == candidate
    }
}

final class AnalysisGenerationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var acceptsFrames = false

    func pause() {
        lock.lock()
        acceptsFrames = false
        generation &+= 1
        lock.unlock()
    }

    func pause(ifCurrent generation: UInt64) {
        lock.lock()
        if self.generation == generation {
            acceptsFrames = false
            self.generation &+= 1
        }
        lock.unlock()
    }

    func resume() -> UInt64 {
        lock.lock()
        generation &+= 1
        acceptsFrames = true
        let currentGeneration = generation
        lock.unlock()
        return currentGeneration
    }

    func generationForFrame() -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        return acceptsFrames ? generation : nil
    }

    func acceptsResult(for frameGeneration: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return acceptsFrames && generation == frameGeneration
    }
}

enum SessionRecoveryAction: Equatable {
    case ignore
    case resumeAutomatically
    case showRetry
}

enum SessionRecoveryPolicy {
    static func interruptionEnded(shouldBeRunning: Bool) -> SessionRecoveryAction {
        shouldBeRunning ? .resumeAutomatically : .ignore
    }

    static func runtimeError(shouldBeRunning: Bool,
                             mediaServicesWereReset: Bool) -> SessionRecoveryAction {
        guard shouldBeRunning else { return .ignore }
        return mediaServicesWereReset ? .resumeAutomatically : .showRetry
    }
}

private final class VideoAnalysisDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    weak var analyzer: CompositionAnalyzer?
    var onResult: ((AnalysisResult) -> Void)?
    private let generationGate = AnalysisGenerationGate()
    private var analysisOrientation: CGImagePropertyOrientation = .right
    private var mostRecentPixelBuffer: CVPixelBuffer?

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let source = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        mostRecentPixelBuffer = source
        guard let generation = generationGate.generationForFrame() else { return }
        let orientation = analysisOrientation
        analyzer?.analyze(source, orientation: orientation) { [weak self] result in
            guard let self, let result, self.generationGate.acceptsResult(for: generation) else { return }
            self.onResult?(result)
        }
    }

    func pause() {
        generationGate.pause()
    }

    func updateOrientation(_ orientation: CGImagePropertyOrientation, on queue: DispatchQueue) {
        queue.async { [weak self] in self?.analysisOrientation = orientation }
    }

    func resume(on queue: DispatchQueue, orientation: CGImagePropertyOrientation,
                while shouldResume: @escaping @Sendable () -> Bool,
                completion: @escaping @Sendable () -> Void) {
        queue.async { [weak self] in
            guard let self else { completion(); return }
            self.mostRecentPixelBuffer = nil
            self.analysisOrientation = orientation
            self.analyzer?.clearSelection()
            guard shouldResume() else { completion(); return }
            let generation = self.generationGate.resume()
            guard shouldResume() else {
                self.generationGate.pause(ifCurrent: generation)
                completion()
                return
            }
            completion()
        }
    }

    func selectSubject(normalizedPoint: CGPoint, orientation: CGImagePropertyOrientation = .right,
                       on queue: DispatchQueue,
                       completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self, let mostRecentPixelBuffer = self.mostRecentPixelBuffer else {
                completion(false)
                return
            }
            let didSelect = self.analyzer?.selectSubject(at: normalizedPoint, in: mostRecentPixelBuffer,
                                                         orientation: orientation) ?? false
            completion(didSelect)
        }
    }

    func clearSelection(on queue: DispatchQueue) {
        queue.async { [weak self] in
            self?.analyzer?.clearSelection()
        }
    }
}

enum PhotoCaptureResultResolver {
    static func resolve(processedResult: Result<Data, Error>?,
                        captureError: Error?,
                        missingDataError: Error) -> Result<Data, Error> {
        if let captureError { return .failure(captureError) }
        return processedResult ?? .failure(missingDataError)
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var processedResult: Result<Data, Error>?
    private var didComplete = false
    var didCapture: ((Result<Data, Error>) -> Void)?

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let result: Result<Data, Error>
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation() {
            result = .success(data)
        } else {
            result = .failure(CaptureError.missingData)
        }
        lock.lock()
        if !didComplete { processedResult = result }
        lock.unlock()
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        lock.lock()
        guard !didComplete else { lock.unlock(); return }
        didComplete = true
        let result = PhotoCaptureResultResolver.resolve(processedResult: processedResult,
                                                        captureError: error,
                                                        missingDataError: CaptureError.missingData)
        let completion = didCapture
        didCapture = nil
        lock.unlock()
        completion?(result)
    }

    private enum CaptureError: LocalizedError {
        case missingData
        var errorDescription: String? { "The captured photo could not be read." }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let rotationAngle: CGFloat
    let isMirrored: Bool
    let onTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator,
                                                          action: #selector(Coordinator.handleTap(_:))))
        context.coordinator.previewView = view
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection {
            if connection.isVideoRotationAngleSupported(rotationAngle) {
                connection.videoRotationAngle = rotationAngle
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isMirrored
            }
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.previewView = uiView
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        if let connection = uiView.previewLayer.connection {
            if connection.isVideoRotationAngleSupported(rotationAngle),
               connection.videoRotationAngle != rotationAngle {
                connection.videoRotationAngle = rotationAngle
            }
            if connection.isVideoMirroringSupported,
               connection.isVideoMirrored != isMirrored {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isMirrored
            }
        }
    }

    final class Coordinator: NSObject {
        weak var previewView: PreviewView?
        var onTap: (CGPoint) -> Void

        init(onTap: @escaping (CGPoint) -> Void) {
            self.onTap = onTap
        }

        @MainActor @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let previewView else { return }
            let layerPoint = recognizer.location(in: previewView)
            let capturePoint = previewView.previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            onTap(capturePoint)
        }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
