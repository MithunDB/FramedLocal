import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

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
        if let data = try await item.loadTransferable(type: Data.self),
           let type = item.supportedContentTypes.first,
           type.conforms(to: .image) {
            return data
        }

        guard let file = try await item.loadTransferable(type: ImportedImageFile.self) else {
            throw ImportError.noImageData
        }
        defer { try? FileManager.default.removeItem(at: file.url) }
        guard let data = try? Data(contentsOf: file.url) else { throw ImportError.noImageData }
        return data
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
