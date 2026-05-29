import SwiftUI
import SwiftData

@main
struct CrochetStepAssistantApp: App {
    @StateObject private var toast = ToastManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ProjectHomeView()
                AppToastOverlay()
            }
            .environmentObject(toast)
        }
        .modelContainer(for: StoredProject.self)
    }
}

@MainActor
final class ToastManager: ObservableObject {
    @Published var message: String?

    func show(_ text: String, duration: TimeInterval = 3) {
        message = text
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.message = nil
                }
            }
        }
    }
}

struct AppToastOverlay: View {
    @EnvironmentObject private var toast: ToastManager

    var body: some View {
        VStack {
            if let message = toast.message {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.2), value: toast.message)
    }
}
