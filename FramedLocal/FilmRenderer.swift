import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import CoreFoundation
import Foundation
import ImageIO

public enum FilmPreset: String, CaseIterable, Identifiable, Sendable {
    case natural = "Natural"
    case warmPrint = "Warm Print"
    case softMono = "Soft Mono"
    case fadedColor = "Faded Color"
    case nightGrain = "Night Grain"

    public var id: String { rawValue }
}

public enum CropAspect: String, CaseIterable, Identifiable, Sendable {
    case original = "Original"
    case square = "Square"
    case fourByThree = "4:3"
    case sixteenByNine = "16:9"

    public var id: String { rawValue }

    var ratio: CGFloat? {
        switch self {
        case .original: nil
        case .square: 1
        case .fourByThree: 4.0 / 3.0
        case .sixteenByNine: 16.0 / 9.0
        }
    }

    func movementAxis(for sourceAspect: CGFloat) -> CropMovementAxis? {
        guard let ratio, sourceAspect.isFinite, sourceAspect > 0 else { return nil }
        if sourceAspect > ratio + 0.000_1 { return .horizontal }
        if sourceAspect < ratio - 0.000_1 { return .vertical }
        return nil
    }
}

enum CropMovementAxis: Equatable, Sendable {
    case horizontal
    case vertical
}

struct LivePreviewSettings: Equatable, Sendable {
    var preset: FilmPreset = .natural
    var cropAspect: CropAspect = .original
    var cropPosition: CropPosition = .center
    var isMirrored = false

    var requiresProcessedPreview: Bool {
        preset != .natural || cropAspect != .original
    }
}

/// Small, GPU-rendered approximation used only for the live camera display.
/// Full-resolution, deterministic film rendering remains in `FilmRenderer` after capture.
enum LiveFilmLook {
    private static let grainTile = CIFilter.randomGenerator().outputImage?
        .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))

    static func apply(_ preset: FilmPreset, to source: CIImage) -> CIImage {
        guard preset != .natural else { return source }
        let controls = CIFilter.colorControls()
        controls.inputImage = source
        var image = source
        switch preset {
        case .natural:
            return source
        case .warmPrint:
            controls.saturation = 1.06
            controls.contrast = 1.06
            controls.brightness = 0.01
            image = controls.outputImage ?? image
            image = temperature(image, kelvin: 5_700, tint: 7)
            image = vignette(image, intensity: 0.18, radius: 1.5)
        case .softMono:
            controls.saturation = 0
            controls.contrast = 0.94
            controls.brightness = 0.025
            image = controls.outputImage ?? image
            image = vignette(image, intensity: 0.12, radius: 1.4)
        case .fadedColor:
            controls.saturation = 0.78
            controls.contrast = 0.88
            controls.brightness = 0.045
            image = controls.outputImage ?? image
            image = temperature(image, kelvin: 6_400, tint: 3)
        case .nightGrain:
            controls.saturation = 0.88
            controls.contrast = 1.12
            controls.brightness = -0.015
            image = controls.outputImage ?? image
            image = temperature(image, kelvin: 4_900, tint: -5)
            image = vignette(image, intensity: 0.32, radius: 1.1)
            image = tiledGrain(over: image, amount: 0.12)
        }
        return image.cropped(to: source.extent)
    }

    private static func temperature(_ image: CIImage, kelvin: Float, tint: Float) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: 6_500, y: 0)
        filter.targetNeutral = CIVector(x: CGFloat(kelvin), y: CGFloat(tint))
        return filter.outputImage ?? image
    }

    private static func vignette(_ image: CIImage, intensity: Float, radius: Float) -> CIImage {
        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = intensity
        filter.radius = Float(max(image.extent.width, image.extent.height)) * radius
        return filter.outputImage ?? image
    }

    private static func tiledGrain(over image: CIImage, amount: Float) -> CIImage {
        guard let grainTile else {
            return image
        }
        let tiled = grainTile.applyingFilter("CIAffineTile")
        let scaledNoise = tiled.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: CGFloat(amount), y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: CGFloat(amount), z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(amount), w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: CGFloat(0.5 - amount / 2),
                                         y: CGFloat(0.5 - amount / 2),
                                         z: CGFloat(0.5 - amount / 2), w: 0)
        ])
        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = scaledNoise
        blend.backgroundImage = image
        return blend.outputImage?.cropped(to: image.extent) ?? image
    }
}

public struct CropPosition: Equatable, Sendable {
    public var horizontal: Double
    public var vertical: Double

    public init(horizontal: Double = 0, vertical: Double = 0) {
        self.horizontal = min(max(horizontal, -1), 1)
        self.vertical = min(max(vertical, -1), 1)
    }

    public static let center = CropPosition()
}

enum CropGeometry {
    static func sourceAspectRatio(from data: Data) -> CGFloat? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0 else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let swapsAxes = (5...8).contains(orientation)
        return swapsAxes ? CGFloat(height / width) : CGFloat(width / height)
    }

    static func cropRect(in extent: CGRect, aspect: CGFloat?, position: CropPosition = .center) -> CGRect {
        guard let aspect, aspect.isFinite, aspect > 0, extent.width > 0, extent.height > 0 else { return extent }
        let sourceAspect = extent.width / extent.height
        let width: CGFloat
        let height: CGFloat
        if sourceAspect > aspect {
            height = extent.height
            width = height * aspect
        } else {
            width = extent.width
            height = width / aspect
        }
        let maxXOffset = (extent.width - width) / 2
        let maxYOffset = (extent.height - height) / 2
        let x = extent.midX - width / 2 + CGFloat(position.horizontal) * maxXOffset
        let y = extent.midY - height / 2 + CGFloat(position.vertical) * maxYOffset
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// Applies original color treatments locally. One context is reused for the app lifetime.
public actor FilmRenderer {
    public static let shared = FilmRenderer()
    private let context = CIContext(options: [.cacheIntermediates: true])

    public func render(_ data: Data, preset: FilmPreset, cropAspect: CropAspect = .original,
                       cropPosition: CropPosition = .center,
                       digitalFraming: DigitalFraming = .identity,
                       autoEnhance: Bool = false) throws -> Data {
        try Task.checkCancellation()
        guard let source = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw RenderError.invalidImage
        }
        try Task.checkCancellation()
        let ratioCroppedSource = Self.centerCrop(source, aspect: cropAspect.ratio, position: cropPosition)
        let croppedSource = Self.apply(digitalFraming, to: ratioCroppedSource)
        let sourceLongEdge = max(croppedSource.extent.width, croppedSource.extent.height)
        let scale = min(1, CGFloat(FrameRenderer.maximumPixelDimension) / sourceLongEdge)
        let boundedSource = scale < 1
            ? croppedSource.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .cropped(to: CGRect(x: croppedSource.extent.minX * scale,
                                    y: croppedSource.extent.minY * scale,
                                    width: croppedSource.extent.width * scale,
                                    height: croppedSource.extent.height * scale))
            : croppedSource
        let balancedSource = autoEnhance ? Self.autoEnhance(boundedSource) : boundedSource
        let image = try apply(preset, to: balancedSource)
        try Task.checkCancellation()
        guard let jpeg = context.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else {
            throw RenderError.encodingFailed
        }
        try Task.checkCancellation()
        return jpeg
    }

    public func clearCaches() {
        context.clearCaches()
    }

    static func centerCrop(_ image: CIImage, aspect: CGFloat?, position: CropPosition) -> CIImage {
        guard let aspect, image.extent.width > 0, image.extent.height > 0 else { return image }
        let crop = CropGeometry.cropRect(in: image.extent, aspect: aspect, position: position)
        let centered = image.cropped(to: crop)
        return centered.transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
    }

    static func apply(_ framing: DigitalFraming, to image: CIImage) -> CIImage {
        let extent = image.extent
        let scale = min(max(framing.scale, 1), 2.4)
        guard scale > 1.001, extent.width > 0, extent.height > 0 else { return image }
        let cropWidth = extent.width / scale
        let cropHeight = extent.height / scale
        // CIImage uses a bottom-left origin; DigitalFraming is expressed in view coordinates.
        let centerX = extent.minX + framing.center.x * extent.width
        let centerY = extent.minY + (1 - framing.center.y) * extent.height
        let originX = min(max(centerX - cropWidth / 2, extent.minX), extent.maxX - cropWidth)
        let originY = min(max(centerY - cropHeight / 2, extent.minY), extent.maxY - cropHeight)
        let crop = CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)
        return image.cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
    }

    /// Applies Apple's image-content-aware corrections to the new rendered copy.
    /// The captured/imported source data remains untouched; the option is deliberately
    /// off by default at this renderer boundary so callers choose when to apply it.
    static func autoEnhance(_ source: CIImage) -> CIImage {
        let filters = source.autoAdjustmentFilters(options: [.enhance: true, .redEye: false])
        return filters.reduce(source) { image, filter in
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage?.cropped(to: source.extent) ?? image
        }
    }

    private func apply(_ preset: FilmPreset, to source: CIImage) throws -> CIImage {
        guard preset != .natural else { return source }

        var image = source
        let color = CIFilter.colorControls()
        color.inputImage = image

        switch preset {
        case .natural:
            return source
        case .warmPrint:
            color.saturation = 1.06
            color.contrast = 1.06
            color.brightness = 0.01
            image = color.outputImage ?? image
            image = temperature(image, kelvin: 5_700, tint: 7)
            image = vignette(image, intensity: 0.18, radius: 1.5)
        case .softMono:
            color.saturation = 0
            color.contrast = 0.94
            color.brightness = 0.025
            image = color.outputImage ?? image
            image = vignette(image, intensity: 0.12, radius: 1.4)
        case .fadedColor:
            color.saturation = 0.78
            color.contrast = 0.88
            color.brightness = 0.045
            image = color.outputImage ?? image
            image = temperature(image, kelvin: 6_400, tint: 3)
        case .nightGrain:
            color.saturation = 0.88
            color.contrast = 1.12
            color.brightness = -0.015
            image = color.outputImage ?? image
            image = temperature(image, kelvin: 4_900, tint: -5)
            image = vignette(image, intensity: 0.32, radius: 1.1)
            image = try grain(image, amount: 0.12)
        }
        return image.cropped(to: source.extent)
    }

    private func temperature(_ image: CIImage, kelvin: Float, tint: Float) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: 6_500, y: 0)
        filter.targetNeutral = CIVector(x: CGFloat(kelvin), y: CGFloat(tint))
        return filter.outputImage ?? image
    }

    private func vignette(_ image: CIImage, intensity: Float, radius: Float) -> CIImage {
        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = intensity
        filter.radius = Float(max(image.extent.width, image.extent.height)) * radius
        return filter.outputImage ?? image
    }

    private func grain(_ image: CIImage, amount: Float) throws -> CIImage {
        let noise = try Self.seededNoise(extent: image.extent, seed: 0x4652414D)
        let blend = CIFilter.softLightBlendMode()
        let scaledNoise = noise.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: CGFloat(amount), y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: CGFloat(amount), z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(amount), w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: CGFloat(0.5 - amount / 2),
                                         y: CGFloat(0.5 - amount / 2),
                                         z: CGFloat(0.5 - amount / 2), w: 0)
        ])
        blend.inputImage = scaledNoise
        blend.backgroundImage = image
        return blend.outputImage?.cropped(to: image.extent) ?? image
    }

    private static func seededNoise(extent: CGRect, seed: UInt32) throws -> CIImage {
        let dimensionLimit = CGFloat(FrameRenderer.maximumPixelDimension + 1)
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0,
              extent.width <= dimensionLimit, extent.height <= dimensionLimit else {
            throw RenderError.invalidImage
        }
        let width = Int(extent.width.rounded(.up))
        let height = Int(extent.height.rounded(.up))
        var state = seed
        let (pixelCount, pixelCountOverflow) = width.multipliedReportingOverflow(by: height)
        let (byteCount, byteCountOverflow) = pixelCount.multipliedReportingOverflow(by: 4)
        guard !pixelCountOverflow, !byteCountOverflow else { throw RenderError.invalidImage }
        var data = Data(count: byteCount)
        try data.withUnsafeMutableBytes { (rawBuffer: UnsafeMutableRawBufferPointer) throws -> Void in
            guard let pixels = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            for pixel in 0..<pixelCount {
                if pixel.isMultiple(of: 65_536) { try Task.checkCancellation() }
                state = 1_664_525 &* state &+ 1_013_904_223
                let value = UInt8(truncatingIfNeeded: state >> 24)
                let offset = pixel * 4
                pixels[offset] = value
                pixels[offset + 1] = value
                pixels[offset + 2] = value
                pixels[offset + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8,
                                    bitsPerPixel: 32, bytesPerRow: width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: false,
                                    intent: .defaultIntent) else {
            return CIImage(color: .gray).cropped(to: extent)
        }
        return CIImage(cgImage: cgImage)
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
            .cropped(to: extent)
    }

    enum RenderError: LocalizedError {
        case invalidImage, encodingFailed
        var errorDescription: String? {
            switch self {
            case .invalidImage: "The captured image could not be decoded."
            case .encodingFailed: "The rendered photo could not be encoded as JPEG."
            }
        }
    }
}
