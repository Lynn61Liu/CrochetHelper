import CryptoKit
import Foundation

struct AssetStore: Sendable {
    let rootDirectory: URL

    init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            self.rootDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("CrochetStepAssistantAssets", isDirectory: true)
        }
    }

    func saveAsset(
        data: Data,
        projectId: UUID,
        role: AssetRole,
        mimeType: String,
        width: Int,
        height: Int
    ) throws -> CrochetAsset {
        let assetId = UUID()
        let projectDirectory = rootDirectory.appendingPathComponent(projectId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        let fileExtension = mimeType == "image/png" ? "png" : "jpg"
        let fileURL = projectDirectory.appendingPathComponent("\(assetId.uuidString).\(fileExtension)")
        try data.write(to: fileURL, options: [.atomic])

        return CrochetAsset(
            id: assetId,
            projectId: projectId,
            role: role,
            localPath: fileURL.path,
            mimeType: mimeType,
            width: width,
            height: height,
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            createdAt: Date()
        )
    }
}
