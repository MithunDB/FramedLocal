import ExtensionKit
import LockedCameraCapture
import SwiftUI

@main
struct FramedLocalCaptureExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            FramedLocalCaptureView(session: session)
        }
    }
}
