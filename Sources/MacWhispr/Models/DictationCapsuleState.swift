import SwiftUI

enum CapsulePhase: Equatable {
    case hidden, listening, transcribing, pasted, failed

    var title: String {
        switch self {
        case .hidden: return ""
        case .listening: return "Listening"
        case .transcribing: return "Transcribing"
        case .pasted: return "Pasted"
        case .failed: return "Action required"
        }
    }

    var subtitle: String {
        switch self {
        case .listening: return "Microphone active"
        case .transcribing: return "Processing on your Mac"
        case .pasted: return "Text inserted"
        case .failed: return "Check the notification"
        case .hidden: return ""
        }
    }

    var tint: Color {
        switch self {
        case .listening, .pasted: return Color(red: 0.48, green: 0.96, blue: 0.78)
        case .transcribing: return Color(red: 0.63, green: 0.88, blue: 1)
        case .failed: return Color(red: 1, green: 0.72, blue: 0.42)
        case .hidden: return .clear
        }
    }
}

@MainActor
final class DictationCapsuleState: ObservableObject {
    @Published var phase: CapsulePhase = .hidden
    @Published var level: Double = 0
    @Published var reduceMotion = false
    @Published var shortcutDisplayName = HotKeyShortcut.current.displayName
    @Published private(set) var phaseStartedAt = Date()

    func transition(to phase: CapsulePhase) {
        // Preserve the last sample so the voice trace can collapse into processing.
        if phase == .listening || phase == .hidden { level = 0 }
        phaseStartedAt = Date()
        self.phase = phase
    }

    func updateLevel(_ decibels: Float) {
        guard phase == .listening else { return }
        let normalized = decibels.isFinite ? min(1, max(0, (Double(decibels) + 55) / 50)) : 0
        level = max(pow(normalized, 1.3), level * 0.78)
    }
}
