import SwiftUI

enum CapsuleLayout {
    static let width: CGFloat = 336
    static let height: CGFloat = 64
    static let inset: CGFloat = 20
    static let panelWidth = width + inset * 2
    static let panelHeight = height + inset * 2
}

@MainActor
struct DictationCapsuleView: View {
    @ObservedObject var state: DictationCapsuleState
    let onStop: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            WhisprMark()
                .stroke(state.phase.tint, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                .frame(width: 26, height: 26)
                .shadow(color: state.phase.tint.opacity(0.25), radius: 5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("MACWHISPR")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Color.white.opacity(0.48))
                    Circle()
                        .fill(state.phase.tint)
                        .frame(width: 3, height: 3)
                }
                Text(state.phase.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color(red: 0.93, green: 0.97, blue: 0.98))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            signal
                .frame(width: 92, height: 30)
                .background(Color(red: 0.035, green: 0.075, blue: 0.085), in: Capsule())
                .overlay { Capsule().strokeBorder(state.phase.tint.opacity(0.12), lineWidth: 0.7) }
                .accessibilityHidden(true)

            control
                .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 18)
        .frame(width: CapsuleLayout.width, height: CapsuleLayout.height)
        .background {
            Capsule()
                .fill(LinearGradient(colors: [
                    Color(red: 0.095, green: 0.14, blue: 0.16),
                    Color(red: 0.04, green: 0.065, blue: 0.08)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .leading) {
                    Ellipse()
                        .fill(state.phase.tint.opacity(0.08))
                        .frame(width: 68, height: 50)
                        .blur(radius: 15)
                }
                .clipShape(Capsule())
        }
        .overlay {
            Capsule().strokeBorder(LinearGradient(colors: [
                Color.white.opacity(0.22),
                Color.white.opacity(0.035),
                state.phase.tint.opacity(0.2)
            ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(LinearGradient(colors: [.clear, .white.opacity(0.16), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: 168, height: 0.7)
                .padding(.top, 0.6)
        }
        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
        .padding(CapsuleLayout.inset)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("MacWhispr \(state.phase.title). \(state.phase.subtitle)")
        .animation(state.reduceMotion ? nil : .easeOut(duration: 0.14), value: state.phase)
    }

    @ViewBuilder
    private var signal: some View {
        switch state.phase {
        case .listening, .transcribing:
            CapsuleSignalView(state: state)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
        case .pasted:
            HStack(spacing: 5) {
                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                Text("INSERTED").font(.system(size: 8, weight: .semibold)).tracking(0.9)
            }
            .foregroundStyle(state.phase.tint)
        case .failed:
            Text("CHECK ALERT")
                .font(.system(size: 7, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(state.phase.tint)
        case .hidden:
            EmptyView()
        }
    }

    @ViewBuilder
    private var control: some View {
        switch state.phase {
        case .listening:
            CapsuleControl(symbol: "stop.fill", label: "Finish dictation", help: "Finish dictation · \(state.shortcutDisplayName)", reduceMotion: state.reduceMotion, action: onStop)
        case .failed:
            CapsuleControl(symbol: "xmark", label: "Dismiss status", help: "Dismiss", reduceMotion: state.reduceMotion, action: onDismiss)
        case .transcribing:
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(state.phase.tint.opacity(0.5))
                .accessibilityHidden(true)
        case .pasted:
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(state.phase.tint)
                .accessibilityHidden(true)
        case .hidden:
            EmptyView()
        }
    }
}

private struct WhisprMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.width * 0.27, y: rect.height * 0.76))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.23))
        path.addLine(to: CGPoint(x: rect.width * 0.73, y: rect.height * 0.76))
        path.addLine(to: CGPoint(x: rect.width * 0.92, y: rect.height * 0.3))
        return path
    }
}

// The alias selects the property wrapper on SDKs that also declare a State macro.
private typealias CapsuleHoverState = SwiftUI.State<Bool>

private struct CapsuleControl: View {
    let symbol: String
    let label: String
    let help: String
    let reduceMotion: Bool
    let action: () -> Void
    @CapsuleHoverState private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(hovered ? 1 : 0.78))
                .frame(width: 28, height: 28)
                .background(.white.opacity(hovered ? 0.14 : 0.055), in: Circle())
                .overlay { Circle().strokeBorder(.white.opacity(hovered ? 0.22 : 0.09), lineWidth: 0.7) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: hovered)
        .help(help)
        .accessibilityLabel(label)
    }
}
