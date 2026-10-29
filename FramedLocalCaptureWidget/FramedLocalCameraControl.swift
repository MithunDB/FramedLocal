import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct FramedLocalCameraControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "local.mithundb.framed.lock-camera") {
            ControlWidgetButton(action: FramedLocalCameraCaptureIntent()) {
                Label("FramedLocal", systemImage: "camera.shutter.button.fill")
            }
        }
        .displayName("FramedLocal Camera")
        .description("Open the FramedLocal camera from your Lock Screen.")
    }
}

@main
struct FramedLocalControlsBundle: WidgetBundle {
    var body: some Widget {
        FramedLocalCameraControl()
    }
}
