import AVFoundation
import CoreGraphics
import Foundation

enum RearCameraLens: String, CaseIterable, Identifiable, Sendable {
    case ultraWide = "0.5×"
    case wide = "1×"

    var id: String { rawValue }

    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: .builtInUltraWideCamera
        case .wide: .builtInWideAngleCamera
        }
    }
}

enum CameraFlashSetting: String, CaseIterable, Identifiable, Sendable {
    case off = "Off"
    case automatic = "Auto"
    case on = "On"

    var id: String { rawValue }

    var captureMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: .off
        case .automatic: .auto
        case .on: .on
        }
    }
}

enum CaptureTimerSetting: Int, CaseIterable, Identifiable, Sendable {
    case off = 0
    case threeSeconds = 3
    case tenSeconds = 10

    var id: Int { rawValue }
    var title: String { rawValue == 0 ? "Off" : "\(rawValue)s" }
}

public struct DigitalFraming: Equatable, Sendable {
    /// Zoom applied to the captured image after the camera's optical/digital zoom.
    public var scale: CGFloat
    /// Normalized image-space center, with the origin at the top-left.
    public var center: CGPoint

    public static let identity = DigitalFraming(scale: 1, center: CGPoint(x: 0.5, y: 0.5))

    public init(scale: CGFloat = 1, center: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        let boundedScale = min(max(scale.isFinite ? scale : 1, 1), 2.4)
        let edge = 0.5 / boundedScale
        self.scale = boundedScale
        self.center = CGPoint(x: min(max(center.x.isFinite ? center.x : 0.5, edge), 1 - edge),
                              y: min(max(center.y.isFinite ? center.y : 0.5, edge), 1 - edge))
    }
}

enum CameraControlPolicy {
    static func clampedZoom(_ requested: Double, minimum: Double = 1, maximum: Double) -> Double {
        guard requested.isFinite, minimum.isFinite, maximum.isFinite else { return max(1, minimum) }
        return min(max(requested, minimum), max(minimum, maximum))
    }

    static func framing(for subject: CGRect?, isMirrored: Bool, enabled: Bool,
                        targetHeight: CGFloat = 0.38) -> DigitalFraming {
        guard enabled, let subject, subject.width > 0, subject.height > 0 else { return .identity }
        let scale = min(max(targetHeight / subject.height, 1.25), 2.4)
        let x = isMirrored ? 1 - subject.midX : subject.midX
        let y = 1 - subject.midY
        return DigitalFraming(scale: scale, center: CGPoint(x: x, y: y))
    }

    static func exposureBias(current: Double, brightness: Double, clippedHighlights: Double,
                             clippedShadows: Double, minimum: Double, maximum: Double) -> Double {
        guard [current, brightness, clippedHighlights, clippedShadows, minimum, maximum].allSatisfy(\.isFinite),
              minimum <= maximum else { return current }
        let target: Double
        if clippedHighlights > 0.08 { target = -0.6 }
        else if clippedShadows > 0.32 && brightness < 0.38 { target = 0.3 }
        else { target = 0 }
        return min(max(target, minimum), maximum)
    }
}
