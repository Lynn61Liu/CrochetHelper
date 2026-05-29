import Foundation

struct CrochetParser: Sendable {
    private let dictionary = NotationDictionary()

    func parseStep(_ line: String, componentId: UUID, stepIndex: Int) -> PatternStep {
        let roundLabel = CrochetTokenizer().tokenize(line).first?.text ?? "Step \(stepIndex + 1)"
        let target = extractTargetCount(from: line)
        let segmentTexts = extractSegmentTexts(from: line)
        let segments = segmentTexts.map { parseSegment($0) }

        return PatternStep(
            id: UUID(),
            componentId: componentId,
            stepIndex: stepIndex,
            roundLabel: roundLabel,
            rawInstruction: line,
            normalizedInstruction: segmentTexts.joined(separator: " + "),
            actionSegments: segments,
            stitchCountTarget: target,
            notes: nil
        )
    }

    private func extractTargetCount(from line: String) -> Int? {
        let normalized = normalize(line)
        guard let match = normalized.matches(of: try! Regex(#"\((\d+)\)\s*$"#)).first else {
            return nil
        }

        return Int(String(normalized[match.range]).trimmingCharacters(in: CharacterSet(charactersIn: "() ")))
    }

    private func extractSegmentTexts(from line: String) -> [String] {
        let normalized = normalize(line)
            .replacingOccurrences(of: #"^\s*(R\d+|第\d+圈)\s*:?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\(\d+\)\s*$"#, with: "", options: .regularExpression)

        var segments: [String] = []
        var current = ""
        var depth = 0

        for character in normalized {
            switch character {
            case "(":
                depth += 1
                current.append(character)
            case ")":
                depth = max(0, depth - 1)
                current.append(character)
            case "," where depth == 0:
                appendSegment(current, to: &segments)
                current = ""
            default:
                current.append(character)
            }
        }

        appendSegment(current, to: &segments)
        return segments
    }

    private func appendSegment(_ text: String, to segments: inout [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            segments.append(trimmed)
        }
    }

    private func parseSegment(_ text: String) -> ActionSegment {
        let repeatCount = extractRepeatCount(from: text)
        let symbol = extractPrimarySymbol(from: text)
        let count = extractLeadingCount(from: text) ?? 1

        return ActionSegment(
            id: UUID(),
            sourceText: text,
            action: dictionary.action(for: symbol),
            count: count,
            repeatCount: repeatCount,
            yarnColorName: nil,
            yarnColorHex: nil
        )
    }

    private func extractRepeatCount(from text: String) -> Int {
        guard let match = text.matches(of: try! Regex(#"x\s*(\d+)"#)).first else {
            return 1
        }

        let raw = String(text[match.range])
            .replacingOccurrences(of: "x", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Int(raw) ?? 1
    }

    private func extractPrimarySymbol(from text: String) -> String {
        let clean = text.replacingOccurrences(of: #"[^A-Z]"#, with: "", options: .regularExpression)
        let knownSymbols = ["BLO", "FLO", "SL", "CH", "FV", "FA", "TV", "TA", "X", "V", "A", "W", "M", "T", "K", "F"]

        return knownSymbols.first { clean.contains($0) } ?? ""
    }

    private func extractLeadingCount(from text: String) -> Int? {
        guard let match = text.matches(of: try! Regex(#"^\d+"#)).first else {
            return nil
        }

        return Int(String(text[match.range]))
    }

    private func normalize(_ line: String) -> String {
        line
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "重复", with: "x")
            .replacingOccurrences(of: "次", with: "")
    }
}
