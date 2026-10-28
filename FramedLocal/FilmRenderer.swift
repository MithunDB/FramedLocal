import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

public enum FilmPreset: String, CaseIterable, Identifiable, Sendable {
    case natural = "Natural"
    case warmPrint = "Warm Print"
    case softMono = "Soft Mono"
    case fadedColor = "Faded Color"
    case nightGrain = "Night Grain"

    public var id: String { rawValue }
}

/// Applies original color treatments locally. One context is reused for the app lifetime.
public actor FilmRenderer {
    public static let shared = FilmRenderer()
    private let context = CIContext(options: [.cacheIntermediates: true])

    public func render(_ data: Data, preset: FilmPreset) throws -> Data {
        guard let source = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw RenderError.invalidImage
        }
        let sourceLongEdge = max(source.extent.width, source.extent.height)
        let scale = min(1, CGFloat(FrameRenderer.maximumPixelDimension) / sourceLongEdge)
        let boundedSource = scale < 1
            ? source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .cropped(to: CGRect(x: source.extent.minX * scale,
                                    y: source.extent.minY * scale,
                                    width: source.extent.width * scale,
                                    height: source.extent.height * scale))
            : source
        let image = apply(preset, to: boundedSource)
        guard let jpeg = context.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else {
            throw RenderError.encodingFailed
        }
        return jpeg
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
        let noise = CIFilter.randomGenerator().outputImage?.cropped(to: image.extent)
        guard let noise else { return image }
        let monochrome = CIFilter.colorMonochrome()
        monochrome.inputImage = noise
        monochrome.color = CIColor(red: 0.5, green: 0.5, blue: 0.5)
        monochrome.intensity = 1
        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = monochrome.outputImage?.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(amount))
        ])
        blend.backgroundImage = image
        return blend.outputImage?.cropped(to: image.extent) ?? image
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
