import XCTest
@testable import CrochetStepAssistant

final class CrochetParserTests: XCTestCase {
    func testParsesRoundWithSegmentsAndTargetCount() {
        let componentId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let step = CrochetParser().parseStep(
            "R5: 3X, (5X,V) x 6, 2X (36)",
            componentId: componentId,
            stepIndex: 0
        )

        XCTAssertEqual(step.roundLabel, "R5")
        XCTAssertEqual(step.stitchCountTarget, 48)
        XCTAssertEqual(step.actionSegments.count, 3)
        XCTAssertEqual(step.actionSegments[0].sourceText, "3X")
        XCTAssertEqual(step.actionSegments[1].sourceText, "(5X,V) x 6")
        XCTAssertEqual(step.actionSegments[1].repeatCount, 6)
        XCTAssertEqual(step.actionSegments[2].sourceText, "2X")
    }

    func testCalculatesTargetCountWithoutExplicitTotal() {
        let componentId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let step = CrochetParser().parseStep(
            "R3: 8(X,W)",
            componentId: componentId,
            stepIndex: 0
        )

        XCTAssertEqual(step.stitchCountTarget, 24)
    }

    func testCalculatesTargetCountForMixedSegmentsWithoutExplicitTotal() {
        let componentId = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let step = CrochetParser().parseStep(
            "R4: 12X,8(X,V),12X",
            componentId: componentId,
            stepIndex: 0
        )

        XCTAssertEqual(step.stitchCountTarget, 36)
    }
}
