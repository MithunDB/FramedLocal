import Photos
import UIKit

actor PhotoLibraryService {
    static let shared = PhotoLibraryService()
    private let albumTitle = "Framed"

    enum SaveError: LocalizedError {
        case permissionDenied
        case imageEncodingFailed
        case photoWriteFailed(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "Allow Framed to add photos in Settings to save this capture."
            case .imageEncodingFailed:
                "The captured photo could not be prepared for Photos."
            case .photoWriteFailed(let reason):
                "Photos could not save this image: \(reason)"
            }
        }
    }

    func saveJPEG(_ data: Data) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let access: PHAuthorizationStatus
        if status == .notDetermined {
            access = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        } else {
            access = status
        }
        guard access == .authorized || access == .limited else {
            throw SaveError.permissionDenied
        }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Framed-Export-\(UUID().uuidString).jpg")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let album = try await fetchOrCreateAlbum()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let creation = PHAssetCreationRequest.forAsset()
                creation.addResource(with: .photo, fileURL: temporaryURL, options: nil)
                if let album {
                    let placeholder = creation.placeholderForCreatedAsset
                    let request = PHAssetCollectionChangeRequest(for: album)
                    if let placeholder {
                        request?.addAssets([placeholder] as NSArray)
                    }
                }
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: SaveError.photoWriteFailed(error?.localizedDescription ?? "Unknown error"))
                }
            }
        }
    }

    func jpegData(from image: UIImage, quality: CGFloat = 0.94) throws -> Data {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw SaveError.imageEncodingFailed
        }
        return data
    }

    private func fetchOrCreateAlbum() async throws -> PHAssetCollection? {
        if let existing = findAlbum() { return existing }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                _ = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumTitle)
            } completionHandler: { [weak self] success, _ in
                guard success else {
                    // Saving to Recents remains useful if album creation is unavailable.
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: self?.findAlbum())
            }
        }
    }

    nonisolated private func findAlbum() -> PHAssetCollection? {
        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var match: PHAssetCollection?
        result.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == self.albumTitle {
                match = collection
                stop.pointee = true
            }
        }
        return match
    }
}
