import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

enum PhotoImportService {
    enum ImportError: LocalizedError {
        case noImageData
        case unsupportedImage

        var errorDescription: String? {
            switch self {
            case .noImageData: "The selected photo could not be loaded."
            case .unsupportedImage: "The selected file is not a supported image."
            }
        }
    }

    static func loadJPEG(from item: PhotosPickerItem) async throws -> Data {
        let sourceData: Data
        if let data = try await item.loadTransferable(type: Data.self),
           let type = item.supportedContentTypes.first,
           type.conforms(to: .image) {
            sourceData = data
        } else {
            guard let file = try await item.loadTransferable(type: ImportedImageFile.self) else {
                throw ImportError.noImageData
            }
            defer { try? FileManager.default.removeItem(at: file.url) }
            guard let data = try? Data(contentsOf: file.url) else { throw ImportError.noImageData }
            sourceData = data
        }
        return try editingCopy(from: sourceData)
    }

    static func editingCopy(from data: Data,
                            maximumPixelDimension: Int = FrameRenderer.maximumPixelDimension) throws -> Data {
        try Task.checkCancellation()
        guard maximumPixelDimension > 0 else { throw ImportError.unsupportedImage }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0 else {
            throw ImportError.unsupportedImage
        }
        let effectiveLongEdge = max(width, height)
        guard effectiveLongEdge > Double(maximumPixelDimension) else { return data }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImportError.unsupportedImage
        }
        try Task.checkCancellation()

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImportError.unsupportedImage
        }
        CGImageDestinationAddImage(destination, thumbnail, [
            kCGImageDestinationLossyCompressionQuality: 0.94
        ] as CFDictionary)
        try Task.checkCancellation()
        guard CGImageDestinationFinalize(destination) else { throw ImportError.unsupportedImage }
        return output as Data
    }
}

private struct ImportedImageFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("Framed-Import-\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ImportedImageFile(url: destination)
        }
    }
}
