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
import AVKit
import LockedCameraCapture

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
    @State private var selectedFrame: FrameLayout = .fullBleed
    @State private var includesDateStamp = false
    @State private var autoEnhancePhotos = true
    @State private var showsCompositionGuides = true
    @State private var selectedEditorTool: EditorTool = .look
    @State private var showsCameraTools = false
    @State private var showsPhotoPicker = false
    @State private var editorStampDate = Date()
    @State private var previewImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importTask: Task<Void, Never>?
    @State private var importTaskID = UUID()
    @State private var isRendering = false
    @State private var renderTask: Task<Void, Never>?
    @State private var pinchStartZoom: Double?
    @State private var dragStartFrameCenter: CGPoint?
    @State private var showsZoomWheel = false
    @State private var cameraChromeSize: CGSize = .zero
    @State private var lastZoomWheelSnap: Double?

    var body: some View {
        ZStack {
            cameraBackground
            reviewImageLayer
            liveGuidanceOverlay
            cameraChrome
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsCameraTools) { cameraToolsSheet }
        .photosPicker(isPresented: $showsPhotoPicker, selection: $photoPickerItem,
                      matching: .images, photoLibrary: .shared())
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            handleMemoryWarning()
        }
        .task {
            camera.updateLivePreviewSettings(currentLivePreviewSettings)
            camera.setCompositionGuidanceEnabled(showsCompositionGuides)
            await camera.requestPermissionAndStart()
            await camera.startIfAuthorized()
        }
        .onChange(of: camera.latestCapture) { _, data in handleLatestCaptureChange(data) }
        .onChange(of: camera.importedImage) { _, data in handleImportedImageChange(data) }
        .onChange(of: photoPickerItem) { _, item in if let item { importPhoto(item) } }
        .onChange(of: selectedPreset) { _, _ in handlePreviewSettingsChange(render: true) }
        .onChange(of: selectedCropAspect) { _, _ in
            cropPosition = .center
            handlePreviewSettingsChange(render: true)
        }
        .onChange(of: cropPosition) { _, _ in handlePreviewSettingsChange(render: false) }
        .onChange(of: camera.isFrontCamera) { _, _ in handlePreviewSettingsChange(render: false) }
        .onChange(of: camera.isFrontCamera) { _, _ in showsZoomWheel = false }
        .onChange(of: showsCompositionGuides) { _, isEnabled in camera.setCompositionGuidanceEnabled(isEnabled) }
        .onChange(of: selectedFrame) { _, _ in renderCurrentSource() }
        .onChange(of: includesDateStamp) { _, _ in renderCurrentSource() }
        .onChange(of: autoEnhancePhotos) { _, _ in renderCurrentSource() }
        .onChange(of: scenePhase) { _, phase in handleScenePhaseChange(phase) }
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
        .onContinueUserActivity(lockedCaptureActivityType) { _ in
            Task { await importLatestLockScreenCapture() }
        }
    }

    private var lockedCaptureActivityType: String {
        if #available(iOS 18.0, *) { return NSUserActivityTypeLockedCameraCapture }
        return "local.mithundb.framed.lock-camera"
    }

    private func importLatestLockScreenCapture() async {
        guard #available(iOS 18.0, *) else { return }
        let manager = LockedCameraCaptureManager.shared
        let fileManager = FileManager.default
        var candidates: [(file: URL, container: URL, modified: Date)] = []
        for container in manager.sessionContentURLs {
            let urls = (try? fileManager.contentsOfDirectory(at: container,
                                                             includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for url in urls where url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg" {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                candidates.append((url, container, modified))
            }
        }
        guard let newest = candidates.max(by: { $0.modified < $1.modified }) else { return }
        do {
            let data = try await PhotoImportWorker.shared.editingCopy(from: newest.file)
            try? await manager.invalidateSessionContent(at: newest.container)
            camera.stop()
            camera.discardCapture()
            previewImage = nil
            editorStampDate = Date()
            camera.captureMessage = "Lock Screen capture · edit a new copy"
            camera.importedImage = data
        } catch {
            camera.captureMessage = "Couldn’t open Lock Screen capture: \(error.localizedDescription)"
        }
    }

    private var cameraBackground: some View {
        Group {
            if camera.authorization == .authorized && camera.latestCapture == nil && camera.importedImage == nil {
                cameraPreviewContent
            } else if camera.latestCapture != nil || camera.importedImage != nil {
                Color.black.ignoresSafeArea()
            } else {
                permissionContent
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var cameraToolsSheet: some View {
        CameraToolsSheet {
            VStack(spacing: 12) {
                cameraAdjustmentControls
                Divider().overlay(.white.opacity(0.12))
                editorControls
            }
        }
            .presentationDetents([.height(330), .medium])
            .presentationDragIndicator(.visible)
    }

    private var cameraAdjustmentControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 18) {
                Menu {
                    ForEach(CameraFlashSetting.allCases) { setting in
                        Button(setting.rawValue, systemImage: camera.flashSetting == setting ? "checkmark" : "") {
                            camera.setFlashSetting(setting)
                        }
                    }
                } label: {
                    Label("Flash · \(camera.flashSetting.rawValue)", systemImage: "bolt.fill")
                        .font(.caption.weight(.medium))
                }
                .disabled(camera.isFrontCamera)

                Menu {
                    ForEach(CaptureTimerSetting.allCases) { setting in
                        Button(setting.title, systemImage: camera.timerSetting == setting ? "checkmark" : "") {
                            camera.setTimerSetting(setting)
                        }
                    }
                } label: {
                    Label("Timer · \(camera.timerSetting.title)", systemImage: "timer")
                        .font(.caption.weight(.medium))
                }
                Spacer(minLength: 0)
                Button(camera.isAutoFramingEnabled ? "Auto frame on" : "Resume auto frame",
                       systemImage: camera.isAutoFramingEnabled ? "viewfinder" : "viewfinder.circle") {
                    if camera.isAutoFramingEnabled {
                        camera.pauseAutomaticFraming()
                    } else {
                        camera.resumeAutomaticFraming()
                    }
                }
                .font(.caption.weight(.medium))
            }
            HStack(spacing: 9) {
                Text("EV").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.72))
                Slider(value: Binding(get: { camera.exposureBias },
                                      set: { camera.setManualExposureBias($0) }),
                       in: camera.exposureBiasRange)
                    .tint(.cyan)
                    .accessibilityLabel("Exposure compensation")
                Text(camera.exposureBias, format: .number.precision(.significantDigits(2)))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 34, alignment: .trailing)
                Button(camera.isAutoExposureEnabled ? "Auto" : "Reset") {
                    camera.resumeAutomaticExposure()
                }
                .font(.caption2.weight(.semibold))
            }
            Toggle(isOn: $autoEnhancePhotos) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto improve photo")
                        .font(.caption.weight(.medium))
                    Text("Tone, contrast, and face-aware corrections after capture")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .tint(.cyan)
            Label("Autofocus · exposure · white balance", systemImage: "camera.aperture")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var reviewImageLayer: some View {
        if let previewImage {
            Image(uiImage: previewImage)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 28)
                .frame(maxHeight: .infinity)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var liveGuidanceOverlay: some View {
        if camera.authorization == .authorized && camera.latestCapture == nil && camera.importedImage == nil,
           showsCompositionGuides {
            VStack {
                Spacer()
                LiveGuidancePanel(message: camera.guidanceText,
                                  suggestedZoom: camera.isAutoFramingEnabled ? nil : camera.suggestedZoomFactor,
                                  onZoom: camera.applyZoomFactor)
                    .padding(.bottom, 165)
            }
        }
        if let countdown = camera.captureCountdown {
            Text("\(countdown)")
                .font(.system(size: 72, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.75), radius: 8)
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }

    private var cameraChrome: some View {
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
                    CameraLiveHeader(
                        canSwitchCamera: camera.authorization == .authorized && camera.isSessionRunning && !camera.isCapturing && !isImporting,
                        showsGuidance: showsCompositionGuides,
                        hapticsEnabled: camera.hapticsEnabled,
                        onSwitchCamera: camera.toggleCamera,
                        onToggleGuidance: { showsCompositionGuides.toggle() },
                        onToggleHaptics: { camera.setHapticsEnabled(!camera.hapticsEnabled) },
                        onChoosePhoto: { showsPhotoPicker = true }
                    )
                }

                Spacer()

                if !camera.isSaving, camera.latestCapture == nil, camera.importedImage == nil, !isImporting {
                    cameraLensZoomBar
                        .padding(.bottom, 14)
                }

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
                } else if camera.latestCapture != nil || camera.importedImage != nil {
                    editorControls
                        .padding(.bottom, 14)
                } else if !isImporting {
                    Button { showsCameraTools = true } label: {
                        Label("Looks & frame", systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.38), in: Capsule())
                    }
                    .padding(.bottom, 10)
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
                    ShutterButton(isAligned: camera.isFramingAligned,
                                  isEnabled: camera.authorization == .authorized && camera.isSessionRunning
                                    && !camera.isCapturing && !camera.isSaving
                                    && camera.latestCapture == nil && camera.importedImage == nil,
                                  action: camera.capture)
                    Spacer()
                }
                .padding(.bottom, 28)
                }
        }
        .overlay(alignment: .bottom) {
            if showsZoomWheel, camera.latestCapture == nil, camera.importedImage == nil {
                GeometryReader { geometry in
                    ZStack {
                        Color.clear.allowsHitTesting(false)
                        if showsZoomWheel, camera.latestCapture == nil, camera.importedImage == nil {
                            RadialZoomWheel(value: overallZoomFactor, range: overallZoomRange,
                                onChange: applyZoomWheelValue, onDismiss: dismissZoomWheel)
                                .frame(width: geometry.size.width - 24, height: 205)
                                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.69)
                                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                        }
                    }
                    .onAppear { cameraChromeSize = geometry.size }
                    .onChange(of: geometry.size) { _, size in cameraChromeSize = size }
                }
                .zIndex(5)
                .accessibilityAddTraits(.isModal)
            }
        }
        .coordinateSpace(name: "cameraChrome")
    }

    private var cameraLensZoomBar: some View {
        HStack(spacing: 12) {
            if !camera.isFrontCamera {
                zoomChoice("0.5×", selected: camera.selectedRearLens == .ultraWide
                           && abs(camera.currentZoomFactor - 1) < 0.04) {
                    camera.selectRearLens(.ultraWide)
                }
            }
            zoomChoice("1×", selected: (camera.isFrontCamera || camera.selectedRearLens == .wide)
                       && abs(camera.currentZoomFactor - 1) < 0.04) {
                camera.selectRearLens(camera.isFrontCamera ? nil : .wide, zoom: 1)
            }
            zoomChoice("2×", selected: (camera.isFrontCamera || camera.selectedRearLens == .wide)
                       && abs(camera.currentZoomFactor - 2) < 0.04) {
                camera.selectRearLens(camera.isFrontCamera ? nil : .wide, zoom: 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.black.opacity(0.42), in: Capsule())
    }

    private var overallZoomFactor: Double {
        guard !camera.isFrontCamera, camera.selectedRearLens == .ultraWide else {
            return camera.currentZoomFactor
        }
        return camera.currentZoomFactor * 0.5
    }

    private var overallZoomRange: ClosedRange<Double> {
        camera.isFrontCamera
            ? 1...max(1, camera.maximumZoomFactor)
            : 0.5...max(1, camera.maximumRearWideZoomFactor)
    }

    private func applyOverallZoom(_ value: Double) {
        guard !camera.isFrontCamera else {
            camera.applyZoomFactor(value)
            return
        }
        if value < 1, camera.selectedRearLens != .ultraWide {
            camera.selectRearLens(.ultraWide, zoom: value * 2)
        } else if value >= 1, camera.selectedRearLens != .wide {
            camera.selectRearLens(.wide, zoom: value)
        } else {
            camera.applyZoomFactor(camera.selectedRearLens == .ultraWide ? value * 2 : value)
        }
    }

    private func applyZoomWheelDrag(at point: CGPoint) {
        let size = cameraChromeSize
        guard size.width > 24, size.height > 205 else { return }
        let wheelWidth = size.width - 24
        let local = CGPoint(x: point.x - 12,
                            y: point.y - (size.height * 0.69 - 102.5))
        guard local.x >= 0, local.x <= wheelWidth, local.y >= 0, local.y <= 205 else { return }
        var angle = atan2(Double(local.y - 207), Double(local.x - wheelWidth / 2))
        if angle < 0 { angle += 2 * .pi }
        angle = min(max(angle, .pi), 2 * .pi)
        let progress = (angle - .pi) / .pi
        let range = overallZoomRange
        let low = log2(range.lowerBound)
        let high = log2(max(range.upperBound, range.lowerBound + 0.001))
        applyZoomWheelValue(pow(2, low + progress * (high - low)))
    }

    private func applyZoomWheelValue(_ requested: Double) {
        let snapped = CameraControlPolicy.snappedZoom(requested, range: overallZoomRange)
        if snapped != lastZoomWheelSnap {
            if snapped != nil { UISelectionFeedbackGenerator().selectionChanged() }
            lastZoomWheelSnap = snapped
        }
        applyOverallZoom(snapped ?? requested)
    }

    private func dismissZoomWheel() {
        withAnimation(.easeOut(duration: 0.16)) { showsZoomWheel = false }
        lastZoomWheelSnap = nil
    }

    private func zoomChoice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(selected ? .black : .white)
            .frame(minWidth: 42, minHeight: 34)
            .background(selected ? Color.cyan : .clear, in: Circle())
            .contentShape(Circle())
            .gesture(
                LongPressGesture(minimumDuration: 0.15, maximumDistance: 32)
                    .sequenced(before: DragGesture(minimumDistance: 0,
                                                   coordinateSpace: .named("cameraChrome")))
                    .onChanged { sequence in
                        switch sequence {
                        case .second(true, let drag):
                            if !showsZoomWheel {
                                action()
                                camera.pauseAutomaticFraming()
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                    showsZoomWheel = true
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            if let drag,
                               hypot(drag.translation.width, drag.translation.height) > 9 {
                                applyZoomWheelDrag(at: drag.location)
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { sequence in
                        switch sequence {
                        case .first(false): action()
                        case .second(true, _): dismissZoomWheel()
                        default: break
                        }
                    }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Zoom \(title)")
            .accessibilityHint("Tap to set this zoom. Touch and hold to open the zoom wheel.")
            .accessibilityAction(.default, action)
    }

    private var livePinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if pinchStartZoom == nil { pinchStartZoom = camera.currentZoomFactor }
                guard let pinchStartZoom else { return }
                camera.applyZoomFactor(pinchStartZoom * value)
            }
            .onEnded { _ in pinchStartZoom = nil }
    }

    private func handleLatestCaptureChange(_ data: Data?) {
        if data != nil { showsZoomWheel = false }
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

    private func handleImportedImageChange(_ data: Data?) {
        guard let data else { return }
        camera.stop()
        editorStampDate = Date()
        cropPosition = .center
        renderTask?.cancel()
        renderTask = renderPreview(data)
    }

    private func handlePreviewSettingsChange(render: Bool) {
        camera.updateLivePreviewSettings(currentLivePreviewSettings)
        if render { renderCurrentSource() }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Task {
                await camera.requestPermissionAndStart()
                await camera.startIfAuthorized()
            }
        case .background:
            camera.stop()
        default:
            break
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
        GeometryReader { geometry in
            let framing = camera.digitalFraming
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
                                               isTracking: camera.isSubjectTracking,
                                               isAligned: camera.isFramingAligned,
                                               isMirrored: camera.isFrontCamera)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                    LiveFrameTreatment(layout: selectedFrame, dateStamp: includesDateStamp, date: editorStampDate)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                } else {
                    GeometryReader { previewGeometry in
                        let previewRect = fittedPreviewRect(in: previewGeometry.size,
                                                            aspect: selectedCropAspect.ratio ?? 1)
                        if showsCompositionGuides {
                            LiveCompositionOverlay(subjectRect: camera.trackedSubjectRect,
                                                   isTracking: camera.isSubjectTracking,
                                                   isAligned: camera.isFramingAligned,
                                                   isMirrored: camera.isFrontCamera)
                                .frame(width: previewRect.width, height: previewRect.height)
                                .position(x: previewRect.midX, y: previewRect.midY)
                                .allowsHitTesting(false)
                        }
                        LiveFrameTreatment(layout: selectedFrame, dateStamp: includesDateStamp, date: editorStampDate)
                            .frame(width: previewRect.width, height: previewRect.height)
                            .position(x: previewRect.midX, y: previewRect.midY)
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(framing.scale)
            .offset(x: (0.5 - framing.center.x) * geometry.size.width * framing.scale,
                    y: (0.5 - framing.center.y) * geometry.size.height * framing.scale)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .animation(.easeOut(duration: 0.28), value: framing)
            .simultaneousGesture(livePinchGesture)
            .simultaneousGesture(
                DragGesture(minimumDistance: 14)
                    .onChanged { value in
                        if dragStartFrameCenter == nil {
                            dragStartFrameCenter = camera.digitalFraming.center
                            camera.pauseAutomaticFraming()
                        }
                        if let dragStartFrameCenter {
                            camera.panManualFrame(translation: value.translation,
                                                  viewportSize: geometry.size,
                                                  startingCenter: dragStartFrameCenter)
                        }
                    }
                    .onEnded { _ in dragStartFrameCenter = nil }
            )
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
        let framing = camera.capturedDigitalFraming
        let autoEnhance = autoEnhancePhotos
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
                                                                  cropPosition: cropPosition,
                                                                  digitalFraming: sourceID == "capture" ? framing : .identity,
                                                                  autoEnhance: autoEnhance)
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

private struct CameraLiveHeader: View {
    let canSwitchCamera: Bool
    let showsGuidance: Bool
    let hapticsEnabled: Bool
    let onSwitchCamera: () -> Void
    let onToggleGuidance: () -> Void
    let onToggleHaptics: () -> Void
    let onChoosePhoto: () -> Void

    var body: some View {
        HStack {
            Text("FRAMED")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(3)
            Spacer()
            Button(action: onSwitchCamera) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Switch camera")
            .disabled(!canSwitchCamera)
            Menu {
                Button(showsGuidance ? "Hide guidance" : "Show guidance", systemImage: "viewfinder",
                       action: onToggleGuidance)
                Button(hapticsEnabled ? "Turn haptics off" : "Turn haptics on", systemImage: "hand.tap",
                       action: onToggleHaptics)
                Button("Choose photo to edit", systemImage: "photo.on.rectangle", action: onChoosePhoto)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Camera options")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }
}

private struct CameraToolsSheet<Controls: View>: View {
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Camera tools").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.font(.subheadline.weight(.semibold))
            }
            controls().padding(.bottom, 20)
        }
        .padding(.horizontal, 12)
        .padding(.top, 22)
        .background(Color(red: 0.055, green: 0.10, blue: 0.14))
        .preferredColorScheme(.dark)
    }
}

private struct ShutterButton: View {
    let isAligned: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .stroke(isAligned ? Color.cyan : Color.white.opacity(0.85), lineWidth: 3)
                .frame(width: 76, height: 76)
                .overlay { Circle().fill(.white).padding(7) }
        }
        .accessibilityLabel("Take photo")
        .accessibilityValue(isAligned ? "Composition guide aligned" : "Composition guide active")
        .disabled(!isEnabled)
    }
}

private struct LiveGuidancePanel: View {
    let message: String
    let suggestedZoom: Double?
    let onZoom: (Double) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.black.opacity(0.45), in: Capsule())
            if let zoom = suggestedZoom {
                Button { onZoom(zoom) } label: {
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
    private(set) var capturedDigitalFraming: DigitalFraming = .identity
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
    @MainActor @Published private(set) var isSubjectTracking = false
    @MainActor @Published private(set) var isFramingAligned = false
    @MainActor @Published private(set) var suggestedZoomFactor: Double?
    @MainActor @Published private(set) var currentZoomFactor = 1.0
    @MainActor @Published private(set) var maximumZoomFactor = 5.0
    @MainActor @Published private(set) var maximumRearWideZoomFactor = 5.0
    @MainActor @Published private(set) var selectedRearLens: RearCameraLens = .wide
    @MainActor @Published private(set) var flashSetting: CameraFlashSetting = .automatic
    @MainActor @Published private(set) var timerSetting: CaptureTimerSetting = .off
    @MainActor @Published private(set) var exposureBias = 0.0
    @MainActor @Published private(set) var exposureBiasRange: ClosedRange<Double> = -2...2
    @MainActor @Published private(set) var isAutoExposureEnabled = true
    @MainActor @Published private(set) var isAutoFramingEnabled = true
    @MainActor @Published private(set) var digitalFraming: DigitalFraming = .identity
    @MainActor @Published private(set) var captureCountdown: Int?
    @MainActor private var timerTask: Task<Void, Never>?
    @MainActor private var subjectRectSmoother = SubjectRectSmoother()
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
        analysisDelegate.updateGuidanceEnabled(enabled || isAutoFramingEnabled, on: analysisQueue)
        updateVideoFrameDeliveryPolicy()
        if enabled {
            guidanceText = "Searching for a subject"
            if isSessionRunning, shouldRunSession { startMotionUpdates() }
        } else if !isAutoFramingEnabled {
            stopMotionUpdates()
            clearSubjectSelection()
            subjectRectSmoother = SubjectRectSmoother()
            trackedSubjectRect = nil
            digitalFraming = .identity
            suggestedZoomFactor = nil
            isSubjectTracking = false
            isFramingAligned = false
            guidanceText = "Composition guides off"
        }
    }

    @MainActor
    func applyZoomFactor(_ factor: Double) {
        pauseAutomaticFraming()
        guard factor.isFinite else { return }
        let requestedFactor = max(1, factor)
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeInput?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                let appliedFactor = CameraControlPolicy.clampedZoom(
                    requestedFactor, maximum: Double(device.activeFormat.videoMaxZoomFactor))
                device.ramp(toVideoZoomFactor: CGFloat(appliedFactor), withRate: 6)
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
    func selectRearLens(_ lens: RearCameraLens?, zoom: Double = 1) {
        if let lens, !isFrontCamera, lens != selectedRearLens {
            selectedRearLens = lens
            pauseAutomaticFraming()
            if shouldRunSession { switchCameraInput(position: .back, rearLens: lens, startingZoom: zoom) }
        } else {
            applyZoomFactor(zoom)
        }
    }

    @MainActor
    func resumeAutomaticFraming() {
        isAutoFramingEnabled = true
        analysisDelegate.updateGuidanceEnabled(true, on: analysisQueue)
        updateVideoFrameDeliveryPolicy()
        updateDigitalFraming()
    }

    @MainActor
    func pauseAutomaticFraming() {
        isAutoFramingEnabled = false
        analysisDelegate.updateGuidanceEnabled(compositionGuidanceEnabled, on: analysisQueue)
        updateVideoFrameDeliveryPolicy()
    }

    @MainActor
    func panManualFrame(translation: CGSize, viewportSize: CGSize, startingCenter: CGPoint) {
        isAutoFramingEnabled = false
        let scale = max(digitalFraming.scale, 1)
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }
        digitalFraming = DigitalFraming(scale: scale, center: CGPoint(
            x: min(max(startingCenter.x - translation.width / viewportSize.width / scale, 0), 1),
            y: min(max(startingCenter.y - translation.height / viewportSize.height / scale, 0), 1)
        ))
    }

    @MainActor
    func setFlashSetting(_ setting: CameraFlashSetting) { flashSetting = setting }

    @MainActor
    func setTimerSetting(_ setting: CaptureTimerSetting) { timerSetting = setting }

    @MainActor
    func setManualExposureBias(_ bias: Double) {
        isAutoExposureEnabled = false
        configureExposureBias(bias)
    }

    @MainActor
    func resumeAutomaticExposure() {
        isAutoExposureEnabled = true
        configureExposureBias(0)
    }

    @MainActor
    private func configureExposureBias(_ bias: Double) {
        let clamped = min(max(bias, exposureBiasRange.lowerBound), exposureBiasRange.upperBound)
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeInput?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.setExposureTargetBias(Float(clamped))
                Task { @MainActor [weak self] in self?.exposureBias = clamped }
            } catch {
                Task { @MainActor [weak self] in self?.captureMessage = "Exposure adjustment is temporarily unavailable." }
            }
        }
    }

    @MainActor
    private func updateDigitalFraming() {
        digitalFraming = CameraControlPolicy.framing(for: trackedSubjectRect,
                                                    isMirrored: isFrontCamera,
                                                    enabled: isAutoFramingEnabled)
    }

    @MainActor
    private func adjustAutomaticExposure(metrics: CompositionMetrics) {
        guard isAutoExposureEnabled else { return }
        let target = CameraControlPolicy.exposureBias(current: exposureBias,
                                                      brightness: metrics.brightness,
                                                      clippedHighlights: metrics.clippedHighlightRatio,
                                                      clippedShadows: metrics.clippedShadowRatio,
                                                      minimum: exposureBiasRange.lowerBound,
                                                      maximum: exposureBiasRange.upperBound)
        guard abs(target - exposureBias) >= 0.2 else { return }
        configureExposureBias(target)
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
        subjectRectSmoother = SubjectRectSmoother()
        trackedSubjectRect = nil
        isSubjectTracking = false
        isFramingAligned = false
        suggestedZoomFactor = nil
        lastGuidanceHapticMessage = nil
    }

    @MainActor
    private func updateVideoFrameDeliveryPolicy() {
        let shouldDeliverFrames = CameraFrameDeliveryPolicy.shouldDeliverFrames(
            sessionIsRunning: shouldRunSession,
            guidanceEnabled: compositionGuidanceEnabled || isAutoFramingEnabled,
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
        let rearLens = selectedRearLens
        let angle = rotationAngle(for: deviceOrientation)

        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureSession(position: position, rearLens: rearLens,
                                          rotationAngle: angle, startingZoom: 1)
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
        timerTask?.cancel()
        timerTask = nil
        captureCountdown = nil
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
        pauseAutomaticFraming()
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        guard shouldRunSession else {
            isFrontCamera.toggle()
            captureMessage = "Start the camera before switching lenses."
            return
        }
        switchCameraInput(position: position, rearLens: selectedRearLens, startingZoom: 1)
    }

    @MainActor
    private func switchCameraInput(position: AVCaptureDevice.Position, rearLens: RearCameraLens,
                                   startingZoom: Double) {
        let angle = rotationAngle(for: deviceOrientation)
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
                try self.configureSession(position: position, rearLens: rearLens,
                                          rotationAngle: angle, startingZoom: startingZoom)
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
        let delay = timerSetting.rawValue
        guard delay > 0 else {
            performCapture()
            return
        }
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for remaining in stride(from: delay, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                self.captureCountdown = remaining
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            self.captureCountdown = nil
            self.timerTask = nil
            self.performCapture()
        }
    }

    @MainActor
    private func performCapture() {
        let angle = rotationAngle(for: deviceOrientation)
        let mirrored = isFrontCamera
        let framing = digitalFraming
        let flashSetting = flashSetting
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let delegate = PhotoCaptureDelegate()
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            settings.photoQualityPrioritization = .quality
            settings.isAutoRedEyeReductionEnabled = self.photoOutput.isAutoRedEyeReductionSupported
            if self.photoOutput.isContentAwareDistortionCorrectionSupported {
                settings.isAutoContentAwareDistortionCorrectionEnabled = true
            }
            if self.photoOutput.supportedFlashModes.contains(flashSetting.captureMode) {
                settings.flashMode = flashSetting.captureMode
            } else {
                settings.flashMode = .off
            }
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
                        self.capturedDigitalFraming = framing
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
        isAutoExposureEnabled = false
        focusAndExpose(at: point)
        guard compositionGuidanceEnabled else { return }
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
    private func focusAndExpose(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.activeInput?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                }
            } catch {
                Task { @MainActor [weak self] in self?.captureMessage = "Tap focus is temporarily unavailable." }
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

    nonisolated private func configureSession(position: AVCaptureDevice.Position, rearLens: RearCameraLens,
                                              rotationAngle angle: CGFloat, startingZoom: Double) throws {
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
                ? [rearLens.deviceType]
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
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            configurePreviewFrameRate(for: device)
            device.videoZoomFactor = CGFloat(CameraControlPolicy.clampedZoom(
                startingZoom, maximum: Double(device.activeFormat.videoMaxZoomFactor)))
            device.unlockForConfiguration()
            let maximumZoom = Double(device.activeFormat.videoMaxZoomFactor)
            let appliedStartingZoom = CameraControlPolicy.clampedZoom(startingZoom, maximum: maximumZoom)
            let minExposure = Double(device.minExposureTargetBias)
            let maxExposure = Double(device.maxExposureTargetBias)
            Task { @MainActor [weak self] in
                self?.currentZoomFactor = appliedStartingZoom
                self?.maximumZoomFactor = max(1, maximumZoom)
                if position == .back, rearLens == .wide {
                    self?.maximumRearWideZoomFactor = max(1, maximumZoom)
                }
                self?.exposureBiasRange = minExposure...maxExposure
                self?.exposureBias = Double(device.exposureTargetBias)
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
                    self.trackedSubjectRect = self.subjectRectSmoother.update(
                        advice.subjectRect, at: MonotonicClock.now)
                    self.updateDigitalFraming()
                    self.adjustAutomaticExposure(metrics: result.metrics)
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

    /// Selects a preview-friendly format that can reach 60 fps. On iOS 18+, let
    /// AVFoundation adapt cadence for exposure; older systems use a 30–60 fps range.
    nonisolated private func configurePreviewFrameRate(for device: AVCaptureDevice) {
        let candidates = device.formats.compactMap { format -> (AVCaptureDevice.Format, Int32, Int32)? in
            let ranges = format.videoSupportedFrameRateRanges.map {
                Double($0.minFrameRate)...Double($0.maxFrameRate)
            }
            guard LivePreviewFrameRatePolicy.supportsTargetFrameRate(ranges) else { return nil }
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard size.width <= 1920, size.height <= 1080 else { return nil }
            return (format, size.width, size.height)
        }
        guard let format = candidates.max(by: {
            Int64($0.1) * Int64($0.2) < Int64($1.1) * Int64($1.2)
        })?.0 else { return }

        device.activeFormat = format
        let ranges = format.videoSupportedFrameRateRanges.map {
            Double($0.minFrameRate)...Double($0.maxFrameRate)
        }
        guard let deliveryRange = LivePreviewFrameRatePolicy.fallbackFrameRateRange(for: ranges) else { return }
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(deliveryRange.upperBound))
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(deliveryRange.lowerBound))
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
        preferredFramesPerSecond = Int(LivePreviewFrameRatePolicy.targetFramesPerSecond)
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

private struct RadialZoomWheel: View {
    let value: Double
    let range: ClosedRange<Double>
    let onChange: (Double) -> Void
    let onDismiss: () -> Void

    private var tickZoomValues: [Double] {
        let lowerLog = log2(max(range.lowerBound, 0.001))
        let upperLog = log2(max(range.upperBound, range.lowerBound + 0.001))
        let count = max(1, Int(ceil((upperLog - lowerLog) * 12)))
        let regularTicks = (0...count).map { index in
            pow(2, lowerLog + (upperLog - lowerLog) * Double(index) / Double(count))
        }
        let keyStops = [0.5, 1.0, 2.0, 5.0].filter { range.contains($0) }
        return Array(Set((regularTicks + keyStops).filter { range.contains($0) })).sorted()
    }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height + 2)
            let radius = min(geometry.size.width * 0.49, geometry.size.height - 12)
            let lowerLog = log2(max(range.lowerBound, 0.001))
            let upperLog = log2(max(range.upperBound, range.lowerBound + 0.001))
            ZStack {
                ZoomWheelArcBand(center: center, radius: radius)
                    .fill(.black.opacity(0.76))
                    .overlay {
                        ZoomWheelArc(center: center, radius: radius)
                            .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1))
                    }
                ForEach(tickZoomValues, id: \.self) { tickValue in
                    let progress = upperLog > lowerLog
                        ? (log2(tickValue) - lowerLog) / (upperLog - lowerLog) : 0.5
                    let angle = Double.pi + Double.pi * progress
                    let major = [0.5, 1.0, 2.0, 5.0].contains { abs(log2(tickValue / $0)) < 0.000_1 }
                    Capsule()
                        .fill(major ? .white.opacity(0.86) : .white.opacity(0.38))
                        .frame(width: major ? 1.5 : 1, height: major ? 12 : 6)
                        .rotationEffect(.radians(angle - 1.5 * .pi))
                        .position(x: center.x + cos(angle) * (radius - 8),
                                  y: center.y + sin(angle) * (radius - 8))
                }
                ForEach([0.5, 1.0, 2.0, 5.0].filter { range.contains($0) }, id: \.self) { stop in
                    let progress = upperLog > lowerLog ? (log2(stop) - lowerLog) / (upperLog - lowerLog) : 0.5
                    let angle = .pi + .pi * progress
                    Text("\(stop, format: .number.precision(.fractionLength(stop < 1 ? 1 : 0)))×")
                        .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.84))
                        .position(x: center.x + cos(angle) * (radius - 33),
                                  y: center.y + sin(angle) * (radius - 33))
                }
                let progress = upperLog > lowerLog
                    ? min(max((log2(max(value, range.lowerBound)) - lowerLog) / (upperLog - lowerLog), 0), 1)
                    : 0.5
                let pointerAngle = .pi + .pi * progress
                Capsule()
                    .fill(Color.yellow)
                    .frame(width: 3, height: 23)
                    .rotationEffect(.radians(pointerAngle - 1.5 * .pi))
                    .position(x: center.x + cos(pointerAngle) * (radius - 8),
                              y: center.y + sin(pointerAngle) * (radius - 8))
                Text("\(value, format: .number.precision(.fractionLength(1)))×")
                    .font(.system(size: 19, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.yellow)
                    .position(x: geometry.size.width / 2, y: 82)
                Text("DRAG TO ADJUST")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.7))
                    .position(x: geometry.size.width / 2, y: 101)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        var angle = atan2(gesture.location.y - center.y, gesture.location.x - center.x)
                        if angle < 0 { angle += 2 * .pi }
                        angle = min(max(angle, .pi), 2 * .pi)
                        let nextProgress = (angle - .pi) / .pi
                        onChange(pow(2, lowerLog + nextProgress * (upperLog - lowerLog)))
                    }
                    .onEnded { _ in onDismiss() }
            )
            .accessibilityElement()
            .accessibilityLabel("Camera zoom wheel")
            .accessibilityValue("\(value.formatted(.number.precision(.fractionLength(1)))) times")
            .accessibilityHint("Drag around the arc to change camera zoom")
            .accessibilityAdjustableAction { direction in
                let step = pow(2, 1.0 / 12.0)
                switch direction {
                case .increment: onChange(min(value * step, range.upperBound))
                case .decrement: onChange(max(value / step, range.lowerBound))
                @unknown default: break
                }
            }
        }
        .frame(height: 205)
    }
}

private struct ZoomWheelArc: Shape {
    let center: CGPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for step in 0...64 {
            let angle = Double.pi + Double.pi * Double(step) / 64
            let point = CGPoint(x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

private struct ZoomWheelArcBand: Shape {
    let center: CGPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = ZoomWheelArc(center: center, radius: radius).path(in: rect)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct LiveCompositionOverlay: View {
    let subjectRect: CGRect?
    let isTracking: Bool
    let isAligned: Bool
    let isMirrored: Bool

    var body: some View {
        Group {
            if let subjectRect {
                let color: Color = isAligned ? .cyan : (isTracking ? .mint : .white)
                LiveSubjectBrackets(rect: subjectRect, isMirrored: isMirrored)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .shadow(color: .black.opacity(0.75), radius: 2)
                    .animation(.easeOut(duration: 0.12), value: subjectRect)
                    .transition(.opacity)
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
