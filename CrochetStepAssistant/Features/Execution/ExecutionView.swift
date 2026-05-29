import SwiftUI

struct ExecutionView: View {
    let steps: [PatternStep]
    let componentId: UUID?
    let primaryColorHex: String
    let subprojectColorHex: String?
    let initialState: CrochetExecutionState?
    let onStateChange: ((CrochetExecutionState) -> Void)?

    @State private var currentRowIndex = 0
    @State private var currentSegmentIndex = 0
    @State private var segmentCounts: [String: Int] = [:]
    @State private var completedStepIds: Set<UUID> = []
    @State private var completedComponentIds: Set<UUID> = []
    @State private var tapScale = 1.0
    @State private var flashSegment = false

    private var sortedSteps: [PatternStep] {
        steps.sorted { $0.stepIndex < $1.stepIndex }
    }

    private var currentStep: PatternStep? {
        guard sortedSteps.indices.contains(currentRowIndex) else { return nil }
        return sortedSteps[currentRowIndex]
    }

    private var rowSegments: [CounterSegment] {
        guard let currentStep else { return [] }
        return counterSegments(for: currentStep)
    }

    private var currentSegment: CounterSegment? {
        guard rowSegments.indices.contains(currentSegmentIndex) else { return nil }
        return rowSegments[currentSegmentIndex]
    }

    private var mainColor: Color {
        Color(hex: primaryColorHex, fallback: Color(red: 0.30, green: 0.64, blue: 0.39))
    }

    private var accentColor: Color {
        currentSegmentColor.opacity(0.88)
    }

    private var currentSegmentColor: Color {
        Color(hex: currentSegment?.colorHex ?? subprojectColorHex ?? primaryColorHex, fallback: mainColor)
    }

    private var rowTotal: Int {
        currentStep?.stitchCountTarget ?? rowSegments.reduce(0) { $0 + $1.target }
    }

    private var completedInRow: Int {
        rowSegments.reduce(0) { $0 + min($1.current, $1.target) }
    }

    init(
        steps: [PatternStep],
        componentId: UUID? = nil,
        primaryColorHex: String = "#4FA363",
        subprojectColorHex: String? = nil,
        initialState: CrochetExecutionState? = nil,
        onStateChange: ((CrochetExecutionState) -> Void)? = nil
    ) {
        self.steps = steps
        self.componentId = componentId
        self.primaryColorHex = primaryColorHex
        self.subprojectColorHex = subprojectColorHex
        self.initialState = initialState
        self.onStateChange = onStateChange
    }

    var body: some View {
        ZStack {
            mainColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    segmentCard
                    segmentOverview
                    rowProgress
                    bottomActions
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 92)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomRowSwitcher
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear(perform: restoreState)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Row \(currentRowIndex + 1) / \(max(sortedSteps.count, 1))")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(.white.opacity(0.18), in: Capsule())

            Text(currentStep?.roundLabel ?? "R-")
                .font(.system(size: 62, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("This row total: \(rowTotal) stitches")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [mainColor.opacity(0.98), mainColor.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }

    private var segmentCard: some View {
        VStack(spacing: 24) {
            Text(currentSegment?.label ?? "-")
                .font(.title.bold())

            HStack(spacing: 26) {
                Button {
                    adjustCurrentSegment(by: -1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 30, weight: .bold))
                        .frame(width: 68, height: 68)
                        .background(Color(.systemGray5), in: Circle())
                        .foregroundStyle(.black)
                }
                .disabled(currentSegment == nil)

                VStack(spacing: 2) {
                    Text("\(currentSegment?.current ?? 0)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("/ \(currentSegment?.target ?? 0)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 92)

                Button {
                    completeCurrentSegment()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .bold))
                        .frame(width: 68, height: 68)
                        .background(accentColor, in: Circle())
                        .foregroundStyle(.white)
                }
                .disabled(currentSegment == nil)
            }

            Text(currentSegment?.label ?? "-")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 82)
                .background((flashSegment ? accentColor : mainColor.opacity(0.13)), in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(flashSegment ? .white : .black)
                .scaleEffect(tapScale)
                .contentShape(Rectangle())
                .onTapGesture {
                    incrementCurrentSegment()
                }
        }
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(mainColor.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
    }

    private var segmentOverview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(rowSegments.enumerated()), id: \.element.id) { index, segment in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentSegmentIndex = index
                        }
                        persistState()
                    } label: {
                        Text(segment.label)
                            .font(.headline.weight(index == currentSegmentIndex ? .bold : .regular))
                            .foregroundStyle(segmentTextColor(segment, index: index))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 48)
                            .background(segmentBackground(segment, index: index), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(mainColor.opacity(segment.completed ? 0 : 0.45), lineWidth: 1)
                            )
                            .scaleEffect(index == currentSegmentIndex ? 1.06 : 1)
                            .shadow(color: index == currentSegmentIndex ? mainColor.opacity(0.28) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(mainColor.opacity(0.45), lineWidth: 1)
        )
    }

    private var rowProgress: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Row progress")
                    .font(.headline)
                Spacer()
                Text("\(completedInRow) / \(rowTotal)")
                    .font(.headline)
            }

            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(progressChunkCompleted(index) ? accentColor : Color(.systemGray5))
                        .frame(height: 12)
                }

                Button {
                    resetCurrentRow()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.weight(.bold))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .foregroundStyle(.white)
                .accessibilityLabel("Reset Row")
            }
        }
        .padding(.vertical, 8)
        .foregroundStyle(.white)
    }

    private var bottomActions: some View {
        HStack(spacing: 34) {
            VStack(spacing: 10) {
                Button {
                    moveRow(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 30, weight: .semibold))
                        .frame(width: 86, height: 86)
                        .background(.white.opacity(0.92), in: Circle())
                        .foregroundStyle(.black)
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                }
                .disabled(currentRowIndex == 0)
                Text("Previous Row")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                Button {
                    completeRow()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .frame(width: 98, height: 98)
                        .background(accentColor, in: Circle())
                        .foregroundStyle(.white)
                        .shadow(color: accentColor.opacity(0.35), radius: 18, y: 8)
                }
                Text("Complete Row")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var bottomRowSwitcher: some View {
        HStack {
            Button {
                moveRow(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 52, height: 52)
            }
            .disabled(currentRowIndex == 0)

            Spacer()

            Text("Row \(currentRowIndex + 1) of \(max(sortedSteps.count, 1))")
                .font(.headline.bold())

            Spacer()

            Button {
                moveRow(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 52, height: 52)
            }
            .disabled(currentRowIndex >= sortedSteps.count - 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .background(.white)
    }

    private func counterSegments(for step: PatternStep) -> [CounterSegment] {
        if step.actionSegments.isEmpty {
            let key = "\(step.id.uuidString):0"
            let target = step.stitchCountTarget ?? 1
            let current = segmentCounts[key] ?? 0
            return [CounterSegment(id: key, label: step.normalizedInstruction, target: target, current: current)]
        }

        return step.actionSegments.enumerated().map { index, segment in
            let key = "\(step.id.uuidString):\(index)"
            let target = max(1, segmentTarget(segment))
            let current = segmentCounts[key] ?? 0
            return CounterSegment(
                id: key,
                label: displayLabel(for: segment),
                target: target,
                current: current,
                colorHex: segment.yarnColorHex
            )
        }
    }

    private func displayLabel(for segment: ActionSegment) -> String {
        segment.sourceText
            .replacingOccurrences(of: #"^(\d+)\((.+)\)$"#, with: "$1 ($2)", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func segmentTarget(_ segment: ActionSegment) -> Int {
        if let match = segment.sourceText.range(of: #"^\d+(?=\s*\()"#, options: .regularExpression) {
            return Int(segment.sourceText[match]) ?? segment.count
        }
        if segment.repeatCount > 1 {
            return segment.repeatCount
        }
        return max(1, segment.count)
    }

    private func incrementCurrentSegment() {
        withAnimation(.easeInOut(duration: 0.1)) {
            tapScale = 0.97
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                tapScale = 1
            }
        }
        adjustCurrentSegment(by: 1)
    }

    private func adjustCurrentSegment(by delta: Int) {
        guard let segment = currentSegment else { return }
        let next = max(0, min(segment.target, segment.current + delta))
        segmentCounts[segment.id] = next
        if next >= segment.target {
            completeCurrentSegment()
        } else {
            persistState()
        }
    }

    private func completeCurrentSegment() {
        guard let segment = currentSegment else { return }
        segmentCounts[segment.id] = segment.target
        withAnimation(.easeInOut(duration: 0.14)) {
            flashSegment = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeInOut(duration: 0.16)) {
                flashSegment = false
            }
            moveToNextSegment()
        }
        persistState()
    }

    private func moveToNextSegment() {
        if currentSegmentIndex < rowSegments.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentSegmentIndex += 1
            }
        } else {
            completeRow()
        }
        persistState()
    }

    private func completeRow() {
        guard let currentStep else { return }
        for segment in rowSegments {
            segmentCounts[segment.id] = segment.target
        }
        completedStepIds.insert(currentStep.id)
        if currentRowIndex < sortedSteps.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentRowIndex += 1
                currentSegmentIndex = 0
            }
        } else if let componentId {
            completedComponentIds.insert(componentId)
        }
        persistState()
    }

    private func moveRow(by delta: Int) {
        guard !sortedSteps.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentRowIndex = min(max(currentRowIndex + delta, 0), sortedSteps.count - 1)
            currentSegmentIndex = 0
        }
        persistState()
    }

    private func resetCurrentRow() {
        guard let currentStep else { return }
        for segment in counterSegments(for: currentStep) {
            segmentCounts[segment.id] = 0
        }
        completedStepIds.remove(currentStep.id)
        currentSegmentIndex = 0
        persistState()
    }

    private func restoreState() {
        guard let initialState,
              initialState.currentComponentId == componentId,
              let stepIndex = sortedSteps.firstIndex(where: { $0.id == initialState.currentStepId }) else {
            return
        }
        currentRowIndex = stepIndex
        currentSegmentIndex = initialState.currentSegmentIndex
        segmentCounts = initialState.segmentCounts
        completedStepIds = initialState.completedStepIds
        completedComponentIds = initialState.completedComponentIds
    }

    private func persistState() {
        guard let currentStep, let componentId else { return }
        onStateChange?(
            CrochetExecutionState(
                currentComponentId: componentId,
                currentStepId: currentStep.id,
                currentSegmentIndex: currentSegmentIndex,
                segmentCounts: segmentCounts,
                completedStepIds: completedStepIds,
                completedComponentIds: completedComponentIds,
                updatedAt: Date()
            )
        )
    }

    private func segmentBackground(_ segment: CounterSegment, index: Int) -> Color {
        let color = Color(hex: segment.colorHex ?? subprojectColorHex ?? primaryColorHex, fallback: mainColor)
        if index == currentSegmentIndex { return color.opacity(0.88) }
        if segment.completed { return color.opacity(0.78) }
        return .white
    }

    private func segmentTextColor(_ segment: CounterSegment, index: Int) -> Color {
        (index == currentSegmentIndex || segment.completed) ? .white : .primary
    }

    private func progressChunkCompleted(_ index: Int) -> Bool {
        guard rowTotal > 0 else { return false }
        let threshold = Double(index + 1) / 8
        return Double(completedInRow) / Double(rowTotal) >= threshold
    }
}

private struct CounterSegment: Identifiable {
    let id: String
    let label: String
    let target: Int
    let current: Int
    var colorHex: String? = nil

    var completed: Bool {
        current >= target
    }
}

private extension Color {
    init(hex: String, fallback: Color) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard clean.count == 6, Scanner(string: clean).scanHexInt64(&value) else {
            self = fallback
            return
        }
        self = Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}

#Preview {
    NavigationStack {
        ExecutionView(steps: [
            PatternStep(
                id: UUID(),
                componentId: UUID(),
                stepIndex: 0,
                roundLabel: "R3",
                rawInstruction: "R3: 12X,8(X,V),12X (32)",
                normalizedInstruction: "12X + 8(X,V) + 12X",
                actionSegments: [
                    ActionSegment(id: UUID(), sourceText: "12X", action: .singleCrochet, count: 12, repeatCount: 1, yarnColorName: nil, yarnColorHex: nil),
                    ActionSegment(id: UUID(), sourceText: "8(X,V)", action: .singleCrochet, count: 8, repeatCount: 1, yarnColorName: nil, yarnColorHex: nil),
                    ActionSegment(id: UUID(), sourceText: "12X", action: .singleCrochet, count: 12, repeatCount: 1, yarnColorName: nil, yarnColorHex: nil)
                ],
                stitchCountTarget: 32,
                notes: nil
            )
        ])
    }
}
