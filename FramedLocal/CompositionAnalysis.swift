import CoreGraphics
import Foundation
import UIKit
import Vision

struct EdgeDistances: Sendable {
    let top: Double
    let right: Double
    let bottom: Double
    let left: Double

    var minimum: Double { min(top, right, bottom, left) }
}

struct CompositionMetrics: Sendable {
    var subjectRect: CGRect?
    var faceRects: [CGRect]
    var brightness: Double
    var clippedHighlightRatio: Double
    var clippedShadowRatio: Double
    var sharpness: Double
    var subjectEdgeDistance: EdgeDistances?
    var confidence: Double
    var confidenceSource: SubjectConfidenceSource = .detection
    var horizonAngle: Double? = nil
}

enum SubjectConfidenceSource: Equatable, Sendable {
    case detection
    case tracking
}

public struct GuidanceEngine {
    public private(set) var current = "Searching for a subject"
    private var candidate: String?
    private var candidateStart = 0.0
    private var lastChange = 0.0
    private var lowConfidenceSince: Double?

    public init() {}

    public mutating func update(message: String, time: Double, confidence: Double) -> String {
        update(message: message, time: time, confidence: confidence, source: .detection)
    }

    mutating func update(message: String, time: Double, confidence: Double,
                         source: SubjectConfidenceSource) -> String {
        let minimumConfidence = source == .tracking ? 0.5 : 0.3
        guard confidence >= minimumConfidence else {
            candidate = nil
            if lowConfidenceSince == nil { lowConfidenceSince = time }
            guard time - (lowConfidenceSince ?? time) >= 0.35 else { return current }
            let recoveryMessage = source == .tracking
                ? "Move slowly to keep the subject in frame"
                : "Move slowly so I can find the subject"
            if current != recoveryMessage {
                current = recoveryMessage
                lastChange = time
            }
            return current
        }
        lowConfidenceSince = nil
        guard message != current else { candidate = nil; return current }
        if candidate != message { candidate = message; candidateStart = time; return current }
        guard time - candidateStart >= 0.6, time - lastChange >= 1.4 else { return current }
        current = message
        lastChange = time
        candidate = nil
        return current
    }
}

struct AnalysisResult: Sendable {
    let metrics: CompositionMetrics
    let guidance: String
}

struct AnalysisRateLimiter {
    let minimumInterval: TimeInterval
    private(set) var lastAcceptedTime: TimeInterval?

    init(minimumInterval: TimeInterval, lastAcceptedTime: TimeInterval? = nil) {
        self.minimumInterval = minimumInterval
        self.lastAcceptedTime = lastAcceptedTime
    }

    mutating func shouldAnalyze(at time: TimeInterval) -> Bool {
        if let lastAcceptedTime, time - lastAcceptedTime < minimumInterval { return false }
        lastAcceptedTime = time
        return true
    }
}

enum ExposureGuidance {
    static func message(brightness: Double, clippedHighlightRatio: Double,
                        clippedShadowRatio: Double) -> String? {
        if clippedHighlightRatio > 0.12 { return "Lower exposure slightly" }
        if clippedShadowRatio > 0.35 && brightness < 0.32 { return "Add a little light" }
        if brightness > 0.82 && clippedHighlightRatio > 0.06 { return "Lower exposure slightly" }
        return nil
    }
}

enum GuidanceHaptics {
    static func shouldTrigger(message: String, previousMessage: String?, enabled: Bool) -> Bool {
        enabled && message == "Hold steady" && previousMessage != message
    }
}

enum HorizonLeveling {
    /// Estimates rotation around the screen normal from gravity projected onto the screen.
    /// The gravity axis aligned with the phone's long edge changes in landscape.
    static func angle(gravityX: Double, gravityY: Double,
                      orientation: UIDeviceOrientation) -> Double? {
        let isLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
        let alongLongAxis = isLandscape ? gravityX : gravityY
        let acrossLongAxis = isLandscape ? gravityY : gravityX
        guard hypot(alongLongAxis, acrossLongAxis) >= 0.35 else { return nil }
        return atan2(acrossLongAxis, abs(alongLongAxis))
    }
}

struct HorizonGuidanceState {
    private(set) var tiltedSince: TimeInterval?
    let threshold: Double
    let stabilityDuration: TimeInterval

    init(threshold: Double = 0.12, stabilityDuration: TimeInterval = 0.45) {
        self.threshold = threshold
        self.stabilityDuration = stabilityDuration
    }

    mutating func shouldShowLevelHint(angle: Double?, at time: TimeInterval) -> Bool {
        guard let angle, abs(angle) >= threshold else {
            tiltedSince = nil
            return false
        }
        if tiltedSince == nil { tiltedSince = time }
        return time - (tiltedSince ?? time) >= stabilityDuration
    }
}

enum VisionTapPointMapper {
    /// Converts the capture-device point (normalized, top-left origin) to Vision's
    /// normalized, bottom-left coordinate space after the requested image orientation.
    static func visionPoint(fromCaptureDevicePoint point: CGPoint,
                            orientation: CGImagePropertyOrientation) -> CGPoint {
        let x = min(max(point.x, 0), 1)
        let y = min(max(point.y, 0), 1)
        let oriented: CGPoint
        switch orientation {
        case .up: oriented = CGPoint(x: x, y: y)
        case .upMirrored: oriented = CGPoint(x: 1 - x, y: y)
        case .down: oriented = CGPoint(x: 1 - x, y: 1 - y)
        case .downMirrored: oriented = CGPoint(x: x, y: 1 - y)
        case .left: oriented = CGPoint(x: y, y: 1 - x)
        case .leftMirrored: oriented = CGPoint(x: y, y: x)
        case .right: oriented = CGPoint(x: 1 - y, y: x)
        case .rightMirrored: oriented = CGPoint(x: 1 - y, y: 1 - x)
        @unknown default: oriented = CGPoint(x: x, y: y)
        }
        return CGPoint(x: oriented.x, y: 1 - oriented.y)
    }
}

enum SubjectSelectionResolver {
    static let maximumFallbackDistance: CGFloat = 0.12

    static func resolve(point: CGPoint, candidates: [CGRect]) -> CGRect? {
        if let containing = candidates.first(where: { $0.contains(point) }) { return containing }
        guard let nearest = candidates.min(by: { distance($0, point) < distance($1, point) }),
              distance(nearest, point) <= maximumFallbackDistance * maximumFallbackDistance else {
            return nil
        }
        return nearest
    }
}

enum SubjectSelectionFeedback {
    static func message(didSelectSubject: Bool) -> String {
        didSelectSubject ? "Tracking selected subject" : "No subject found — try tapping closer"
    }
}

/// Runs Vision and pixel sampling on a worker queue. Only small observations cross to UI.
final class CompositionAnalyzer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.mithundb.framed.vision", qos: .userInitiated)
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let sequence = VNSequenceRequestHandler()
    private var rateLimiter = AnalysisRateLimiter(minimumInterval: 0.14)
    private var selectedObservation: VNDetectedObjectObservation?
    private var trackingRequest: VNTrackObjectRequest?
    private var guidanceEngine = GuidanceEngine()

    init() {
        queue.setSpecific(key: queueKey, value: 1)
    }

    func analyze(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .right,
                 completion: @escaping @Sendable (AnalysisResult?) -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            analyzeOnQueue(pixelBuffer, orientation: orientation, completion: completion)
        } else {
            queue.sync { analyzeOnQueue(pixelBuffer, orientation: orientation, completion: completion) }
        }
    }

    private func analyzeOnQueue(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                                completion: @Sendable (AnalysisResult?) -> Void) {
            let now = CFAbsoluteTimeGetCurrent()
            guard rateLimiter.shouldAnalyze(at: now) else {
                completion(nil)
                return
            }

            do {
                let faces = VNDetectFaceRectanglesRequest()
                let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
                if let tracking = trackingRequest {
                    try sequence.perform([tracking], on: pixelBuffer, orientation: orientation)
                    if let observation = tracking.results?.first as? VNDetectedObjectObservation,
                       observation.confidence >= 0.35 {
                        selectedObservation = observation
                        tracking.inputObservation = observation
                    } else {
                        selectedObservation = nil
                        trackingRequest = nil
                    }
                }
                try sequence.perform([faces, saliency], on: pixelBuffer, orientation: orientation)

                let faceObservations = faces.results ?? []
                let faceRects = faceObservations.map(\.boundingBox)
                let saliencyRect = (saliency.results?.first as? VNSaliencyImageObservation)?.salientObjects?
                    .max(by: { $0.confidence < $1.confidence })?.boundingBox
                let subjectRect = selectedObservation?.boundingBox
                    ?? faceObservations.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })?.boundingBox
                    ?? saliencyRect
                let samples = Self.sampleLuminance(pixelBuffer)
                let edgeDistances = subjectRect.map(Self.edgeDistances)
                let confidence = self.selectedObservation.map { Double($0.confidence) }
                    ?? (faceObservations.isEmpty ? (saliencyRect == nil ? 0.12 : 0.58) : 0.82)
                let confidenceSource: SubjectConfidenceSource = self.selectedObservation == nil ? .detection : .tracking
                let metrics = CompositionMetrics(
                    subjectRect: subjectRect,
                    faceRects: faceRects,
                    brightness: samples.brightness,
                    clippedHighlightRatio: samples.highlights,
                    clippedShadowRatio: samples.shadows,
                    sharpness: Self.sharpness(pixelBuffer),
                    subjectEdgeDistance: edgeDistances,
                    confidence: confidence,
                    confidenceSource: confidenceSource
                )
                let guidance = guidanceEngine.update(message: suggestedGuidance(for: metrics),
                                                     time: now, confidence: metrics.confidence,
                                                     source: metrics.confidenceSource)
                completion(AnalysisResult(metrics: metrics, guidance: guidance))
            } catch {
                let guidance = guidanceEngine.update(message: "Searching for a subject",
                                                     time: now,
                                                     confidence: 0.12,
                                                     source: .detection)
                let metrics = CompositionMetrics(subjectRect: nil, faceRects: [], brightness: 0.5,
                    clippedHighlightRatio: 0, clippedShadowRatio: 0, sharpness: 0,
                    subjectEdgeDistance: nil, confidence: 0)
                completion(AnalysisResult(metrics: metrics, guidance: guidance))
            }
    }

    func selectSubject(at normalizedPoint: CGPoint, in pixelBuffer: CVPixelBuffer,
                       orientation: CGImagePropertyOrientation = .right) -> Bool {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return selectSubjectOnQueue(at: normalizedPoint, in: pixelBuffer, orientation: orientation)
        } else {
            return queue.sync { selectSubjectOnQueue(at: normalizedPoint, in: pixelBuffer, orientation: orientation) }
        }
    }

    private func selectSubjectOnQueue(at normalizedPoint: CGPoint, in pixelBuffer: CVPixelBuffer,
                                      orientation: CGImagePropertyOrientation) -> Bool {
        let request = VNDetectFaceRectanglesRequest()
        let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
        do {
            try sequence.perform([request, saliency], on: pixelBuffer, orientation: orientation)
            let faces = request.results ?? []
            let boxes = faces.map(\.boundingBox) + ((saliency.results?.first as? VNSaliencyImageObservation)?.salientObjects?.map(\.boundingBox) ?? [])
            guard let selected = SubjectSelectionResolver.resolve(point: normalizedPoint, candidates: boxes) else {
                selectedObservation = nil
                trackingRequest = nil
                return false
            }
            let observation = VNDetectedObjectObservation(boundingBox: selected)
            selectedObservation = observation
            let tracking = VNTrackObjectRequest(detectedObjectObservation: observation)
            tracking.trackingLevel = .accurate
            tracking.isLastFrame = false
            trackingRequest = tracking
            return true
        } catch {
            selectedObservation = nil
            trackingRequest = nil
            return false
        }
    }

    func clearSelection() {
        queue.async { [weak self] in
            self?.selectedObservation = nil
            self?.trackingRequest = nil
        }
    }

    func enqueue(_ operation: @escaping @Sendable () -> Void) {
        queue.async(execute: operation)
    }

    private func suggestedGuidance(for metrics: CompositionMetrics) -> String {
        let message: String
        if metrics.confidenceSource == .tracking && metrics.confidence < 0.5 {
            message = "Move slowly to keep the subject in frame"
        } else if metrics.confidence < 0.3 {
            message = "Move slowly so I can find the subject"
        } else if metrics.sharpness < 0.035 {
            message = "Hold steady"
        } else if let edges = metrics.subjectEdgeDistance, edges.minimum < 0.045 {
            message = edges.left == edges.minimum ? "Move slightly right"
                : edges.right == edges.minimum ? "Move slightly left"
                : edges.top == edges.minimum ? "Lower the subject in frame" : "Raise the subject in frame"
        } else if let subject = metrics.subjectRect, subject.width * subject.height < 0.09 {
            message = "Move a little closer"
        } else if let tilt = metrics.horizonAngle, abs(tilt) > 0.10 {
            message = "Level the phone"
        } else if let exposureMessage = ExposureGuidance.message(
            brightness: metrics.brightness,
            clippedHighlightRatio: metrics.clippedHighlightRatio,
            clippedShadowRatio: metrics.clippedShadowRatio
        ) {
            message = exposureMessage
        } else {
            message = "Suggested framing"
        }

        return message
    }

    static func edgeDistances(_ rect: CGRect) -> EdgeDistances {
        EdgeDistances(top: 1 - rect.maxY, right: 1 - rect.maxX, bottom: rect.minY, left: rect.minX)
    }

    private static func sampleLuminance(_ buffer: CVPixelBuffer) -> (brightness: Double, highlights: Double, shadows: Double) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return (0.5, 0, 0) }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var total = 0.0, highlights = 0, shadows = 0, count = 0
        for y in stride(from: 0, to: height, by: max(height / 32, 1)) {
            for x in stride(from: 0, to: width, by: max(width / 32, 1)) {
                let value = Double(bytes[y * rowBytes + x]) / 255
                total += value
                if value > 0.96 { highlights += 1 }
                if value < 0.04 { shadows += 1 }
                count += 1
            }
        }
        guard count > 0 else { return (0.5, 0, 0) }
        return (total / Double(count), Double(highlights) / Double(count), Double(shadows) / Double(count))
    }

    private static func sharpness(_ buffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return 0 }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0), height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let row = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var sum = 0.0, count = 0.0
        let xStep = max(width / 48, 1), yStep = max(height / 48, 1)
        for y in stride(from: yStep, to: height - yStep, by: yStep) {
            for x in stride(from: xStep, to: width - xStep, by: xStep) {
                let center = Double(bytes[y * row + x])
                let laplacian = Double(bytes[y * row + x - 1]) + Double(bytes[y * row + x + 1])
                    + Double(bytes[(y - 1) * row + x]) + Double(bytes[(y + 1) * row + x]) - 4 * center
                sum += laplacian * laplacian
                count += 1
            }
        }
        return count > 0 ? min((sum / count) / 2_000, 1) : 0
    }
}

private func distance(_ rect: CGRect, _ point: CGPoint) -> CGFloat {
    let dx = max(max(rect.minX - point.x, 0), point.x - rect.maxX)
    let dy = max(max(rect.minY - point.y, 0), point.y - rect.maxY)
    return dx * dx + dy * dy
}
