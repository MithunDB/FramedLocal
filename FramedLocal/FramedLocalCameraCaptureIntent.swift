import AppIntents

@available(iOS 18.0, *)
struct FramedLocalCameraCaptureIntent: CameraCaptureIntent {
    static let title: LocalizedStringResource = "Open FramedLocal Camera"
    static let description = IntentDescription("Capture a photo with FramedLocal.")

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
