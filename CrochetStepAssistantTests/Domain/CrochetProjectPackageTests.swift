import XCTest
@testable import CrochetStepAssistant

final class CrochetProjectPackageTests: XCTestCase {
    func testProjectPackageRoundTripsThroughJSON() throws {
        let package = CrochetProjectPackage(
            schemaVersion: 1,
            project: CrochetProject(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Bear",
                sourceLanguage: .chinese,
                preferredDisplayNotation: .compact,
                componentOrder: [UUID(uuidString: "22222222-2222-2222-2222-222222222222")!],
                createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 2),
                currentStepIndex: 0,
                completionState: .inProgress
            ),
            sourcePatterns: [],
            components: [],
            steps: [],
            progress: nil,
            assets: []
        )

        let data = try JSONEncoder.crochet.encode(package)
        let decoded = try JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.project.name, "Bear")
        XCTAssertEqual(decoded.project.sourceLanguage, .chinese)
    }
}
