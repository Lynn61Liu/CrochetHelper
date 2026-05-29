import Foundation

struct CrochetParser: Sendable {
    private let dictionary = NotationDictionary()

    func parseStep(_ line: String, componentId: UUID, stepIndex: Int) -> PatternStep {
        let roundLabel = CrochetTokenizer().tokenize(line).first?.text ?? "Step \(stepIndex + 1)"
        let target = targetCount(for: line)
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

    func targetCount(for line: String) -> Int? {
        extractTargetCount(from: line)
    }

    private func extractTargetCount(from line: String) -> Int? {
        let normalized = normalize(line)
        if let match = normalized.matches(of: try! Regex(#"\((\d+)\)\s*$"#)).first {
            return Int(String(normalized[match.range]).trimmingCharacters(in: CharacterSet(charactersIn: "() ")))
        }

        let body = normalized
            .replacingOccurrences(of: #"^\s*(R\d+|第\d+圈)\s*:?\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        return sumTopLevelSegments(in: body)
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

    private func sumTopLevelSegments(in body: String) -> Int {
        let segments = splitTopLevelByComma(body)
        return segments.reduce(0) { $0 + segmentContribution($1) }
    }

    private func segmentContribution(_ segment: String) -> Int {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        if let match = firstRegexMatch(#"^(\d+)\s*\((.+)\)\s*$"#, in: trimmed),
           let repeatCount = Int(match[0]) {
            let innerSegments = splitTopLevelByComma(match[1])
            let innerTotal = innerSegments.reduce(0) { $0 + symbolContribution($1) }
            return repeatCount * innerTotal
        }

        if let match = firstRegexMatch(#"^(.+?)\s*(x|\*)\s*(\d+)\s*$"#, in: trimmed),
           let repeatCount = Int(match[2]) {
            return repeatCount * symbolContribution(match[0])
        }

        return symbolContribution(trimmed)
    }

    private func symbolContribution(_ text: String) -> Int {
        let clean = text.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        guard !clean.isEmpty else { return 0 }

        let leading = extractLeadingCount(from: clean) ?? 1
        let symbol = clean.replacingOccurrences(of: #"^\d+"#, with: "", options: .regularExpression).uppercased()

        if symbol.hasPrefix("V") || symbol.hasPrefix("W") {
            return leading * 2
        }
        if symbol.hasPrefix("T") || symbol.hasPrefix("TW") {
            return leading * 3
        }
        return leading
    }

    private func splitTopLevelByComma(_ input: String) -> [String] {
        var parts: [String] = []
        var buffer = ""
        var depth = 0
        for character in input {
            switch character {
            case "(":
                depth += 1
                buffer.append(character)
            case ")":
                depth = max(0, depth - 1)
                buffer.append(character)
            case "," where depth == 0:
                appendSegment(buffer, to: &parts)
                buffer = ""
            default:
                buffer.append(character)
            }
        }
        appendSegment(buffer, to: &parts)
        return parts
    }

    private func firstRegexMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange) else {
            return nil
        }
        return (1..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: text) else {
                return ""
            }
            return String(text[range])
        }
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
