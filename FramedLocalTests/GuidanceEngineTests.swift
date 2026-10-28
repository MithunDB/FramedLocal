import XCTest
@testable import FramedLocal

final class GuidanceEngineTests: XCTestCase {
    func testGuidanceWaitsForStableConditionAndCooldown() {
        var engine = GuidanceEngine()
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.0, confidence: 0.8), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.5, confidence: 0.8), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.7, confidence: 0.8), "Hold steady")
    }

    func testLowConfidenceReplacesStaleGuidanceAfterBriefLoss() {
        var engine = GuidanceEngine()
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.0, confidence: 0.8), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.7, confidence: 0.8), "Hold steady")
        XCTAssertEqual(engine.update(message: "Move closer", time: 3.0, confidence: 0.1), "Hold steady")
        XCTAssertEqual(engine.update(message: "Move closer", time: 3.4, confidence: 0.1), "Move slowly so I can find the subject")
        XCTAssertEqual(engine.update(message: "Move closer", time: 3.7, confidence: 0.1), "Move slowly so I can find the subject")
    }

    func testInitialLowConfidenceWaitsBeforeShowingRecoveryGuidance() {
        var engine = GuidanceEngine()
        XCTAssertEqual(engine.update(message: "Move slowly so I can find the subject", time: 1.0, confidence: 0.1), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Move slowly so I can find the subject", time: 1.2, confidence: 0.1), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Move slowly so I can find the subject", time: 1.4, confidence: 0.1), "Move slowly so I can find the subject")
    }
}
