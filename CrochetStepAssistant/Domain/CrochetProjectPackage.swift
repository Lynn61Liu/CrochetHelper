import Foundation

struct CrochetProjectPackage: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var project: CrochetProject
    var sourcePatterns: [SourcePattern]
    var components: [PatternComponent]
    var steps: [PatternStep]
    var progress: ProgressState?
    var assets: [CrochetAsset]
    var executionState: CrochetExecutionState? = nil
    var executionStatesByComponentId: [String: CrochetExecutionState] = [:]

    init(
        schemaVersion: Int,
        project: CrochetProject,
        sourcePatterns: [SourcePattern],
        components: [PatternComponent],
        steps: [PatternStep],
        progress: ProgressState?,
        assets: [CrochetAsset],
        executionState: CrochetExecutionState? = nil,
        executionStatesByComponentId: [String: CrochetExecutionState] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.project = project
        self.sourcePatterns = sourcePatterns
        self.components = components
        self.steps = steps
        self.progress = progress
        self.assets = assets
        self.executionState = executionState
        self.executionStatesByComponentId = executionStatesByComponentId
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case project
        case sourcePatterns
        case components
        case steps
        case progress
        case assets
        case executionState
        case executionStatesByComponentId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        project = try container.decode(CrochetProject.self, forKey: .project)
        sourcePatterns = try container.decode([SourcePattern].self, forKey: .sourcePatterns)
        components = try container.decode([PatternComponent].self, forKey: .components)
        steps = try container.decode([PatternStep].self, forKey: .steps)
        progress = try container.decodeIfPresent(ProgressState.self, forKey: .progress)
        assets = try container.decode([CrochetAsset].self, forKey: .assets)
        executionState = try container.decodeIfPresent(CrochetExecutionState.self, forKey: .executionState)
        executionStatesByComponentId = try container.decodeIfPresent([String: CrochetExecutionState].self, forKey: .executionStatesByComponentId) ?? [:]
    }
}

struct CrochetExecutionState: Codable, Equatable, Sendable {
    var currentComponentId: UUID
    var currentStepId: UUID
    var currentSegmentIndex: Int
    var segmentCounts: [String: Int]
    var completedStepIds: Set<UUID>
    var completedComponentIds: Set<UUID>
    var updatedAt: Date

    init(
        currentComponentId: UUID,
        currentStepId: UUID,
        currentSegmentIndex: Int,
        segmentCounts: [String: Int] = [:],
        completedStepIds: Set<UUID> = [],
        completedComponentIds: Set<UUID> = [],
        updatedAt: Date = Date()
    ) {
        self.currentComponentId = currentComponentId
        self.currentStepId = currentStepId
        self.currentSegmentIndex = currentSegmentIndex
        self.segmentCounts = segmentCounts
        self.completedStepIds = completedStepIds
        self.completedComponentIds = completedComponentIds
        self.updatedAt = updatedAt
    }
}

extension JSONEncoder {
    static var crochet: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var crochet: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
