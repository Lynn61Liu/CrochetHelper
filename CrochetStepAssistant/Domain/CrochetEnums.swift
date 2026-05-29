import Foundation

enum SourceLanguage: String, Codable, CaseIterable, Sendable {
    case chinese
    case english
    case mixed
    case unknown
}

enum DisplayNotation: String, Codable, CaseIterable, Sendable {
    case compact
    case chineseTerms
    case englishTerms
    case source
}

enum CompletionState: String, Codable, Sendable {
    case notStarted
    case inProgress
    case completed
}

enum PatternComponentType: String, Codable, Sendable {
    case crochetPart
    case assembly
    case finishing
}

enum AssetRole: String, Codable, Sendable {
    case original
    case crop
    case sourceRegion
    case thumbnail
}

enum StitchAction: String, Codable, Sendable {
    case chain = "CH"
    case singleCrochet = "X"
    case singleCrochetIncrease = "V"
    case singleCrochetDecrease = "A"
    case threeSingleCrochetInOne = "W"
    case threeSingleCrochetMerged = "M"
    case halfDoubleCrochet = "T"
    case halfDoubleCrochetIncrease = "TV"
    case halfDoubleCrochetDecrease = "TA"
    case slipStitch = "SL"
    case chainSpace = "K"
    case doubleCrochet = "F"
    case doubleCrochetIncrease = "FV"
    case doubleCrochetDecrease = "FA"
    case backLoopOnly = "BLO"
    case frontLoopOnly = "FLO"
    case unknown
}
