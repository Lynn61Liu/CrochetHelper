import ActivityKit
import Foundation

struct CrochetLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var roundLabel: String
        var instructionSummary: String
        var countProgress: String
    }

    var projectName: String
}
