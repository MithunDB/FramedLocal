import Photos
import UIKit

actor PhotoLibraryService {
    static let shared = PhotoLibraryService()
    private let albumTitle = "Framed"
    private let albumIdentifierKey = "FramedLocal.albumIdentifier"
    private let albumCreationAttemptedKey = "FramedLocal.albumCreationAttempted"

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

    func saveJPEG(_ data: Data) async throws -> Bool {
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

        let savedInAlbumKey = "FramedLocal.savedInAlbum.\(UUID().uuidString)"
        UserDefaults.standard.set(false, forKey: savedInAlbumKey)
        let savedInAlbum = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let creation = PHAssetCreationRequest.forAsset()
                creation.addResource(with: .photo, fileURL: temporaryURL, options: nil)

                guard let assetPlaceholder = creation.placeholderForCreatedAsset else { return }
                let savedAlbumIdentifier = UserDefaults.standard.string(forKey: self.albumIdentifierKey)
                if let savedAlbumIdentifier,
                   let album = Self.fetchAlbum(identifier: savedAlbumIdentifier),
                   let request = PHAssetCollectionChangeRequest(for: album) {
                    request.addAssets([assetPlaceholder] as NSArray)
                    UserDefaults.standard.set(true, forKey: savedInAlbumKey)
                } else if !UserDefaults.standard.bool(forKey: self.albumCreationAttemptedKey) {
                    let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumTitle)
                    request.addAssets([assetPlaceholder] as NSArray)
                    UserDefaults.standard.set(request.placeholderForCreatedAssetCollection.localIdentifier,
                                              forKey: self.albumIdentifierKey)
                    UserDefaults.standard.set(true, forKey: self.albumCreationAttemptedKey)
                    UserDefaults.standard.set(true, forKey: savedInAlbumKey)
                } else {
                    // Add-only access may not allow fetching an existing collection. Save to Recents in that case.
                }
            } completionHandler: { success, error in
                if success {
                    let didSaveInAlbum = UserDefaults.standard.bool(forKey: savedInAlbumKey)
                    UserDefaults.standard.removeObject(forKey: savedInAlbumKey)
                    continuation.resume(returning: didSaveInAlbum)
                } else {
                    UserDefaults.standard.removeObject(forKey: savedInAlbumKey)
                    if UserDefaults.standard.bool(forKey: self.albumCreationAttemptedKey) {
                        UserDefaults.standard.removeObject(forKey: self.albumIdentifierKey)
                        UserDefaults.standard.set(false, forKey: self.albumCreationAttemptedKey)
                        self.saveAssetOnly(from: temporaryURL) { fallbackSuccess, fallbackError in
                            if fallbackSuccess {
                                continuation.resume(returning: false)
                            } else {
                                continuation.resume(throwing: SaveError.photoWriteFailed(
                                    fallbackError?.localizedDescription ?? error?.localizedDescription ?? "Unknown error"))
                            }
                        }
                    } else {
                        continuation.resume(throwing: SaveError.photoWriteFailed(error?.localizedDescription ?? "Unknown error"))
                    }
                }
            }
        }
        return savedInAlbum
    }

    func jpegData(from image: UIImage, quality: CGFloat = 0.94) throws -> Data {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw SaveError.imageEncodingFailed
        }
        return data
    }

    nonisolated private func saveAssetOnly(from url: URL, completion: @escaping @Sendable (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges {
            let creation = PHAssetCreationRequest.forAsset()
            creation.addResource(with: .photo, fileURL: url, options: nil)
        } completionHandler: { success, error in
            completion(success, error)
        }
    }

    nonisolated private static func fetchAlbum(identifier: String) -> PHAssetCollection? {
        PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [identifier], options: nil).firstObject
    }
}
