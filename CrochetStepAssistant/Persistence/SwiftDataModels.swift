import Foundation
import SwiftData

@Model
final class StoredProject {
    @Attribute(.unique) var id: UUID
    var name: String
    var packageData: Data
    var updatedAt: Date
    var primaryColorHex: String
    var coverImageSystemName: String
    var completionProgress: Double
    var coverImageData: Data?

    init(
        id: UUID,
        name: String,
        packageData: Data,
        updatedAt: Date,
        primaryColorHex: String = "#D9A066",
        coverImageSystemName: String = "photo",
        completionProgress: Double = 0,
        coverImageData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.packageData = packageData
        self.updatedAt = updatedAt
        self.primaryColorHex = primaryColorHex
        self.coverImageSystemName = coverImageSystemName
        self.completionProgress = completionProgress
        self.coverImageData = coverImageData
    }
}
