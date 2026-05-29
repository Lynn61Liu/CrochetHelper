import SwiftUI
import SwiftData
import UIKit

struct ParseReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toast: ToastManager
    @State var sourceText: String
    var onProjectCreated: ((CrochetProjectPackage) -> Void)?
    @State private var subprojects: [ImportedSubproject] = []

    var body: some View {
        List {
            Section("Source Text") {
                TextEditor(text: $sourceText)
                    .frame(minHeight: 140)

                Button("Build Subprojects") {
                    parseSubprojects()
                }
            }

            Section("Subprojects Summary") {
                ForEach(Array(subprojects.indices), id: \.self) { index in
                    NavigationLink {
                        SubprojectReviewView(subproject: $subprojects[index])
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: subprojects[index].primaryColorHex))
                                .frame(width: 14, height: 14)
                            Text(subprojects[index].title)
                            Spacer()
                            Text("\(subprojects[index].lineCount) lines")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Create Project") {
                    createProject()
                }
                .disabled(subprojects.isEmpty)
            }
        }
        .navigationTitle("Subprojects")
        .onAppear(perform: parseSubprojects)
    }

    private func parseSubprojects() {
        subprojects = ImportedSubprojectExtractor().extract(from: sourceText)
    }

    private func createProject() {
        do {
            let package = buildPackage()
            try SwiftDataProjectRepository(modelContext: modelContext).save(package)
            NotificationCenter.default.post(name: .projectStoreDidChange, object: nil)
            onProjectCreated?(package)
            if onProjectCreated == nil {
                toast.show("Project created")
                dismiss()
            }
        } catch {
            toast.show("Create failed")
        }
    }

    private func buildPackage() -> CrochetProjectPackage {
        let now = Date()
        let projectId = UUID()
        let rootName = subprojects.first?.title.isEmpty == false ? subprojects.first!.title : "Imported Crochet Project"

        var components: [PatternComponent] = []
        var allSteps: [PatternStep] = []
        var componentOrder: [UUID] = []
        let parser = CrochetParser()

        for (index, subproject) in subprojects.enumerated() {
            let componentId = UUID()
            componentOrder.append(componentId)
            components.append(
                PatternComponent(
                    id: componentId,
                    projectId: projectId,
                    name: subproject.title,
                    type: .crochetPart,
                    sourceRegionId: nil,
                    displayOrder: index,
                    completionState: .notStarted
                )
            )

            let lines = subproject.sourceText.logicalStepLines().flatMap { $0.expandRangeIfNeeded() }
            let steps = lines.enumerated().map { lineIndex, line in
                parser.parseStep(line, componentId: componentId, stepIndex: lineIndex)
            }
            allSteps.append(contentsOf: steps)
        }

        let project = CrochetProject(
            id: projectId,
            name: rootName,
            sourceLanguage: .unknown,
            preferredDisplayNotation: .compact,
            componentOrder: componentOrder,
            createdAt: now,
            updatedAt: now,
            currentStepIndex: 0,
            completionState: .notStarted
        )

        let sourcePattern = SourcePattern(
            id: UUID(),
            projectId: projectId,
            ocrRawText: sourceText,
            croppedAssetId: nil,
            notationDetectionResult: .unknown,
            detectedComponentRegions: [],
            userCorrectedSourceText: nil
        )

        return CrochetProjectPackage(
            schemaVersion: 1,
            project: project,
            sourcePatterns: [sourcePattern],
            components: components,
            steps: allSteps,
            progress: nil,
            assets: []
        )
    }
}

#Preview {
    NavigationStack {
        ParseReviewView(sourceText: "耳朵\nR1: 6X\nR2: 6V\n\n身体\nR1: 8X\nR2-R4: 8X")
    }
}

private struct SubprojectReviewView: View {
    @Binding var subproject: ImportedSubproject
    @State private var steps: [PatternStep] = []

    private let componentId = UUID()

    var body: some View {
        List {
            Section("Structure") {
                TextField("Title", text: $subproject.title)
                TextField("Primary Color Hex", text: $subproject.primaryColorHex)
                    .textInputAutocapitalization(.never)
            }

            Section("Source Text") {
                TextEditor(text: $subproject.sourceText)
                    .frame(minHeight: 160)
                Button("Parse Again") {
                    parse()
                }
            }

            Section("Structured Draft") {
                ForEach($steps) { $step in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Round", text: $step.roundLabel)
                                .font(.headline)
                            Spacer()
                            if let total = StitchCountCalculator.totalStitches(for: step.rawInstruction) {
                                Text("Total: \(total)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        TextField("Raw instruction", text: $step.rawInstruction)
                    }
                }
            }
        }
        .navigationTitle(subproject.title)
        .onAppear(perform: parse)
    }

    private func parse() {
        let logicalLines = subproject.sourceText.logicalStepLines()
        let expanded = logicalLines.flatMap { $0.expandRangeIfNeeded() }
        steps = expanded
            .enumerated()
            .map { index, line in
                CrochetParser().parseStep(line, componentId: componentId, stepIndex: index)
            }
    }
}

struct StoredSubprojectStructureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var useProjectColor: Bool
    @State private var subprojectColor: Color
    @State private var steps: [PatternStep]

    let projectColorHex: String
    let onSave: (String, String?, [PatternStep]) -> Void

    init(
        component: PatternComponent,
        steps: [PatternStep],
        projectColorHex: String,
        onSave: @escaping (String, String?, [PatternStep]) -> Void
    ) {
        _title = State(initialValue: component.name)
        _useProjectColor = State(initialValue: component.primaryColorHex == nil)
        _subprojectColor = State(initialValue: Color(hex: component.primaryColorHex ?? projectColorHex))
        _steps = State(initialValue: steps.sorted { $0.stepIndex < $1.stepIndex })
        self.projectColorHex = projectColorHex
        self.onSave = onSave
    }

    var body: some View {
        List {
            Section("Structure") {
                TextField("Title", text: $title)
                Toggle("Use project color", isOn: $useProjectColor)
                if !useProjectColor {
                    ColorPicker("Subproject color", selection: $subprojectColor)
                }
            }

            Section("Structured Draft") {
                ForEach($steps) { $step in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Round", text: $step.roundLabel)
                                .font(.headline)
                            Spacer()
                            if let total = StitchCountCalculator.totalStitches(for: step.rawInstruction) {
                                Text("Total: \(total)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        TextField("Raw instruction", text: $step.rawInstruction)
                        ForEach(step.actionSegments.indices, id: \.self) { segmentIndex in
                            ColorPicker(
                                step.actionSegments[segmentIndex].sourceText,
                                selection: Binding(
                                    get: {
                                        Color(hex: step.actionSegments[segmentIndex].yarnColorHex ?? resolvedSubprojectColorHex)
                                    },
                                    set: { newColor in
                                        step.actionSegments[segmentIndex].yarnColorHex = UIColor(newColor).toHexString() ?? resolvedSubprojectColorHex
                                    }
                                )
                            )
                        }
                    }
                }
            }

            Section {
                Button("Save Changes") {
                    let normalized = steps.enumerated().map { index, step in
                        CrochetParser().parseStep(step.rawInstruction, componentId: step.componentId, stepIndex: index)
                    }
                    let finalSteps = normalized.map { parsedStep in
                        var updated = parsedStep
                        if let original = steps.first(where: { $0.id == parsedStep.id || $0.stepIndex == parsedStep.stepIndex }) {
                            updated.actionSegments = updated.actionSegments.enumerated().map { index, segment in
                                var copy = segment
                                if original.actionSegments.indices.contains(index) {
                                    copy.yarnColorHex = original.actionSegments[index].yarnColorHex
                                }
                                return copy
                            }
                        }
                        return updated
                    }
                    onSave(title, useProjectColor ? nil : resolvedSubprojectColorHex, finalSteps)
                    dismiss()
                }
            }
        }
        .navigationTitle(title.isEmpty ? "Subproject" : title)
    }

    private var resolvedSubprojectColorHex: String {
        useProjectColor ? projectColorHex : (UIColor(subprojectColor).toHexString() ?? projectColorHex)
    }
}

private extension UIColor {
    func toHexString() -> String? {
        guard let comps = cgColor.components else { return nil }
        let r = Int((comps[safe: 0] ?? 0) * 255)
        let g = Int((comps[safe: 1] ?? 0) * 255)
        let b = Int((comps[safe: 2] ?? 0) * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct ImportedSubproject: Identifiable, Equatable {
    let id: UUID
    var title: String
    var primaryColorHex: String
    var sourceText: String

    var lineCount: Int {
        sourceText.logicalStepLines().count
    }
}

private struct ImportedSubprojectExtractor {
    func extract(from sourceText: String) -> [ImportedSubproject] {
        let blocks = splitIntoBlocks(sourceText)
        return blocks.enumerated().compactMap { index, block in
            guard !block.isEmpty else { return nil }
            let title = block[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let stepLines = Array(block.dropFirst())
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !stepLines.isEmpty else {
                return nil
            }

            return ImportedSubproject(
                id: UUID(),
                title: title.isEmpty ? "Subproject \(index + 1)" : title,
                primaryColorHex: "#D9A066",
                sourceText: stepLines.joined(separator: "\n")
            )
        }
    }

    private func splitIntoBlocks(_ sourceText: String) -> [[String]] {
        let lines = sourceText.components(separatedBy: .newlines)
        var blocks: [[String]] = []
        var current: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !current.isEmpty {
                    blocks.append(current)
                    current = []
                }
                continue
            }
            current.append(trimmed)
        }

        if !current.isEmpty {
            blocks.append(current)
        }
        return blocks
    }
}

private extension String {
    var isRoundLine: Bool {
        range(of: #"^\s*(R\d+|第\d+圈)\s*[:：]?"#, options: .regularExpression) != nil
    }

    func logicalStepLines() -> [String] {
        let rawLines = components(separatedBy: .newlines)
        var lines: [String] = []
        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.isRoundLine || lines.isEmpty {
                lines.append(trimmed)
            } else {
                // Continuation lines belong to the previous round, preventing accidental split like R43.
                lines[lines.count - 1] += trimmed.hasPrefix(",") ? trimmed : ",\(trimmed)"
            }
        }
        return lines
    }

    func expandRangeIfNeeded() -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"^\s*R(\d+)\s*-\s*R?(\d+)\s*[:：]\s*(.+)$"#, options: []) else {
            return [self]
        }
        let nsRange = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: nsRange),
              match.numberOfRanges == 4,
              let startRange = Range(match.range(at: 1), in: self),
              let endRange = Range(match.range(at: 2), in: self),
              let bodyRange = Range(match.range(at: 3), in: self),
              let start = Int(self[startRange]),
              let end = Int(self[endRange]),
              start <= end else {
            return [self]
        }

        let body = String(self[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (start...end).map { "R\($0): \(body)" }
    }
}

private extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        let r, g, b: Double
        switch clean.count {
        case 6:
            r = Double((value >> 16) & 0xff) / 255
            g = Double((value >> 8) & 0xff) / 255
            b = Double(value & 0xff) / 255
        default:
            r = 0.85
            g = 0.63
            b = 0.40
        }
        self = Color(red: r, green: g, blue: b)
    }
}

private enum StitchCountCalculator {
    static func totalStitches(for instruction: String) -> Int? {
        let normalized = normalize(instruction)
        let body = normalized
            .replacingOccurrences(of: #"^\s*(R\d+|第\d+圈)\s*[:：]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let explicit = explicitTarget(from: body) {
            return explicit
        }

        guard !body.isEmpty else { return nil }
        return sumTopLevelSegments(in: body)
    }

    private static func explicitTarget(from body: String) -> Int? {
        guard let range = body.range(of: #"\((\d+)\)\s*$"#, options: .regularExpression) else {
            return nil
        }
        let raw = String(body[range]).replacingOccurrences(of: #"[^0-9]"#, with: "", options: .regularExpression)
        return Int(raw)
    }

    private static func sumTopLevelSegments(in body: String) -> Int {
        let noTail = body.replacingOccurrences(of: #"\(\d+\)\s*$"#, with: "", options: .regularExpression)
        let segments = splitTopLevelByComma(noTail)
        return segments.reduce(0) { $0 + segmentContribution($1) }
    }

    private static func segmentContribution(_ segment: String) -> Int {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        // 8(X,W) => groupStitches(2) * 8
        if let m = firstRegexMatch(#"^(\d+)\s*\((.+)\)\s*$"#, in: trimmed),
           let repeatCount = Int(m[0]) {
            let inner = m[1]
            let innerSegments = splitTopLevelByComma(inner)
            let innerTotal = innerSegments.reduce(0) { $0 + symbolContribution($1) }
            return repeatCount * innerTotal
        }

        // x6 or *6 at tail
        if let m = firstRegexMatch(#"^(.+?)\s*(x|\*)\s*(\d+)\s*$"#, in: trimmed),
           let repeatCount = Int(m[2]) {
            let unit = m[0]
            return repeatCount * symbolContribution(unit)
        }

        return symbolContribution(trimmed)
    }

    private static func symbolContribution(_ text: String) -> Int {
        let clean = text.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        guard !clean.isEmpty else { return 0 }

        let leading = leadingNumber(in: clean) ?? 1
        let symbol = clean.replacingOccurrences(of: #"^\d+"#, with: "", options: .regularExpression).uppercased()

        if symbol.hasPrefix("V") || symbol.hasPrefix("W") {
            return leading * 2
        }
        if symbol.hasPrefix("T") {
            return leading * 3
        }
        if symbol.hasPrefix("TW") {
            return leading * 3
        }
        return leading
    }

    private static func leadingNumber(in text: String) -> Int? {
        guard let m = firstRegexMatch(#"^(\d+)"#, in: text) else {
            return nil
        }
        return Int(m[0])
    }

    private static func splitTopLevelByComma(_ input: String) -> [String] {
        var parts: [String] = []
        var buf = ""
        var depth = 0
        for ch in input {
            switch ch {
            case "(":
                depth += 1
                buf.append(ch)
            case ")":
                depth = max(0, depth - 1)
                buf.append(ch)
            case "," where depth == 0:
                let t = buf.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { parts.append(t) }
                buf = ""
            default:
                buf.append(ch)
            }
        }
        let tail = buf.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { parts.append(tail) }
        return parts
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "X", with: "X")
    }

    private static func firstRegexMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else {
            return nil
        }
        var groups: [String] = []
        for idx in 1..<match.numberOfRanges {
            let range = match.range(at: idx)
            guard let swiftRange = Range(range, in: text) else {
                groups.append("")
                continue
            }
            groups.append(String(text[swiftRange]))
        }
        return groups
    }
}
