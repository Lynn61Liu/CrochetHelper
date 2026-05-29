import SwiftUI
import SwiftData
import PhotosUI
import UIKit

enum AppRoute: Hashable {
    case importPattern
    case reviewImport(String)
    case projectDetail(UUID)
    case addSubproject(UUID)
    case componentEdit(UUID, UUID)
    case componentExecution(UUID, UUID)
}

private enum ProjectProgressCalculator {
    static func completionProgress(for package: CrochetProjectPackage) -> Double {
        let allStepIds = Set(package.steps.map(\.id))
        guard !allStepIds.isEmpty else { return 0 }

        var completedStepIds: Set<UUID> = []
        var completedComponentIds: Set<UUID> = []

        if let progress = package.progress {
            completedStepIds.formUnion(progress.completedStepIds)
            completedComponentIds.formUnion(progress.completedComponentIds)
        }
        if let executionState = package.executionState {
            completedStepIds.formUnion(executionState.completedStepIds)
            completedComponentIds.formUnion(executionState.completedComponentIds)
        }
        for state in package.executionStatesByComponentId.values {
            completedStepIds.formUnion(state.completedStepIds)
            completedComponentIds.formUnion(state.completedComponentIds)
        }

        for componentId in completedComponentIds {
            completedStepIds.formUnion(package.steps.filter { $0.componentId == componentId }.map(\.id))
        }

        return min(1, Double(completedStepIds.intersection(allStepIds).count) / Double(allStepIds.count))
    }
}

struct ProjectHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var toast: ToastManager
    @Query(sort: \StoredProject.updatedAt, order: .reverse) private var queriedProjects: [StoredProject]
    @State private var path = NavigationPath()
    @State private var projects: [StoredProject] = []
    @State private var editingProject: StoredProject?
    @State private var deletingProject: StoredProject?
    @State private var resettingProject: StoredProject?

    private let coverSymbols = ["photo", "shippingbox", "heart.text.square", "leaf", "star", "hare", "teddybear"]
    private var visibleProjects: [StoredProject] {
        projects.isEmpty ? queriedProjects : projects
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if visibleProjects.isEmpty {
                    ContentUnavailableView(
                        "No Crochet Projects",
                        systemImage: "square.grid.2x2",
                        description: Text("Import a tutorial image to create your first project.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(visibleProjects) { project in
                                projectCard(project)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationTitle("Projects")
            .onAppear {
                reloadProjects()
                refreshProgressFromPackages()
            }
            .onReceive(NotificationCenter.default.publisher(for: .projectStoreDidChange)) { _ in
                reloadProjects()
                refreshProgressFromPackages()
            }
            .onReceive(NotificationCenter.default.publisher(for: .subprojectRouteRequested)) { notification in
                if let route = notification.object as? AppRoute {
                    path.append(route)
                }
            }
            .onChange(of: queriedProjects.count) { _, _ in
                reloadProjects()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(AppRoute.importPattern)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Project")
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .importPattern:
                    ImportCropView()
                case .reviewImport(let sourceText):
                    ParseReviewView(sourceText: sourceText) { package in
                        returnToHomeAndConfirmSave(package)
                    }
                case .projectDetail(let projectId):
                    ProjectSubprojectsView(projectId: projectId)
                case .addSubproject(let projectId):
                    AddSubprojectView(projectId: projectId)
                case .componentEdit(let projectId, let componentId):
                    if let editable = editableComponent(projectId: projectId, componentId: componentId) {
                        StoredSubprojectStructureView(
                            component: editable.component,
                            steps: editable.steps,
                            projectColorHex: editable.projectColorHex
                        ) { title, subprojectColorHex, steps in
                            updateComponent(
                                projectId: projectId,
                                componentId: componentId,
                                title: title,
                                subprojectColorHex: subprojectColorHex,
                                steps: steps
                            )
                        }
                    } else {
                        ContentUnavailableView("Subproject Not Found", systemImage: "folder.badge.questionmark")
                    }
                case .componentExecution(let projectId, let componentId):
                    if let context = executionContext(projectId: projectId, componentId: componentId) {
                        ExecutionView(
                            steps: context.steps,
                            componentId: componentId,
                            primaryColorHex: context.primaryColorHex,
                            subprojectColorHex: context.subprojectColorHex,
                            initialState: context.package.executionStatesByComponentId[componentId.uuidString] ?? context.package.executionState,
                            onStateChange: { state in
                                saveExecutionState(state, projectId: projectId)
                            },
                            onCompleted: {
                                toast.show("Subproject complete")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    if !path.isEmpty {
                                        path.removeLast()
                                    }
                                }
                            }
                        )
                    } else {
                        ContentUnavailableView("No Steps", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .sheet(item: $editingProject) { project in
                EditProjectCardSheet(
                    project: project,
                    coverSymbols: coverSymbols,
                    onSaved: {
                        reloadProjects()
                    }
                )
            }
            .alert("Delete Project?", isPresented: Binding(
                get: { deletingProject != nil },
                set: { if !$0 { deletingProject = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let deletingProject {
                        deleteProject(deletingProject)
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .alert("Reset Project?", isPresented: Binding(
                get: { resettingProject != nil },
                set: { if !$0 { resettingProject = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    if let resettingProject {
                        resetProjectProgress(resettingProject)
                    }
                }
            } message: {
                Text("This will clear all saved row and segment progress, but keep the project and steps.")
            }
        }
    }

    @ViewBuilder
    private func projectCard(_ project: StoredProject) -> some View {
        let uiColor = UIColor(hex: project.primaryColorHex) ?? UIColor(red: 0.85, green: 0.63, blue: 0.40, alpha: 1)
        let cardColor = Color(uiColor: uiColor)
        let package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: project.packageData)
        let subprojectCount = package?.components.count ?? 0
        let stepCount = package?.steps.count ?? 0
        let progress = max(0, min(1, project.completionProgress))

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                Spacer()
                HStack(spacing: 12) {
                    Button {
                        editingProject = project
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        deletingProject = project
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(cardColor.opacity(0.18))
                    .aspectRatio(1.9, contentMode: .fit)
                if let data = project.coverImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: project.coverImageSystemName)
                        .font(.system(size: 52))
                        .foregroundStyle(cardColor)
                }
            }
            .clipped()

            VStack(alignment: .leading, spacing: 10) {
                Text("Project details")
                    .font(.headline.weight(.bold))
                HStack(spacing: 12) {
                    projectInfoPill(icon: "square.stack.3d.up", title: "\(subprojectCount)", subtitle: "Subprojects", color: cardColor)
                    projectInfoPill(icon: "list.bullet", title: "\(stepCount)", subtitle: "Rows", color: cardColor)
                }
            }

            HStack(spacing: 10) {
                ProgressView(value: progress)
                    .tint(cardColor)

                Button {
                    resettingProject = project
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(cardColor)
                        .frame(width: 40, height: 40)
                        .background(cardColor.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset Project")
            }

            Button {
                path.append(AppRoute.projectDetail(project.id))
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(cardColor, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }

    private func projectInfoPill(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func deleteProject(_ project: StoredProject) {
        modelContext.delete(project)
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .projectStoreDidChange, object: nil)
            reloadProjects()
            toast.show("Project deleted")
        } catch {
            toast.show("Delete failed")
        }
    }

    private func resetProjectProgress(_ project: StoredProject) {
        guard var package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: project.packageData) else {
            toast.show("Reset failed")
            return
        }
        package.executionState = nil
        package.executionStatesByComponentId = [:]
        package.progress = nil
        package.project.currentStepIndex = 0
        package.project.completionState = .notStarted
        package.components = package.components.map { component in
            var copy = component
            copy.completionState = .notStarted
            return copy
        }
        package.project.updatedAt = Date()

        do {
            project.packageData = try JSONEncoder.crochet.encode(package)
            project.completionProgress = 0
            project.updatedAt = package.project.updatedAt
            try modelContext.save()
            NotificationCenter.default.post(name: .projectStoreDidChange, object: nil)
            reloadProjects()
            toast.show("Project reset")
        } catch {
            toast.show("Reset failed")
        }
    }

    private func reloadProjects() {
        projects = fetchStoredProjects()
    }

    private func fetchStoredProjects() -> [StoredProject] {
        let descriptor = FetchDescriptor<StoredProject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func returnToHomeAndConfirmSave(_ package: CrochetProjectPackage) {
        path = NavigationPath()
        do {
            try SwiftDataProjectRepository(modelContext: modelContext).save(package)
            NotificationCenter.default.post(name: .projectStoreDidChange, object: nil)
            let fetched = fetchStoredProjects()
            projects = fetched
            refreshProgressFromPackages()
            let count = fetchStoredProjects().count
            let didSave = fetchStoredProjects().contains { $0.id == package.project.id }
            toast.show(didSave ? "Home refreshed: \(count) project\(count == 1 ? "" : "s")" : "Saved, but Home fetch is empty")
        } catch {
            toast.show("Save failed on Home")
        }
    }

    private func refreshProgressFromPackages() {
        reloadProjects()
        var didChange = false
        for project in projects {
            guard let package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: project.packageData) else {
                continue
            }
            let newProgress = ProjectProgressCalculator.completionProgress(for: package)
            if abs(project.completionProgress - newProgress) > 0.0001 {
                project.completionProgress = newProgress
                didChange = true
            }
        }
        if didChange {
            try? modelContext.save()
            reloadProjects()
        }
    }

    private func stepsForComponent(projectId: UUID, componentId: UUID) -> [PatternStep]? {
        guard let stored = fetchStoredProjects().first(where: { $0.id == projectId }),
              let package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: stored.packageData) else {
            return nil
        }
        return package.steps
            .filter { $0.componentId == componentId }
            .sorted { $0.stepIndex < $1.stepIndex }
    }

    private func executionContext(projectId: UUID, componentId: UUID) -> (package: CrochetProjectPackage, steps: [PatternStep], primaryColorHex: String, subprojectColorHex: String?)? {
        guard let stored = fetchStoredProjects().first(where: { $0.id == projectId }),
              var package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: stored.packageData),
              let component = package.components.first(where: { $0.id == componentId }) else {
            return nil
        }
        package = backfillMissingStepTotals(in: package, storedProject: stored)
        let steps = package.steps
            .filter { $0.componentId == componentId }
            .sorted { $0.stepIndex < $1.stepIndex }
        return (package, steps, stored.primaryColorHex, component.primaryColorHex)
    }

    private func backfillMissingStepTotals(in package: CrochetProjectPackage, storedProject: StoredProject) -> CrochetProjectPackage {
        let parser = CrochetParser()
        var updated = package
        var didChange = false

        updated.steps = updated.steps.map { step in
            guard step.stitchCountTarget == nil,
                  let total = parser.targetCount(for: step.rawInstruction) else {
                return step
            }
            var copy = step
            copy.stitchCountTarget = total
            didChange = true
            return copy
        }

        guard didChange else { return package }
        do {
            storedProject.packageData = try JSONEncoder.crochet.encode(updated)
            try modelContext.save()
            NotificationCenter.default.post(name: .projectStoreDidChange, object: nil)
        } catch {
            toast.show("Step totals update failed")
        }
        return updated
    }

    private func saveExecutionState(_ state: CrochetExecutionState, projectId: UUID) {
        guard let stored = fetchStoredProjects().first(where: { $0.id == projectId }),
              var package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: stored.packageData) else {
            return
        }
        package.executionState = state
        package.executionStatesByComponentId[state.currentComponentId.uuidString] = state
        package.progress = ProgressState(
            projectId: projectId,
            currentComponentId: state.currentComponentId,
            currentStepId: state.currentStepId,
            currentInStepStitchCount: state.segmentCounts.values.reduce(0, +),
            completedStepIds: state.completedStepIds,
            completedComponentIds: state.completedComponentIds,
            lastUpdatedAt: state.updatedAt,
            liveActivitySummary: "Row progress saved"
        )
        package.project.currentStepIndex = package.steps
            .filter { $0.componentId == state.currentComponentId }
            .sorted { $0.stepIndex < $1.stepIndex }
            .firstIndex { $0.id == state.currentStepId } ?? 0
        let aggregateProgress = ProjectProgressCalculator.completionProgress(for: package)
        package.project.completionState = aggregateProgress >= 1 ? .completed : .inProgress
        package.components = package.components.map { component in
            var copy = component
            if state.completedComponentIds.contains(component.id) {
                copy.completionState = .completed
            } else if component.id == state.currentComponentId {
                copy.completionState = .inProgress
            }
            return copy
        }
        package.project.updatedAt = state.updatedAt

        do {
            stored.packageData = try JSONEncoder.crochet.encode(package)
            stored.completionProgress = aggregateProgress
            stored.updatedAt = state.updatedAt
            try modelContext.save()
            NotificationCenter.default.post(name: .projectStoreDidChange, object: nil)
        } catch {
            toast.show("Progress save failed")
        }
    }

    private func editableComponent(projectId: UUID, componentId: UUID) -> (component: PatternComponent, steps: [PatternStep], projectColorHex: String)? {
        guard let stored = fetchStoredProjects().first(where: { $0.id == projectId }),
              let package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: stored.packageData),
              let component = package.components.first(where: { $0.id == componentId }) else {
            return nil
        }
        let steps = package.steps
            .filter { $0.componentId == componentId }
            .sorted { $0.stepIndex < $1.stepIndex }
        return (component, steps, stored.primaryColorHex)
    }

    private func updateComponent(projectId: UUID, componentId: UUID, title: String, subprojectColorHex: String?, steps: [PatternStep]) {
        guard let stored = fetchStoredProjects().first(where: { $0.id == projectId }),
              var package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: stored.packageData),
              let componentIndex = package.components.firstIndex(where: { $0.id == componentId }) else {
            toast.show("Save failed")
            return
        }

        package.components[componentIndex].name = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? package.components[componentIndex].name
            : title
        package.components[componentIndex].primaryColorHex = subprojectColorHex
        package.steps.removeAll { $0.componentId == componentId }
        package.steps.append(contentsOf: steps.enumerated().map { index, step in
            PatternStep(
                id: step.id,
                componentId: componentId,
                stepIndex: index,
                roundLabel: step.roundLabel,
                rawInstruction: step.rawInstruction,
                normalizedInstruction: step.normalizedInstruction,
                actionSegments: step.actionSegments,
                stitchCountTarget: step.stitchCountTarget,
                notes: step.notes
            )
        })
        package.project.updatedAt = Date()

        do {
            stored.packageData = try JSONEncoder.crochet.encode(package)
            stored.updatedAt = package.project.updatedAt
            try modelContext.save()
            NotificationCenter.default.post(name: .projectStoreDidChange, object: nil)
            reloadProjects()
            toast.show("Subproject updated")
        } catch {
            toast.show("Save failed")
        }
    }
}

extension Notification.Name {
    static let projectStoreDidChange = Notification.Name("projectStoreDidChange")
    static let subprojectRouteRequested = Notification.Name("subprojectRouteRequested")
}

private struct EditProjectCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var toast: ToastManager

    let project: StoredProject
    let coverSymbols: [String]
    let onSaved: () -> Void

    @State private var title: String = ""
    @State private var coverImageSystemName: String = "photo"
    @State private var selectedColor: Color = Color(red: 0.85, green: 0.63, blue: 0.40)
    @State private var selectedCoverPickerItem: PhotosPickerItem?
    @State private var selectedCoverImageData: Data?
    @State private var cropScale: CGFloat = 1
    @State private var cropOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            Form {
                Section("Card Info") {
                    TextField("Title", text: $title)
                    PhotosPicker(selection: $selectedCoverPickerItem, matching: .images) {
                        Label("Choose Cover from Photos", systemImage: "photo.on.rectangle")
                    }
                    Picker("Image", selection: $coverImageSystemName) {
                        ForEach(coverSymbols, id: \.self) { symbol in
                            HStack {
                                Image(systemName: symbol)
                                Text(symbol)
                            }.tag(symbol)
                        }
                    }
                    ColorPicker("Primary Color", selection: $selectedColor)
                }

                if let data = selectedCoverImageData, let previewImage = UIImage(data: data) {
                    Section("Crop Cover") {
                        ImageCropPreview(
                            image: previewImage,
                            scale: $cropScale,
                            offset: $cropOffset
                        )
                        Button("Reset Crop") {
                            cropScale = 1
                            cropOffset = .zero
                        }
                        .frame(minHeight: 48)
                    }
                }
            }
            .navigationTitle("Edit Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                title = project.name
                coverImageSystemName = project.coverImageSystemName
                selectedColor = Color(uiColor: UIColor(hex: project.primaryColorHex) ?? UIColor(red: 0.85, green: 0.63, blue: 0.40, alpha: 1))
                selectedCoverImageData = project.coverImageData
            }
            .onChange(of: selectedCoverPickerItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            selectedCoverImageData = data
                            cropScale = 1
                            cropOffset = .zero
                        }
                    }
                }
            }
        }
    }

    private func save() {
        let finalName = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Project" : title
        project.name = finalName
        project.coverImageSystemName = coverImageSystemName
        project.coverImageData = croppedCoverImageData() ?? selectedCoverImageData
        project.primaryColorHex = UIColor(selectedColor).toHexString() ?? "#D9A066"
        project.updatedAt = Date()
        if var package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: project.packageData) {
            package.project.name = finalName
            package.project.updatedAt = project.updatedAt
            if let encoded = try? JSONEncoder.crochet.encode(package) {
                project.packageData = encoded
            }
        }
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .projectStoreDidChange, object: nil)
            onSaved()
            toast.show("Project updated")
            dismiss()
        } catch {
            toast.show("Save failed")
        }
    }

    private func croppedCoverImageData() -> Data? {
        guard let selectedCoverImageData,
              let image = UIImage(data: selectedCoverImageData),
              let cropped = image.croppedSquare(
                displaySize: ImageCropPreview.cropSize,
                scale: cropScale,
                offset: cropOffset,
                outputSize: 900
              ) else {
            return nil
        }
        return cropped.jpegData(compressionQuality: 0.9)
    }
}

private struct ImageCropPreview: View {
    static let cropSize: CGFloat = 260

    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    @State private var lastScale: CGFloat = 1
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Color(.systemGray6)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.cropSize, height: Self.cropSize)
                    .scaleEffect(scale)
                    .offset(offset)
            }
            .frame(width: Self.cropSize, height: Self.cropSize)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white, lineWidth: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value, 1), 4)
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
            )

            Text("Drag to position. Pinch to zoom.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            lastScale = scale
            lastOffset = offset
        }
    }
}

private extension UIColor {
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let int = Int(cleaned, radix: 16) else { return nil }
        let r = CGFloat((int >> 16) & 0xff) / 255
        let g = CGFloat((int >> 8) & 0xff) / 255
        let b = CGFloat(int & 0xff) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    func toHexString() -> String? {
        guard let comps = cgColor.components else { return nil }
        let r = Int((comps[safe: 0] ?? 0) * 255)
        let g = Int((comps[safe: 1] ?? 0) * 255)
        let b = Int((comps[safe: 2] ?? 0) * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

private extension UIImage {
    func croppedSquare(displaySize: CGFloat, scale userScale: CGFloat, offset: CGSize, outputSize: CGFloat) -> UIImage? {
        let normalized = normalizedForCropping()
        guard let cgImage = normalized.cgImage else { return nil }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let baseScale = max(displaySize / imageSize.width, displaySize / imageSize.height)
        let effectiveScale = max(baseScale * max(userScale, 1), 0.0001)
        let cropSide = min(imageSize.width, imageSize.height, displaySize / effectiveScale)
        let center = CGPoint(
            x: imageSize.width / 2 - offset.width / effectiveScale,
            y: imageSize.height / 2 - offset.height / effectiveScale
        )
        let origin = CGPoint(
            x: min(max(center.x - cropSide / 2, 0), imageSize.width - cropSide),
            y: min(max(center.y - cropSide / 2, 0), imageSize.height - cropSide)
        )
        let cropRect = CGRect(origin: origin, size: CGSize(width: cropSide, height: cropSide)).integral

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }
        let cropped = UIImage(cgImage: croppedCGImage)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize), format: format).image { _ in
            cropped.draw(in: CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
        }
    }

    func normalizedForCropping() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
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

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct ProjectSubprojectsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var toast: ToastManager
    @State private var storedProject: StoredProject?
    @State private var package: CrochetProjectPackage?
    @State private var deletingComponent: PatternComponent?

    let projectId: UUID

    var body: some View {
        List {
            if let package {
                Section("Subprojects") {
                    ForEach(package.components.sorted { $0.displayOrder < $1.displayOrder }) { component in
                        subprojectCard(component, package: package)
                    }
                }

                Section {
                    NavigationLink(value: AppRoute.addSubproject(projectId)) {
                        Label("Add Subproject", systemImage: "plus.circle")
                            .frame(minHeight: 48)
                    }
                }
            } else {
                ContentUnavailableView("Project Not Found", systemImage: "folder.badge.questionmark")
            }
        }
        .navigationTitle(package?.project.name ?? "Subprojects")
        .onAppear(perform: load)
        .onReceive(NotificationCenter.default.publisher(for: .projectStoreDidChange)) { _ in
            load()
        }
        .alert("Delete Subproject?", isPresented: Binding(
            get: { deletingComponent != nil },
            set: { if !$0 { deletingComponent = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let deletingComponent {
                    deleteComponent(deletingComponent)
                }
            }
        } message: {
            Text("This will remove the subproject and its steps.")
        }
    }

    private func subprojectCard(_ component: PatternComponent, package: CrochetProjectPackage) -> some View {
        let progress = progress(for: component, in: package)
        let subColor = Color(hex: component.primaryColorHex ?? storedProject?.primaryColorHex ?? "#D9A066", fallback: Color(red: 0.85, green: 0.63, blue: 0.40))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(subColor)
                            .frame(width: 12, height: 12)
                        Text(component.name)
                            .font(.headline)
                    }
                    Text("\(stepCount(for: component, in: package)) steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 14) {
                    Button {
                        NotificationCenter.default.post(
                            name: .subprojectRouteRequested,
                            object: AppRoute.componentExecution(projectId, component.id)
                        )
                    } label: {
                        Image(systemName: "play.circle")
                    }
                    .buttonStyle(.plain)

                    Button {
                        NotificationCenter.default.post(
                            name: .subprojectRouteRequested,
                            object: AppRoute.componentEdit(projectId, component.id)
                        )
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        deletingComponent = component
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ProgressView(value: progress)
                    .tint(subColor)

                Text("\(Int(progress * 100))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button {
                    resetComponentProgress(component)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(subColor)
                        .frame(width: 36, height: 36)
                        .background(subColor.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset Subproject")
            }
        }
        .padding(.vertical, 6)
    }

    private func load() {
        let descriptor = FetchDescriptor<StoredProject>(
            predicate: #Predicate { $0.id == projectId }
        )
        storedProject = try? modelContext.fetch(descriptor).first
        if let storedProject {
            package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: storedProject.packageData)
        }
    }

    private func stepCount(for component: PatternComponent, in package: CrochetProjectPackage) -> Int {
        package.steps.filter { $0.componentId == component.id }.count
    }

    private func progress(for component: PatternComponent, in package: CrochetProjectPackage) -> Double {
        let steps = package.steps.filter { $0.componentId == component.id }
        guard !steps.isEmpty else { return 0 }
        let state = package.executionStatesByComponentId[component.id.uuidString]
        if state?.completedComponentIds.contains(component.id) == true ||
            package.progress?.completedComponentIds.contains(component.id) == true {
            return 1
        }
        let completed = state?.completedStepIds ?? package.progress?.completedStepIds ?? []
        return Double(steps.filter { completed.contains($0.id) }.count) / Double(steps.count)
    }

    private func deleteComponent(_ component: PatternComponent) {
        guard var package, let storedProject else { return }
        package.components.removeAll { $0.id == component.id }
        package.steps.removeAll { $0.componentId == component.id }
        package.project.componentOrder.removeAll { $0 == component.id }
        package.components = package.components
            .sorted { $0.displayOrder < $1.displayOrder }
            .enumerated()
            .map { index, component in
                var copy = component
                copy.displayOrder = index
                return copy
            }
        save(package, into: storedProject, successMessage: "Subproject deleted")
    }

    private func resetComponentProgress(_ component: PatternComponent) {
        guard var package, let storedProject else { return }
        package.executionStatesByComponentId.removeValue(forKey: component.id.uuidString)
        if package.executionState?.currentComponentId == component.id {
            package.executionState = nil
        }
        package.progress?.completedComponentIds.remove(component.id)
        let stepIds = Set(package.steps.filter { $0.componentId == component.id }.map(\.id))
        package.progress?.completedStepIds.subtract(stepIds)
        save(package, into: storedProject, successMessage: "Subproject reset")
    }

    private func save(_ package: CrochetProjectPackage, into storedProject: StoredProject, successMessage: String) {
        var updated = package
        updated.project.updatedAt = Date()
        do {
            storedProject.packageData = try JSONEncoder.crochet.encode(updated)
            storedProject.completionProgress = ProjectProgressCalculator.completionProgress(for: updated)
            storedProject.updatedAt = updated.project.updatedAt
            try modelContext.save()
            self.package = updated
            NotificationCenter.default.post(name: .projectStoreDidChange, object: nil)
            toast.show(successMessage)
        } catch {
            toast.show("Save failed")
        }
    }
}

private struct AddSubprojectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toast: ToastManager

    @State private var selectedItem: PhotosPickerItem?
    @State private var sourceText = ""
    @State private var isRecognizing = false

    let projectId: UUID

    private let ocrService: OCRServicing = VisionOCRService()

    var body: some View {
        Form {
            Section("Import") {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Choose Image", systemImage: "photo")
                        .frame(minHeight: 48)
                }

                if isRecognizing {
                    HStack {
                        ProgressView()
                        Text("Recognizing text...")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                TextEditor(text: $sourceText)
                    .frame(minHeight: 220)
            } footer: {
                Text("First line is the subproject title. Remaining lines are steps.")
            }

            Section {
                Button("Save Subproject") {
                    saveSubproject()
                }
                .disabled(parsedSubprojects().isEmpty)
                .frame(minHeight: 48)
            }
        }
        .navigationTitle("Add Subproject")
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await recognizeText(from: newValue)
            }
        }
    }

    @MainActor
    private func recognizeText(from item: PhotosPickerItem) async {
        isRecognizing = true
        defer { isRecognizing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                toast.show("Image load failed")
                return
            }
            let text = try await ocrService.recognizeText(in: image)
            sourceText = text
            toast.show(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No text detected" : "Text recognized")
        } catch {
            toast.show("OCR failed")
        }
    }

    private func parsedSubprojects() -> [(title: String, stepLines: [String])] {
        let blocks = sourceText
            .components(separatedBy: .newlines)
            .reduce(into: [[String]]()) { blocks, line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    if blocks.last?.isEmpty == false {
                        blocks.append([])
                    }
                } else {
                    if blocks.isEmpty {
                        blocks.append([])
                    }
                    blocks[blocks.count - 1].append(trimmed)
                }
            }
            .filter { !$0.isEmpty }

        return blocks.compactMap { block in
            guard block.count >= 2 else { return nil }
            return (title: block[0], stepLines: Array(block.dropFirst()))
        }
    }

    private func saveSubproject() {
        let parsedSubprojects = parsedSubprojects()
        guard !parsedSubprojects.isEmpty else {
            toast.show("Add title and steps first")
            return
        }

        let descriptor = FetchDescriptor<StoredProject>(
            predicate: #Predicate { $0.id == projectId }
        )
        guard let storedProject = try? modelContext.fetch(descriptor).first,
              var package = try? JSONDecoder.crochet.decode(CrochetProjectPackage.self, from: storedProject.packageData) else {
            toast.show("Project not found")
            return
        }

        let parser = CrochetParser()
        for parsed in parsedSubprojects {
            let componentId = UUID()
            let order = package.components.count
            let component = PatternComponent(
                id: componentId,
                projectId: projectId,
                name: parsed.title,
                type: .crochetPart,
                sourceRegionId: nil,
                displayOrder: order,
                completionState: .notStarted
            )
            let steps = parsed.stepLines
                .joined(separator: "\n")
                .homeLogicalStepLines()
                .flatMap { $0.homeExpandRangeIfNeeded() }
                .enumerated()
                .map { index, line in
                    parser.parseStep(line, componentId: componentId, stepIndex: index)
                }

            package.components.append(component)
            package.project.componentOrder.append(componentId)
            package.steps.append(contentsOf: steps)
        }
        package.project.updatedAt = Date()

        do {
            storedProject.packageData = try JSONEncoder.crochet.encode(package)
            storedProject.completionProgress = ProjectProgressCalculator.completionProgress(for: package)
            storedProject.updatedAt = package.project.updatedAt
            try modelContext.save()
            NotificationCenter.default.post(name: .projectStoreDidChange, object: nil)
            toast.show(parsedSubprojects.count == 1 ? "Subproject added" : "\(parsedSubprojects.count) subprojects added")
            dismiss()
        } catch {
            toast.show("Save failed")
        }
    }
}

private extension String {
    var homeIsRoundLine: Bool {
        range(of: #"^\s*(R\d+|第\d+圈)\s*[:：]?"#, options: .regularExpression) != nil
    }

    func homeLogicalStepLines() -> [String] {
        let rawLines = components(separatedBy: .newlines)
        var lines: [String] = []
        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.homeIsRoundLine || lines.isEmpty {
                lines.append(trimmed)
            } else {
                lines[lines.count - 1] += trimmed.hasPrefix(",") ? trimmed : ",\(trimmed)"
            }
        }
        return lines
    }

    func homeExpandRangeIfNeeded() -> [String] {
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

#Preview {
    ProjectHomeView()
}
