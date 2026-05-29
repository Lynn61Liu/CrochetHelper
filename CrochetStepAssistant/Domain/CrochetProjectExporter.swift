import Foundation

struct CrochetProjectExporter {
    func projectJSONData(from package: CrochetProjectPackage) throws -> Data {
        try JSONEncoder.crochet.encode(package)
    }
}
