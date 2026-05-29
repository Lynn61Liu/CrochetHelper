import Foundation

@MainActor
protocol CrochetProjectRepository {
    func listProjects() throws -> [CrochetProject]
    func loadProject(id: UUID) throws -> CrochetProjectPackage?
    func save(_ package: CrochetProjectPackage) throws
    func deleteProject(id: UUID) throws
}
