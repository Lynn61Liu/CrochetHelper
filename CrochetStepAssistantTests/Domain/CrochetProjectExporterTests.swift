import XCTest
@testable import CrochetStepAssistant

final class CrochetProjectExporterTests: XCTestCase {
    func testExportsProjectJSON() throws {
        let project = CrochetProject(
            id: UUID(),
            name: "Export Bear",
            sourceLanguage: .mixed,
            preferredDisplayNotation: .compact,
            componentOrder: [],
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            currentStepIndex: 0,
            completionState: .inProgress
        )
        let package = CrochetProjectPackage(
            schemaVersion: 1,
            project: project,
            sourcePatterns: [],
            components: [],
            steps: [],
            progress: nil,
            assets: []
        )

        let data = try CrochetProjectExporter().projectJSONData(from: package)
        let decoded = try JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: data)

        XCTAssertEqual(decoded.project.name, "Export Bear")
        XCTAssertEqual(decoded.schemaVersion, 1)
    }
}
