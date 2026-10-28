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
                       cropPosition: CropPosition = .center) throws -> Data {
        guard let source = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw RenderError.invalidImage
        }
        let croppedSource = Self.centerCrop(source, aspect: cropAspect.ratio, position: cropPosition)
        let sourceLongEdge = max(croppedSource.extent.width, croppedSource.extent.height)
        let scale = min(1, CGFloat(FrameRenderer.maximumPixelDimension) / sourceLongEdge)
        let boundedSource = scale < 1
            ? croppedSource.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .cropped(to: CGRect(x: croppedSource.extent.minX * scale,
                                    y: croppedSource.extent.minY * scale,
                                    width: croppedSource.extent.width * scale,
                                    height: croppedSource.extent.height * scale))
            : croppedSource
        let image = apply(preset, to: boundedSource)
        guard let jpeg = context.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else {
            throw RenderError.encodingFailed
        }
        return jpeg
    }

    private static func centerCrop(_ image: CIImage, aspect: CGFloat?, position: CropPosition) -> CIImage {
        guard let aspect, image.extent.width > 0, image.extent.height > 0 else { return image }
        let crop = CropGeometry.cropRect(in: image.extent, aspect: aspect, position: position)
        let centered = image.cropped(to: crop)
        return centered.transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
    }

    private func apply(_ preset: FilmPreset, to source: CIImage) -> CIImage {
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
            image = grain(image, amount: 0.12)
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

    private func grain(_ image: CIImage, amount: Float) -> CIImage {
        let noise = Self.seededNoise(extent: image.extent, seed: 0x4652414D)
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

    private static func seededNoise(extent: CGRect, seed: UInt32) -> CIImage {
        let width = max(Int(extent.width.rounded(.up)), 1)
        let height = max(Int(extent.height.rounded(.up)), 1)
        var state = seed
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for pixel in 0..<(width * height) {
            state = 1_664_525 &* state &+ 1_013_904_223
            let value = UInt8(truncatingIfNeeded: state >> 24)
            let offset = pixel * 4
            pixels[offset] = value
            pixels[offset + 1] = value
            pixels[offset + 2] = value
            pixels[offset + 3] = 255
        }
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data),
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
