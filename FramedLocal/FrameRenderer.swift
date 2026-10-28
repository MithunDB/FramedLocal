import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

public enum FrameLayout: String, CaseIterable, Identifiable, Sendable {
    case fullBleed = "Full Bleed"
    case whiteBorder = "White Border"
    case paperPrint = "Paper Print"

    public var id: String { rawValue }
}

/// Flattens an image into a new JPEG canvas. Source image data is never modified.
public actor FrameRenderer {
    public static let shared = FrameRenderer()

    public func render(_ data: Data, layout: FrameLayout, dateStamp: Bool) throws -> Data {
        guard let source = UIImage(data: data), let cgImage = source.cgImage else {
            throw RenderError.invalidImage
        }

        let scale = CGFloat(max(cgImage.width, cgImage.height)) > 2_400
            ? 2_400 / CGFloat(max(cgImage.width, cgImage.height)) : 1
        let width = CGFloat(cgImage.width) * scale
        let height = CGFloat(cgImage.height) * scale
        let longSide = max(width, height)
        let border: CGFloat = switch layout {
        case .fullBleed: 0
        case .whiteBorder: longSide * 0.055
        case .paperPrint: longSide * 0.08
        }
        let bottomExtra: CGFloat = layout == .paperPrint ? longSide * 0.12 : (dateStamp ? longSide * 0.065 : 0)
        let canvasSize = CGSize(width: width + border * 2, height: height + border + bottomExtra)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: Int(canvasSize.width), height: Int(canvasSize.height),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw RenderError.contextCreationFailed
        }

        let background: UIColor = layout == .paperPrint
            ? UIColor(red: 0.91, green: 0.87, blue: 0.78, alpha: 1)
            : .white
        context.setFillColor(background.cgColor)
        context.fill(CGRect(origin: .zero, size: canvasSize))

        let imageRect = CGRect(x: border, y: bottomExtra, width: width, height: height)
        context.draw(cgImage, in: imageRect)

        if dateStamp {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy.MM.dd"
            let title = formatter.string(from: Date()) as CFString
            let font = CTFontCreateWithName("Menlo-Medium" as CFString, longSide * 0.026, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): UIColor(red: 0.27, green: 0.20, blue: 0.13, alpha: 0.88).cgColor
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: title as String, attributes: attributes))
            let textBounds = CTLineGetBoundsWithOptions(line, [])
            context.textPosition = CGPoint(x: canvasSize.width - border - textBounds.width,
                                           y: max(border * 0.45, (bottomExtra - textBounds.height) / 2))
            CTLineDraw(line, context)
        }

        guard let output = context.makeImage() else { throw RenderError.contextCreationFailed }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw RenderError.encodingFailed
        }
        CGImageDestinationAddImage(destination, output, [kCGImageDestinationLossyCompressionQuality: 0.94] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw RenderError.encodingFailed }
        return result as Data
    }

    enum RenderError: LocalizedError {
        case invalidImage, contextCreationFailed, encodingFailed
        var errorDescription: String? {
            switch self {
            case .invalidImage: "The image could not be opened for framing."
            case .contextCreationFailed: "A frame canvas could not be created."
            case .encodingFailed: "The framed image could not be saved as JPEG."
            }
        }
    }
}
