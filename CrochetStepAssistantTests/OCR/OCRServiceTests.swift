import XCTest
import UIKit
@testable import CrochetStepAssistant

private struct MockOCRService: OCRServicing {
    let text: String

    func recognizeText(in image: UIImage) async throws -> String {
        text
    }
}

final class OCRServiceTests: XCTestCase {
    func testMockOCRReturnsConfiguredText() async throws {
        let service = MockOCRService(text: "R1: 6X")
        let text = try await service.recognizeText(in: UIImage())
        XCTAssertEqual(text, "R1: 6X")
    }
}
