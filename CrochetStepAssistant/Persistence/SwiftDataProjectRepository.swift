import Foundation
import SwiftData

@MainActor
final class SwiftDataProjectRepository: CrochetProjectRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func listProjects() throws -> [CrochetProject] {
        let descriptor = FetchDescriptor<StoredProject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        return try modelContext.fetch(descriptor).compactMap { stored in
            try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: stored.packageData).project
        }
    }

    func loadProject(id: UUID) throws -> CrochetProjectPackage? {
        let projectId = id
        let descriptor = FetchDescriptor<StoredProject>(
            predicate: #Predicate { $0.id == projectId }
        )

        guard let stored = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return try JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: stored.packageData)
    }

    func save(_ package: CrochetProjectPackage) throws {
        let data = try JSONEncoder.crochet.encode(package)
        let projectId = package.project.id
        let descriptor = FetchDescriptor<StoredProject>(
            predicate: #Predicate { $0.id == projectId }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = package.project.name
            existing.packageData = data
            existing.updatedAt = package.project.updatedAt
        } else {
            modelContext.insert(StoredProject(
                id: package.project.id,
                name: package.project.name,
                packageData: data,
                updatedAt: package.project.updatedAt
            ))
        }

        try modelContext.save()
    }

    func deleteProject(id: UUID) throws {
        let projectId = id
        let descriptor = FetchDescriptor<StoredProject>(
            predicate: #Predicate { $0.id == projectId }
        )

        for stored in try modelContext.fetch(descriptor) {
            modelContext.delete(stored)
        }

        try modelContext.save()
    }
}
