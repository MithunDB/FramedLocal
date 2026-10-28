import XCTest
@testable import FramedLocal

final class GuidanceEngineTests: XCTestCase {
    func testGuidanceWaitsForStableConditionAndCooldown() {
        var engine = GuidanceEngine()
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.0, confidence: 0.8), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.5, confidence: 0.8), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.7, confidence: 0.8), "Hold steady")
    }

    func testLowConfidenceNeverChangesGuidance() {
        var engine = GuidanceEngine()
        XCTAssertEqual(engine.update(message: "Move closer", time: 3.0, confidence: 0.1), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Move closer", time: 5.0, confidence: 0.1), "Searching for a subject")
    }
}
