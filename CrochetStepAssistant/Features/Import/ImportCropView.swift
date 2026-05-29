import PhotosUI
import SwiftUI
import UIKit

struct ImportCropView: View {
    @EnvironmentObject private var toast: ToastManager
    var onProjectCreated: ((UUID) -> Void)?
    @State private var selectedItem: PhotosPickerItem?
    @State private var sourceText = ""
    @State private var isRecognizing = false
    @State private var recognitionError: String?

    private let ocrService: OCRServicing = VisionOCRService()

    var body: some View {
        Form {
            Section("Image") {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Choose Tutorial Image", systemImage: "photo")
                }

                if isRecognizing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Recognizing text...")
                            .foregroundStyle(.secondary)
                    }
                } else if let recognitionError {
                    Text(recognitionError)
                        .foregroundStyle(.red)
                } else {
                    Text("Crop controls will appear here after image selection.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Extracted Text") {
                TextEditor(text: $sourceText)
                    .frame(minHeight: 180)
            }

            NavigationLink(value: AppRoute.reviewImport(sourceText)) {
                Text("Review Parsed Steps")
            }
            .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("Import")
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await recognizeText(from: newItem)
            }
        }
    }

    @MainActor
    private func recognizeText(from item: PhotosPickerItem) async {
        isRecognizing = true
        recognitionError = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                recognitionError = "Failed to load selected image data."
                isRecognizing = false
                return
            }
            guard let image = UIImage(data: data) else {
                recognitionError = "Selected file is not a valid image."
                isRecognizing = false
                return
            }

            let text = try await ocrService.recognizeText(in: image)
            sourceText = text
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recognitionError = "No text detected in this image."
                toast.show("No text detected")
            } else {
                toast.show("Text recognized")
            }
        } catch {
            recognitionError = "OCR failed: \(error.localizedDescription)"
            toast.show("OCR failed")
        }

        isRecognizing = false
    }
}

#Preview {
    NavigationStack {
        ImportCropView()
    }
}
