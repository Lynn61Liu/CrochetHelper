import XCTest
import SwiftData
@testable import CrochetStepAssistant

@MainActor
final class SwiftDataProjectRepositoryTests: XCTestCase {
    func testSavesAndListsProjectPackages() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredProject.self, configurations: config)
        let repository = SwiftDataProjectRepository(modelContext: container.mainContext)

        let project = CrochetProject(
            id: UUID(),
            name: "Local Bear",
            sourceLanguage: .chinese,
            preferredDisplayNotation: .compact,
            componentOrder: [],
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            currentStepIndex: 0,
            completionState: .notStarted
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

        try repository.save(package)
        let projects = try repository.listProjects()

        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects.first?.name, "Local Bear")
    }
}
