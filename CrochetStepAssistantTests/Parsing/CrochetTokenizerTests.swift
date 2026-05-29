import XCTest
@testable import CrochetStepAssistant

final class CrochetTokenizerTests: XCTestCase {
    func testTokenizesLinearAndRepeatSegments() {
        let tokens = CrochetTokenizer().tokenize("R5: 3X, (5X,V) x 6, 2X (36)")
        XCTAssertEqual(tokens.map(\.text), ["R5", "3X", "(5X,V) x 6", "2X", "36"])
    }

    func testTokenizesChineseRoundLabel() {
        let tokens = CrochetTokenizer().tokenize("第3圈：5X，V，重复6次（36）")
        XCTAssertEqual(tokens.first?.text, "第3圈")
        XCTAssertTrue(tokens.contains { $0.text == "5X" })
        XCTAssertTrue(tokens.contains { $0.text == "V" })
    }
}
