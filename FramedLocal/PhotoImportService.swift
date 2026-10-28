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

    static func loadImageData(from item: PhotosPickerItem) async throws -> Data {
        do {
            if let file = try await item.loadTransferable(type: ImportedImageFile.self) {
                defer { try? FileManager.default.removeItem(at: file.url) }
                return try await PhotoImportWorker.shared.editingCopy(from: file.url)
            }
        } catch {
            try Task.checkCancellation()
        }

        guard let type = item.supportedContentTypes.first, type.conforms(to: .image),
              let data = try await item.loadTransferable(type: Data.self) else {
            throw ImportError.noImageData
        }
        return try await PhotoImportWorker.shared.editingCopy(from: data)
    }

    static func editingCopy(from data: Data,
                            maximumPixelDimension: Int = FrameRenderer.maximumPixelDimension) throws -> Data {
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImportError.unsupportedImage
        }
        return try editingCopy(from: source, originalData: data, originalURL: nil,
                               maximumPixelDimension: maximumPixelDimension)
    }

    static func editingCopy(from url: URL,
                            maximumPixelDimension: Int = FrameRenderer.maximumPixelDimension) throws -> Data {
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImportError.unsupportedImage
        }
        return try editingCopy(from: source, originalData: nil, originalURL: url,
                               maximumPixelDimension: maximumPixelDimension)
    }

    private static func editingCopy(from source: CGImageSource, originalData: Data?, originalURL: URL?,
                                    maximumPixelDimension: Int) throws -> Data {
        try Task.checkCancellation()
        guard maximumPixelDimension > 0 else { throw ImportError.unsupportedImage }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0 else {
            throw ImportError.unsupportedImage
        }
        let effectiveLongEdge = max(width, height)
        if effectiveLongEdge <= Double(maximumPixelDimension), let originalData {
            return originalData
        }
        if effectiveLongEdge <= Double(maximumPixelDimension) {
            // A file-backed import can preserve original bytes too, without decoding the full image.
            // The caller owns and removes this temporary file after the copy is returned.
            guard let originalURL else { throw ImportError.unsupportedImage }
            return try Data(contentsOf: originalURL)
        }

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

/// Keeps synchronous ImageIO thumbnail decoding and JPEG encoding off the UI actor.
actor PhotoImportWorker {
    static let shared = PhotoImportWorker()

    func editingCopy(from data: Data,
                     maximumPixelDimension: Int = FrameRenderer.maximumPixelDimension) throws -> Data {
        try PhotoImportService.editingCopy(from: data, maximumPixelDimension: maximumPixelDimension)
    }

    func editingCopy(from url: URL,
                     maximumPixelDimension: Int = FrameRenderer.maximumPixelDimension) throws -> Data {
        try PhotoImportService.editingCopy(from: url, maximumPixelDimension: maximumPixelDimension)
    }
}

private struct ImportedImageFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("Framed-Import-\(UUID().uuidString).\(received.file.pathExtension)")
            do {
                try FileManager.default.copyItem(at: received.file, to: destination)
                try Task.checkCancellation()
                return ImportedImageFile(url: destination)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }
    }
}
