import XCTest
@testable import CrochetStepAssistant

final class AssetStoreTests: XCTestCase {
    func testSavesAssetAndReturnsMetadata() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = AssetStore(rootDirectory: root)
        let projectId = UUID()
        let imageData = Data([0x01, 0x02, 0x03])

        let asset = try store.saveAsset(
            data: imageData,
            projectId: projectId,
            role: .original,
            mimeType: "image/jpeg",
            width: 10,
            height: 20
        )

        XCTAssertEqual(asset.projectId, projectId)
        XCTAssertEqual(asset.role, .original)
        XCTAssertEqual(asset.mimeType, "image/jpeg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.localPath))
        XCTAssertFalse(asset.sha256.isEmpty)
    }
}
