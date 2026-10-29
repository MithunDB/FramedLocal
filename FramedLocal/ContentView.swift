import AVFoundation
import Combine
import CoreImage
import SwiftUI
import UIKit
import PhotosUI
import CoreVideo
import CoreMotion
import ImageIO
import MetalKit

struct ContentView: View {
    private enum EditorTool: String, CaseIterable {
        case look = "Look"
        case crop = "Crop"
        case frame = "Frame"
    }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraController()
    @State private var selectedPreset: FilmPreset = .natural
    @State private var selectedCropAspect: CropAspect = .original
    @State private var cropPosition = CropPosition.center
    @State private var selectedFrame: FrameLayout = .whiteBorder
    @State private var includesDateStamp = true
    @State private var showsCompositionGuides = true
    @State private var selectedEditorTool: EditorTool = .look
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

            if camera.authorization == .authorized && camera.latestCapture == nil && camera.importedImage == nil {
                cameraPreviewContent
            } else if camera.latestCapture != nil || camera.importedImage != nil {
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
                    if showsCompositionGuides {
                        VStack(spacing: 8) {
                            Text(camera.guidanceText)
                                .font(.caption.weight(.medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.black.opacity(0.45), in: Capsule())
                            if let zoom = camera.suggestedZoomFactor {
                                Button {
                                    camera.applyZoomFactor(zoom)
                                } label: {
                                    Label("Zoom to \(zoom, format: .number.precision(.fractionLength(1)))×",
                                          systemImage: "plus.magnifyingglass")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(.cyan.opacity(0.38), in: Capsule())
                                }
                                .accessibilityHint("Adjusts camera zoom to make the detected subject larger in the preview")
                            }
                        }
                        .padding(.bottom, 165)
                    }
                }
                .allowsHitTesting(false)
            }

            VStack {
                if camera.isSaving {
                    HStack {
                        Text("SAVING TO PHOTOS")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .tracking(2)
                        Spacer()
                        ProgressView().tint(.white)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                } else if camera.latestCapture != nil || camera.importedImage != nil {
                    HStack {
                        Text("EDIT COPY")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .tracking(2)
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                } else {
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
                        .disabled(camera.authorization != .authorized || !camera.isSessionRunning || camera.isCapturing || isImporting)

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

                        Button {
                            showsCompositionGuides.toggle()
                        } label: {
                            Image(systemName: showsCompositionGuides ? "viewfinder" : "viewfinder.circle")
                                .font(.system(size: 18, weight: .regular))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(showsCompositionGuides ? "Hide composition guides" : "Show composition guides")

                        PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 19, weight: .regular))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Choose a photo to edit")
                        .disabled(isImporting)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                }

                Spacer()

                if camera.isSaving {
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Saving a new copy…")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.bottom, 36)
                } else if !isImporting || camera.latestCapture != nil || camera.importedImage != nil {
                    editorControls
                        .padding(.bottom, 14)
                }

                if !camera.isSaving, let captureMessage = camera.captureMessage {
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
                if isImporting && !camera.isSaving {
                    Button("Cancel import", action: cancelImport)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)
                }

                if !camera.isSaving && camera.latestCapture != nil {
                    HStack(spacing: 18) {
                        Button("Retake") {
                            camera.discardCapture()
                            previewImage = nil
                            restartCamera()
                        }
                        .foregroundStyle(.white)
                        .disabled(camera.isSaving)
                        Button(isCurrentRenderSaved ? "Saved" : "Save to Photos") {
                            camera.saveLatestCapture()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                        .disabled(camera.isSaving || isRendering || camera.renderedCapture == nil || isCurrentRenderSaved)
                    }
                    .padding(.bottom, 12)
                } else if !camera.isSaving && camera.importedImage != nil {
                    HStack(spacing: 18) {
                        Button("Cancel") {
                            cancelImport()
                        }
                        .foregroundStyle(.white)
                        .disabled(camera.isSaving)
                        Button(isCurrentRenderSaved ? "Saved" : "Export New Copy") {
                            camera.saveLatestCapture()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                        .disabled(camera.isSaving || isRendering || camera.renderedCapture == nil || isCurrentRenderSaved)
                    }
                    .padding(.bottom, 12)
                }

                if !camera.isSaving && camera.latestCapture == nil && camera.importedImage == nil {
                HStack {
                    Spacer()
                    Button {
                        if camera.latestCapture == nil && camera.importedImage == nil {
                            camera.capture()
                        }
                    } label: {
                        Circle()
                            .stroke(camera.isFramingAligned ? Color.cyan : Color.white.opacity(0.85), lineWidth: 3)
                            .frame(width: 76, height: 76)
                            .overlay {
                                Circle().fill(.white).padding(7)
                            }
                    }
                    .accessibilityLabel("Take photo")
                    .accessibilityValue(camera.isFramingAligned ? "Composition guide aligned" : "Composition guide active")
                    .disabled(camera.authorization != .authorized || !camera.isSessionRunning || camera.isCapturing || camera.isSaving || camera.latestCapture != nil || camera.importedImage != nil)
                    Spacer()
                }
                .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            handleMemoryWarning()
        }
        .task {
            camera.updateLivePreviewSettings(currentLivePreviewSettings)
            camera.setCompositionGuidanceEnabled(showsCompositionGuides)
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
            camera.updateLivePreviewSettings(currentLivePreviewSettings)
            if let data = camera.latestCapture ?? camera.importedImage { renderTask?.cancel(); renderTask = renderPreview(data) }
        }
        .onChange(of: selectedCropAspect) { _, _ in
            cropPosition = .center
            camera.updateLivePreviewSettings(currentLivePreviewSettings)
            if let data = camera.latestCapture ?? camera.importedImage { renderTask?.cancel(); renderTask = renderPreview(data) }
        }
        .onChange(of: cropPosition) { _, _ in
            camera.updateLivePreviewSettings(currentLivePreviewSettings)
        }
        .onChange(of: camera.isFrontCamera) { _, _ in
            camera.updateLivePreviewSettings(currentLivePreviewSettings)
        }
        .onChange(of: showsCompositionGuides) { _, isEnabled in
            camera.setCompositionGuidanceEnabled(isEnabled)
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
            photoPickerItem = nil
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
                let data = try await PhotoImportService.loadImageData(from: item)
                try Task.checkCancellation()
                await MainActor.run {
                    guard importTaskID == taskID else { return }
                    camera.importedImage = data
                    camera.captureMessage = "Original kept unchanged · edit a new copy"
                    photoPickerItem = nil
                    isImporting = false
                    importTask = nil
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    guard importTaskID == taskID else { return }
                    camera.captureMessage = error.localizedDescription
                    photoPickerItem = nil
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
        photoPickerItem = nil
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

    private var currentLivePreviewSettings: LivePreviewSettings {
        LivePreviewSettings(preset: selectedPreset, cropAspect: selectedCropAspect,
                            cropPosition: cropPosition, isMirrored: camera.isFrontCamera)
    }

    private var cameraPreviewContent: some View {
        ZStack {
            CameraPreview(session: camera.session, rotationAngle: camera.previewRotationAngle,
                          isMirrored: camera.isFrontCamera,
                          isVisible: !currentLivePreviewSettings.requiresProcessedPreview) { capturePoint in
                camera.selectSubject(atCaptureDevicePoint: capturePoint)
            }
            if currentLivePreviewSettings.requiresProcessedPreview {
                MetalLivePreview(mailbox: camera.livePreviewMailbox, isActive: camera.isSessionRunning)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if selectedCropAspect == .original {
                if showsCompositionGuides {
                    LiveCompositionOverlay(subjectRect: camera.trackedSubjectRect,
                                           targetThird: camera.compositionTargetThird,
                                           isTracking: camera.isSubjectTracking,
                                           isAligned: camera.isFramingAligned,
                                           isMirrored: camera.isFrontCamera)
                        .ignoresSafeArea()
                }
                LiveFrameTreatment(layout: selectedFrame, dateStamp: includesDateStamp, date: editorStampDate)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                GeometryReader { geometry in
                    let previewRect = fittedPreviewRect(in: geometry.size,
                                                        aspect: selectedCropAspect.ratio ?? 1)
                    if showsCompositionGuides {
                        LiveCompositionOverlay(subjectRect: camera.trackedSubjectRect,
                                               targetThird: camera.compositionTargetThird,
                                               isTracking: camera.isSubjectTracking,
                                               isAligned: camera.isFramingAligned,
                                               isMirrored: camera.isFrontCamera)
                            .frame(width: previewRect.width, height: previewRect.height)
                            .position(x: previewRect.midX, y: previewRect.midY)
                    }
                    LiveFrameTreatment(layout: selectedFrame, dateStamp: includesDateStamp, date: editorStampDate)
                        .frame(width: previewRect.width, height: previewRect.height)
                        .position(x: previewRect.midX, y: previewRect.midY)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    private func fittedPreviewRect(in size: CGSize, aspect: CGFloat) -> CGRect {
        guard size.width > 0, size.height > 0, aspect.isFinite, aspect > 0 else { return .zero }
        let containerAspect = size.width / size.height
        let fittedSize: CGSize
        if containerAspect > aspect {
            fittedSize = CGSize(width: size.height * aspect, height: size.height)
        } else {
            fittedSize = CGSize(width: size.width, height: size.width / aspect)
        }
        return CGRect(x: (size.width - fittedSize.width) / 2,
                      y: (size.height - fittedSize.height) / 2,
                      width: fittedSize.width, height: fittedSize.height)
    }

    private var isCurrentRenderSaved: Bool {
        camera.captureMessage?.hasPrefix("Saved to Photos") == true
    }

    private var editorControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(EditorTool.allCases, id: \.self) { tool in
                    Button(tool.rawValue) { selectedEditorTool = tool }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedEditorTool == tool ? .black : .white.opacity(0.82))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 7)
                        .background(selectedEditorTool == tool ? Color.white : Color.white.opacity(0.14), in: Capsule())
                        .accessibilityAddTraits(selectedEditorTool == tool ? .isSelected : [])
                }
            }

            Group {
                switch selectedEditorTool {
                case .look:
                    presetPicker
                case .crop:
                    VStack(spacing: 7) {
                        cropAspectPicker
                        cropPositionControl
                    }
                case .frame:
                    framePicker
                }
            }
        }
        .disabled(camera.isSaving)
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
        if camera.captureMessage?.hasPrefix("Saved to Photos") == true {
            camera.captureMessage = nil
        }
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
                try Task.checkCancellation()
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

    private func handleMemoryWarning() {
        let renderID = camera.renderTaskID
        let renderedData = camera.renderedCapture
        previewImage = nil
        Task {
            await FilmRenderer.shared.clearCaches()
            guard let renderedData else { return }
            do {
                let image = try await PreviewImageDecoder.shared.decode(renderedData,
                                                                        maximumPixelDimension: 1_000)
                guard camera.renderTaskID == renderID, camera.renderedCapture != nil else { return }
                previewImage = UIImage(cgImage: image)
            } catch {
                guard camera.renderTaskID == renderID else { return }
                camera.renderError = error.localizedDescription
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
    let livePreviewMailbox = LivePreviewMailbox()
    private let analysisQueue = DispatchQueue(label: "local.mithundb.framed.analysis-frames", qos: .userInitiated)
    private let sessionQueue = DispatchQueue(label: "local.mithundb.framed.camera-session")
    private var photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptures: [Int64: PhotoCaptureDelegate] = [:]
    private var activeInput: AVCaptureDeviceInput?
    private var isConfigured = false
    nonisolated private let sessionGeneration = SessionGeneration()
    nonisolated private let motionGeneration = SessionGeneration()
    @MainActor private var selectionGeneration = SessionGeneration()
    @MainActor private var hasInstalledSessionObservers = false
    @MainActor private var interruptionObservers: [NSObjectProtocol] = []
    @MainActor private var isConfiguring = false
    @MainActor @Published private(set) var isFrontCamera = false
    @MainActor private var shouldRunSession = false
    @MainActor private var compositionGuidanceEnabled = true
    @MainActor private var livePreviewSettings = LivePreviewSettings()
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
    @MainActor @Published private(set) var trackedSubjectRect: CGRect?
    @MainActor @Published private(set) var compositionTargetThird: CGPoint?
    @MainActor @Published private(set) var isSubjectTracking = false
    @MainActor @Published private(set) var isFramingAligned = false
    @MainActor @Published private(set) var suggestedZoomFactor: Double?
    @MainActor @Published private(set) var currentZoomFactor = 1.0
    @MainActor private var maximumZoomFactor = 3.0
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
    func updateLivePreviewSettings(_ settings: LivePreviewSettings) {
        livePreviewSettings = settings
        livePreviewMailbox.update(settings: settings)
        analysisDelegate.updatePreviewSettings(settings, on: analysisQueue)
        updateVideoFrameDeliveryPolicy()
    }

    @MainActor
    func setCompositionGuidanceEnabled(_ enabled: Bool) {
        guard compositionGuidanceEnabled != enabled else { return }
        compositionGuidanceEnabled = enabled
        analysisDelegate.updateGuidanceEnabled(enabled, on: analysisQueue)
        updateVideoFrameDeliveryPolicy()
        if enabled {
            guidanceText = "Searching for a subject"
            if isSessionRunning, shouldRunSession { startMotionUpdates() }
        } else {
            stopMotionUpdates()
            clearSubjectSelection()
            trackedSubjectRect = nil
            compositionTargetThird = nil
            suggestedZoomFactor = nil
            isSubjectTracking = false
            isFramingAligned = false
            guidanceText = "Composition guides off"
        }
    }

    @MainActor
    func applyZoomFactor(_ factor: Double) {
        let requestedFactor = min(max(factor, 1), maximumZoomFactor)
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeInput?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                let appliedFactor = min(requestedFactor, Double(device.activeFormat.videoMaxZoomFactor))
                device.videoZoomFactor = CGFloat(appliedFactor)
                Task { @MainActor [weak self] in
                    self?.currentZoomFactor = appliedFactor
                    self?.suggestedZoomFactor = nil
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.captureMessage = "Camera zoom is temporarily unavailable."
                }
            }
        }
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
    private func removeSessionObservers() {
        guard hasInstalledSessionObservers else { return }
        interruptionObservers.forEach(NotificationCenter.default.removeObserver)
        interruptionObservers.removeAll()
        hasInstalledSessionObservers = false
    }

    @MainActor
    private func pauseAnalysis() {
        analysisDelegate.pause(on: analysisQueue)
        livePreviewMailbox.clearFrame()
        guidanceText = "Searching for a subject"
        trackedSubjectRect = nil
        compositionTargetThird = nil
        isSubjectTracking = false
        isFramingAligned = false
        suggestedZoomFactor = nil
        lastGuidanceHapticMessage = nil
    }

    @MainActor
    private func updateVideoFrameDeliveryPolicy() {
        let shouldDeliverFrames = CameraFrameDeliveryPolicy.shouldDeliverFrames(
            sessionIsRunning: shouldRunSession,
            guidanceEnabled: compositionGuidanceEnabled,
            previewRequiresProcessing: livePreviewSettings.requiresProcessedPreview
        )
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.analysisOutput.setSampleBufferDelegate(
                shouldDeliverFrames ? self.analysisDelegate : nil,
                queue: shouldDeliverFrames ? self.analysisQueue : nil
            )
        }
    }

    @MainActor
    private func handleSessionInterruption() {
        guard shouldRunSession else { return }
        pauseAnalysis()
        isSessionRunning = false
        stopMotionUpdates()
        captureMessage = "Camera temporarily unavailable. It will resume when available."
    }

    @MainActor
    private func handleSessionInterruptionEnded() {
        switch SessionRecoveryPolicy.interruptionEnded(shouldBeRunning: shouldRunSession) {
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
        switch SessionRecoveryPolicy.runtimeError(shouldBeRunning: shouldRunSession,
                                                  mediaServicesWereReset: isMediaServicesReset) {
        case .ignore:
            return
        case .resumeAutomatically:
            // Media-services reset can invalidate sensor callbacks and their
            // orientation observer; remove them before installing a new generation.
            stopMotionUpdates()
            resumeSessionAfterSystemEvent(failureMessage: "Camera could not resume after a system reset. Tap Retry camera.")
        case .showRetry:
            _ = sessionGeneration.advance()
            pauseAnalysis()
            shouldRunSession = false
            isSessionRunning = false
            isConfiguring = false
            cameraStartupFailed = true
            stopMotionUpdates()
            captureMessage = "Camera stopped unexpectedly: \(message)"
        }
    }

    @MainActor
    private func resumeSessionAfterSystemEvent(failureMessage: String) {
        let generation = sessionGeneration.advance()
        let visionOrientation = self.visionOrientation
        isConfiguring = true
        pauseAnalysis()
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
                        self.updateVideoFrameDeliveryPolicy()
                        if self.compositionGuidanceEnabled { self.startMotionUpdates() }
                    }
                }
            } else {
                Task { @MainActor in
                    guard self.sessionGeneration.isCurrent(generation) else { return }
                    self.isConfiguring = false
                    self.isSessionRunning = false
                    self.shouldRunSession = false
                    self.cameraStartupFailed = true
                    self.captureMessage = failureMessage
                }
            }
        }
    }

    @MainActor
    func startIfAuthorized() async {
        guard authorization == .authorized, !shouldRunSession, !isConfiguring else { return }
        installSessionObserversIfNeeded()
        shouldRunSession = true
        isConfiguring = true
        isSessionRunning = false
        let generation = sessionGeneration.advance()
        let visionOrientation = self.visionOrientation
        pauseAnalysis()
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
                guard CaptureSessionStartOutcome.resolve(isRunning: self.session.isRunning) == .started else {
                    Task { @MainActor in
                        guard self.sessionGeneration.isCurrent(generation) else { return }
                        self.shouldRunSession = false
                        self.isConfiguring = false
                        self.isSessionRunning = false
                        self.cameraStartupFailed = true
                        self.captureMessage = "The camera did not start. Tap Retry camera."
                    }
                    return
                }
                self.analysisDelegate.resume(on: self.analysisQueue, orientation: visionOrientation,
                                             while: { [weak self] in self?.sessionGeneration.isCurrent(generation) ?? false }) {
                    Task { @MainActor in
                        guard self.sessionGeneration.isCurrent(generation) else { return }
                        self.isConfiguring = false
                        self.cameraStartupFailed = false
                        self.isSessionRunning = true
                        self.updateVideoFrameDeliveryPolicy()
                        if self.compositionGuidanceEnabled { self.startMotionUpdates() }
                    }
                }
            } catch {
                Task { @MainActor in
                    guard self.sessionGeneration.isCurrent(generation) else { return }
                    self.shouldRunSession = false
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
        removeSessionObservers()
        pauseAnalysis()
        clearSubjectSelection()
        stopMotionUpdates()
        shouldRunSession = false
        isSessionRunning = false
        isConfiguring = false
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.analysisOutput.setSampleBufferDelegate(nil, queue: nil)
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    @MainActor
    private func stopMotionUpdates() {
        _ = motionGeneration.advance()
        motionManager.stopDeviceMotionUpdates()
        horizonTilt = nil
        horizonGuidanceState = HorizonGuidanceState()
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
            self.orientationObserver = nil
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    @MainActor
    func toggleCamera() {
        isFrontCamera.toggle()
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        let angle = rotationAngle(for: deviceOrientation)
        guard shouldRunSession else {
            isFrontCamera.toggle()
            captureMessage = "Start the camera before switching lenses."
            return
        }
        isSessionRunning = false
        isConfiguring = true
        cameraStartupFailed = false
        let generation = sessionGeneration.advance()
        let visionOrientation = self.visionOrientation
        pauseAnalysis()
        clearSubjectSelection()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.sessionGeneration.isCurrent(generation) else { return }
            do {
                try self.configureSession(position: position, rotationAngle: angle)
                guard self.sessionGeneration.isCurrent(generation) else { return }
                guard CaptureSessionStartOutcome.resolve(isRunning: self.session.isRunning) == .started else {
                    Task { @MainActor in
                        guard self.sessionGeneration.isCurrent(generation) else { return }
                        self.stopMotionUpdates()
                        self.isFrontCamera = position == .back
                        self.shouldRunSession = false
                        self.isConfiguring = false
                        self.isSessionRunning = false
                        self.cameraStartupFailed = true
                        self.captureMessage = "The camera stopped while switching lenses. Tap Retry camera."
                    }
                    return
                }
                self.analysisDelegate.resume(on: self.analysisQueue, orientation: visionOrientation,
                                             while: { [weak self] in self?.sessionGeneration.isCurrent(generation) ?? false }) {
                    Task { @MainActor in
                        guard self.sessionGeneration.isCurrent(generation) else { return }
                        self.isConfiguring = false
                        self.isSessionRunning = true
                        self.updateVideoFrameDeliveryPolicy()
                    }
                }
            } catch {
                if self.session.isRunning { self.session.stopRunning() }
                Task { @MainActor in
                    guard self.sessionGeneration.isCurrent(generation) else { return }
                    self.stopMotionUpdates()
                    self.isFrontCamera = position == .back
                    self.shouldRunSession = false
                    self.isConfiguring = false
                    self.isSessionRunning = false
                    self.cameraStartupFailed = true
                    self.captureMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    func capture() {
        guard CaptureAvailability.canCapture(sessionIsRunning: isSessionRunning,
                                             isCapturing: isCapturing) else {
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
        guard isSessionRunning, compositionGuidanceEnabled else { return }
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
        guard compositionGuidanceEnabled else { return }
        let generation = motionGeneration.advance()
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        deviceOrientation = UIDevice.current.orientation
        updateConnectionsOrientation()
        if orientationObserver == nil {
            orientationObserver = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification,
                                                                          object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.motionGeneration.isCurrent(generation) else { return }
                let current = UIDevice.current.orientation
                guard current.isPortrait || current.isLandscape else { return }
                self.deviceOrientation = current
                self.updateConnectionsOrientation()
            }
            }
        }
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: motionQueue,
                                               withHandler: deviceMotionHandler(generation: generation))
    }

    /// Core Motion invokes this callback on `motionQueue`, which is not MainActor.
    /// Keeping the closure in a nonisolated method avoids inheriting the actor
    /// isolation of `startMotionUpdates()` and trapping on Swift's executor check.
    nonisolated private func deviceMotionHandler(generation: UInt64) -> CMDeviceMotionHandler {
        { [weak self] motion, _ in
            guard let motion else { return }
            let gravityX = motion.gravity.x
            let gravityY = motion.gravity.y
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.motionGeneration.isCurrent(generation) else { return }
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
            try device.lockForConfiguration()
            device.videoZoomFactor = 1
            device.unlockForConfiguration()
            let maximumZoom = min(3, Double(device.activeFormat.videoMaxZoomFactor))
            Task { @MainActor [weak self] in
                self?.currentZoomFactor = 1
                self?.maximumZoomFactor = max(1, maximumZoom)
            }

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
            analysisDelegate.livePreviewMailbox = livePreviewMailbox
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
            analysisDelegate.onResult = { [weak self] result, generation in
                guard let self else { return }
                Task { @MainActor in
                    // A result may be queued to MainActor just before pauseAnalysis()
                    // invalidates its analysis generation.
                    guard self.analysisDelegate.acceptsResult(for: generation) else { return }
                    let levelHintIsStable = self.horizonGuidanceState.shouldShowLevelHint(
                        angle: self.horizonTilt, at: MonotonicClock.now)
                    let fallback = levelHintIsStable && result.guidance == "Suggested framing"
                        ? "Level the phone" : result.guidance
                    let advice = LiveCompositionCoach.advice(for: result.metrics, fallback: fallback,
                                                             currentZoomFactor: self.currentZoomFactor,
                                                             maximumZoomFactor: self.maximumZoomFactor)
                    self.trackedSubjectRect = advice.subjectRect
                    self.compositionTargetThird = advice.targetThird
                    self.isSubjectTracking = advice.isTracking
                    self.isFramingAligned = advice.isAligned
                    self.suggestedZoomFactor = advice.suggestedZoomFactor
                    let message = advice.message
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

    func current() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return value
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

struct LivePreviewFrame: @unchecked Sendable {
    let identifier: UInt64
    let pixelBuffer: CVPixelBuffer
    let orientation: CGImagePropertyOrientation
    let settings: LivePreviewSettings
}

final class LivePreviewMailbox: @unchecked Sendable {
    private let lock = NSLock()
    private var settings = LivePreviewSettings()
    private var frame: LivePreviewFrame?
    private var nextIdentifier: UInt64 = 0

    func update(settings: LivePreviewSettings) {
        lock.lock()
        self.settings = settings
        if !settings.requiresProcessedPreview { frame = nil }
        lock.unlock()
    }

    func submit(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        lock.lock()
        guard settings.requiresProcessedPreview else { lock.unlock(); return }
        nextIdentifier &+= 1
        frame = LivePreviewFrame(identifier: nextIdentifier, pixelBuffer: pixelBuffer,
                                 orientation: orientation, settings: settings)
        lock.unlock()
    }

    func clearFrame() {
        lock.lock()
        frame = nil
        lock.unlock()
    }

    func latestFrame() -> LivePreviewFrame? {
        lock.lock()
        defer { lock.unlock() }
        return frame
    }
}

final class AnalysisWorkGate: @unchecked Sendable {
    private let lock = NSLock()
    private var minimumInterval: TimeInterval
    private var lastStart: TimeInterval?
    private var isWorking = false

    init(minimumInterval: TimeInterval = 0.28) {
        self.minimumInterval = minimumInterval
    }

    func begin(at time: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isWorking, lastStart.map({ time - $0 >= minimumInterval }) ?? true else { return false }
        isWorking = true
        lastStart = time
        return true
    }

    func finish() {
        lock.lock()
        isWorking = false
        lock.unlock()
    }

    func finish(nextMinimumInterval: TimeInterval?) {
        lock.lock()
        isWorking = false
        if let nextMinimumInterval, nextMinimumInterval.isFinite, nextMinimumInterval > 0 {
            minimumInterval = nextMinimumInterval
        }
        lock.unlock()
    }
}

enum CameraFrameDeliveryPolicy {
    static func shouldDeliverFrames(sessionIsRunning: Bool,
                                    guidanceEnabled: Bool,
                                    previewRequiresProcessing: Bool) -> Bool {
        sessionIsRunning && (guidanceEnabled || previewRequiresProcessing)
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

enum CaptureSessionStartOutcome: Equatable {
    case started
    case failed

    static func resolve(isRunning: Bool) -> CaptureSessionStartOutcome {
        isRunning ? .started : .failed
    }
}

enum CaptureAvailability {
    static func canCapture(sessionIsRunning: Bool, isCapturing: Bool) -> Bool {
        sessionIsRunning && !isCapturing
    }
}

private final class VideoAnalysisDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    weak var analyzer: CompositionAnalyzer?
    var onResult: ((AnalysisResult, UInt64) -> Void)?
    weak var livePreviewMailbox: LivePreviewMailbox?
    private let generationGate = AnalysisGenerationGate()
    private let guidanceGeneration = SessionGeneration()
    private let analysisWorkGate = AnalysisWorkGate()
    private var previewSettings = LivePreviewSettings()
    private var guidanceEnabled = true
    private var analysisOrientation: CGImagePropertyOrientation = .right
    private var mostRecentPixelBuffer: CVPixelBuffer?

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let source = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let generation = generationGate.generationForFrame() else {
            mostRecentPixelBuffer = nil
            return
        }
        let orientation = analysisOrientation
        if previewSettings.requiresProcessedPreview {
            livePreviewMailbox?.submit(source, orientation: orientation)
        }
        guard guidanceEnabled else {
            mostRecentPixelBuffer = nil
            return
        }
        mostRecentPixelBuffer = source
        let guidanceToken = guidanceGeneration.current()
        guard analysisWorkGate.begin(at: MonotonicClock.now) else { return }
        guard let analyzer else { analysisWorkGate.finish(); return }
        analyzer.analyze(AnalysisPixelBuffer(value: source), orientation: orientation) { [weak self] result in
            guard let self else { return }
            let isTracking = result?.metrics.confidenceSource == .tracking
            self.analysisWorkGate.finish(nextMinimumInterval: isTracking ? (1.0 / 12.0) : 0.28)
            guard let result, self.generationGate.acceptsResult(for: generation),
                  self.guidanceGeneration.isCurrent(guidanceToken) else { return }
            self.onResult?(result, generation)
        }
    }

    func acceptsResult(for generation: UInt64) -> Bool {
        generationGate.acceptsResult(for: generation)
    }

    func pause(on queue: DispatchQueue) {
        generationGate.pause()
        queue.async { [weak self] in
            self?.mostRecentPixelBuffer = nil
            self?.analyzer?.clearSelection()
            self?.livePreviewMailbox?.clearFrame()
        }
    }

    func updateOrientation(_ orientation: CGImagePropertyOrientation, on queue: DispatchQueue) {
        queue.async { [weak self] in self?.analysisOrientation = orientation }
    }

    func updatePreviewSettings(_ settings: LivePreviewSettings, on queue: DispatchQueue) {
        queue.async { [weak self] in self?.previewSettings = settings }
    }

    func updateGuidanceEnabled(_ enabled: Bool, on queue: DispatchQueue) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.guidanceEnabled != enabled { _ = self.guidanceGeneration.advance() }
            self.guidanceEnabled = enabled
            if !enabled {
                self.mostRecentPixelBuffer = nil
                self.analyzer?.clearSelection()
            }
        }
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
            self.analysisWorkGate.finish(nextMinimumInterval: didSelect ? (1.0 / 12.0) : 0.28)
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
    let isVisible: Bool
    let onTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator,
                                                          action: #selector(Coordinator.handleTap(_:))))
        context.coordinator.previewView = view
        view.previewLayer.isHidden = !isVisible
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
        uiView.previewLayer.isHidden = !isVisible
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

private struct MetalLivePreview: UIViewRepresentable {
    let mailbox: LivePreviewMailbox
    let isActive: Bool

    func makeUIView(context: Context) -> MetalPreviewContainer {
        MetalPreviewContainer(mailbox: mailbox)
    }

    func updateUIView(_ uiView: MetalPreviewContainer, context: Context) {
        uiView.setActive(isActive)
    }
}

@MainActor
private final class MetalPreviewContainer: UIView {
    private var metalPreview: LiveMetalPreviewView?

    init(mailbox: LivePreviewMailbox) {
        super.init(frame: .zero)
        backgroundColor = .black
        isUserInteractionEnabled = false
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let preview = LiveMetalPreviewView(frame: .zero, device: device, mailbox: mailbox)
        preview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(preview)
        metalPreview = preview
    }

    func setActive(_ active: Bool) {
        metalPreview?.setActive(active)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MetalPreviewContainer is created in code.")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalPreview?.frame = bounds
    }
}

@MainActor
private final class LiveMetalPreviewView: MTKView, MTKViewDelegate {
    private let mailbox: LivePreviewMailbox
    private let imageContext: CIContext
    private let commandQueue: MTLCommandQueue?
    private var lastFrameIdentifier: UInt64 = 0

    init(frame: CGRect, device: MTLDevice, mailbox: LivePreviewMailbox) {
        self.mailbox = mailbox
        imageContext = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        commandQueue = device.makeCommandQueue()
        super.init(frame: frame, device: device)
        delegate = self
        isOpaque = true
        backgroundColor = .black
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        framebufferOnly = false
        preferredFramesPerSecond = 30
        isPaused = true
    }

    func setActive(_ active: Bool) {
        isPaused = !active
        if active { setNeedsDisplay() }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("LiveMetalPreviewView is created in code.")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale: CGFloat = 1.5
        let requested = CGSize(width: max(1, bounds.width * scale),
                               height: max(1, bounds.height * scale))
        if drawableSize != requested { drawableSize = requested }
    }

    func draw(in view: MTKView) {
        guard let frame = mailbox.latestFrame(), frame.identifier != lastFrameIdentifier,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        lastFrameIdentifier = frame.identifier

        var image = CIImage(cvPixelBuffer: frame.pixelBuffer)
            .oriented(forExifOrientation: Int32(frame.orientation.rawValue))
        image = FilmRenderer.centerCrop(image, aspect: frame.settings.cropAspect.ratio,
                                        position: frame.settings.cropPosition)
        image = LiveFilmLook.apply(frame.settings.preset, to: image)
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX,
                                                         y: -image.extent.minY))
        if frame.settings.isMirrored {
            let width = image.extent.width
            image = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
                .transformed(by: CGAffineTransform(translationX: width, y: 0))
        }

        let canvas = CGRect(x: 0, y: 0, width: drawable.texture.width, height: drawable.texture.height)
        let extent = image.extent
        let scaleX = canvas.width / extent.width
        let scaleY = canvas.height / extent.height
        let scale = frame.settings.cropAspect == .original
            ? max(scaleX, scaleY)
            : min(scaleX, scaleY)
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = image.extent
        image = image.transformed(by: CGAffineTransform(
            translationX: canvas.midX - scaledExtent.midX,
            y: canvas.midY - scaledExtent.midY
        ))
        let background = CIImage(color: .black).cropped(to: canvas)
        let composited = image.composited(over: background).cropped(to: canvas)
        imageContext.render(composited, to: drawable.texture, commandBuffer: commandBuffer,
                            bounds: canvas, colorSpace: CGColorSpaceCreateDeviceRGB())
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct LiveFrameTreatment: View {
    let layout: FrameLayout
    let dateStamp: Bool
    let date: Date

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    var body: some View {
        GeometryReader { geometry in
            let inset = min(geometry.size.width, geometry.size.height) * 0.035
            ZStack {
                if layout == .whiteBorder {
                    Rectangle()
                        .stroke(.white.opacity(0.95), lineWidth: 8)
                        .padding(inset)
                } else if layout == .paperPrint {
                    Rectangle()
                        .stroke(Color(red: 0.94, green: 0.90, blue: 0.81), lineWidth: 10)
                        .padding(inset)
                    if dateStamp {
                        HStack {
                            Spacer()
                            Text(formattedDate)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.16))
                        }
                        .padding(.horizontal, inset + 12)
                        .frame(height: 30)
                        .background(Color(red: 0.94, green: 0.90, blue: 0.81))
                        .padding(.horizontal, inset)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, inset)
                    }
                }

                if dateStamp && layout != .paperPrint {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(formattedDate)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(layout == .whiteBorder ? .black : .white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(layout == .whiteBorder ? Color.white : Color.black.opacity(0.45),
                                            in: Capsule())
                        }
                        .padding(.horizontal, inset + 10)
                        .padding(.bottom, inset + 8)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LiveCompositionOverlay: View {
    let subjectRect: CGRect?
    let targetThird: CGPoint?
    let isTracking: Bool
    let isAligned: Bool
    let isMirrored: Bool

    var body: some View {
        Canvas { context, size in
            var grid = Path()
            for fraction in [CGFloat(1.0 / 3.0), CGFloat(2.0 / 3.0)] {
                let x = size.width * fraction
                let y = size.height * fraction
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(.white.opacity(0.24)), lineWidth: 0.75)

            if let targetThird {
                let targetX = isMirrored ? 1 - targetThird.x : targetThird.x
                let point = CGPoint(x: targetX * size.width,
                                    y: (1 - targetThird.y) * size.height)
                var marker = Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
                marker.move(to: CGPoint(x: point.x - 10, y: point.y))
                marker.addLine(to: CGPoint(x: point.x + 10, y: point.y))
                marker.move(to: CGPoint(x: point.x, y: point.y - 10))
                marker.addLine(to: CGPoint(x: point.x, y: point.y + 10))
                context.stroke(marker, with: .color(.cyan.opacity(0.82)), lineWidth: 1.5)
            }

        }
        .overlay {
            if let subjectRect {
                let color: Color = isAligned ? .cyan : (isTracking ? .mint : .white)
                LiveSubjectBrackets(rect: subjectRect, isMirrored: isMirrored)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .animation(.linear(duration: 0.08), value: subjectRect)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LiveSubjectBrackets: Shape {
    var rect: CGRect
    let isMirrored: Bool

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(rect.minX, rect.minY), AnimatablePair(rect.width, rect.height)) }
        set {
            rect = CGRect(x: newValue.first.first, y: newValue.first.second,
                          width: newValue.second.first, height: newValue.second.second)
        }
    }

    func path(in bounds: CGRect) -> Path {
        let x = isMirrored ? 1 - rect.maxX : rect.minX
        let tracked = CGRect(x: bounds.minX + x * bounds.width,
                             y: bounds.minY + (1 - rect.maxY) * bounds.height,
                             width: rect.width * bounds.width,
                             height: rect.height * bounds.height)
        let corner = min(max(min(tracked.width, tracked.height) * 0.24, 9), 22)
        var path = Path()
        path.move(to: CGPoint(x: tracked.minX, y: tracked.minY + corner))
        path.addLine(to: CGPoint(x: tracked.minX, y: tracked.minY))
        path.addLine(to: CGPoint(x: tracked.minX + corner, y: tracked.minY))
        path.move(to: CGPoint(x: tracked.maxX - corner, y: tracked.minY))
        path.addLine(to: CGPoint(x: tracked.maxX, y: tracked.minY))
        path.addLine(to: CGPoint(x: tracked.maxX, y: tracked.minY + corner))
        path.move(to: CGPoint(x: tracked.minX, y: tracked.maxY - corner))
        path.addLine(to: CGPoint(x: tracked.minX, y: tracked.maxY))
        path.addLine(to: CGPoint(x: tracked.minX + corner, y: tracked.maxY))
        path.move(to: CGPoint(x: tracked.maxX - corner, y: tracked.maxY))
        path.addLine(to: CGPoint(x: tracked.maxX, y: tracked.maxY))
        path.addLine(to: CGPoint(x: tracked.maxX, y: tracked.maxY - corner))
        return path
    }
}
