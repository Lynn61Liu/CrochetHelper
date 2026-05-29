import Foundation

struct CrochetProject: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var sourceLanguage: SourceLanguage
    var preferredDisplayNotation: DisplayNotation
    var componentOrder: [UUID]
    var createdAt: Date
    var updatedAt: Date
    var currentStepIndex: Int
    var completionState: CompletionState
}

struct SourcePattern: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var projectId: UUID
    var ocrRawText: String
    var croppedAssetId: UUID?
    var notationDetectionResult: SourceLanguage
    var detectedComponentRegions: [SourceRegion]
    var userCorrectedSourceText: String?
}

struct SourceRegion: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var assetId: UUID
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct PatternComponent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var projectId: UUID
    var name: String
    var type: PatternComponentType
    var sourceRegionId: UUID?
    var displayOrder: Int
    var completionState: CompletionState
    var primaryColorHex: String? = nil

    init(
        id: UUID,
        projectId: UUID,
        name: String,
        type: PatternComponentType,
        sourceRegionId: UUID?,
        displayOrder: Int,
        completionState: CompletionState,
        primaryColorHex: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.type = type
        self.sourceRegionId = sourceRegionId
        self.displayOrder = displayOrder
        self.completionState = completionState
        self.primaryColorHex = primaryColorHex
    }

    enum CodingKeys: String, CodingKey {
        case id
        case projectId
        case name
        case type
        case sourceRegionId
        case displayOrder
        case completionState
        case primaryColorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decode(UUID.self, forKey: .projectId)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(PatternComponentType.self, forKey: .type)
        sourceRegionId = try container.decodeIfPresent(UUID.self, forKey: .sourceRegionId)
        displayOrder = try container.decode(Int.self, forKey: .displayOrder)
        completionState = try container.decode(CompletionState.self, forKey: .completionState)
        primaryColorHex = try container.decodeIfPresent(String.self, forKey: .primaryColorHex)
    }
}

struct PatternStep: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var componentId: UUID
    var stepIndex: Int
    var roundLabel: String
    var rawInstruction: String
    var normalizedInstruction: String
    var actionSegments: [ActionSegment]
    var stitchCountTarget: Int?
    var notes: String?
}

struct ActionSegment: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var sourceText: String
    var action: StitchAction
    var count: Int
    var repeatCount: Int
    var yarnColorName: String?
    var yarnColorHex: String?
}

struct ProgressState: Codable, Equatable, Sendable {
    var projectId: UUID
    var currentComponentId: UUID
    var currentStepId: UUID
    var currentInStepStitchCount: Int
    var completedStepIds: Set<UUID>
    var completedComponentIds: Set<UUID>
    var lastUpdatedAt: Date
    var liveActivitySummary: String
}

struct CrochetAsset: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var projectId: UUID
    var role: AssetRole
    var localPath: String
    var mimeType: String
    var width: Int
    var height: Int
    var sha256: String
    var createdAt: Date
}
