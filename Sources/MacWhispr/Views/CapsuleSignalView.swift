import SwiftUI

@MainActor
struct CapsuleSignalView: View {
    @ObservedObject var state: DictationCapsuleState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: state.reduceMotion)) { context in
            SignalDrawing(
                level: state.level,
                processing: state.phase == .transcribing ? 1 : 0,
                elapsed: state.reduceMotion ? 0 : max(0, context.date.timeIntervalSince(state.phaseStartedAt)),
                reduceMotion: state.reduceMotion,
                tint: state.phase.tint
            )
            .animation(state.reduceMotion ? nil : .easeOut(duration: 0.14), value: state.phase)
            .animation(state.reduceMotion ? nil : .linear(duration: 0.05), value: state.level)
        }
    }
}

private struct SignalDrawing: View, Animatable {
    var level: Double
    var processing: Double
    let elapsed: Double
    let reduceMotion: Bool
    let tint: Color

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, processing) }
        set { level = newValue.first; processing = newValue.second }
    }

    var body: some View {
        Canvas { context, size in
            let blend = min(1, max(0, processing))
            // Baseline bars mean ready to listen; their height comes from actual audio.
            if blend < 1 {
                for index in 0..<18 {
                    let position = Double(index) / 17
                    let envelope = 0.3 + 0.7 * sin(position * .pi)
                    let ripple = reduceMotion ? 0.8 : 0.65 + 0.35 * sin(elapsed * 12 - Double(index) * 0.62)
                    let height = (2.5 + 21 * level * envelope * ripple) * (1 - blend) + 1.5 * blend
                    let x = position * (size.width - 2.3)
                    let rect = CGRect(x: x, y: (size.height - height) / 2, width: 2.3, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1.15), with: .color(tint.opacity(0.85 * (1 - blend))))
                }
            }

            // Short independent strokes repeat; this is activity, not estimated progress.
            if blend > 0 {
                for lane in 0..<3 {
                    let y = size.height * Double(lane + 1) / 4
                    let track = CGRect(x: 0, y: y - 0.65, width: size.width, height: 1.3)
                    context.fill(Path(roundedRect: track, cornerRadius: 0.65), with: .color(tint.opacity(0.09 * blend)))

                    let cycle = (elapsed / 0.72 + Double(lane) * 0.19).truncatingRemainder(dividingBy: 1)
                    let head = reduceMotion ? size.width * (0.55 + Double(lane) * 0.18) : cycle * (size.width + 26)
                    let start = max(0, head - 26)
                    let end = min(size.width, head + 2)
                    guard end > start else { continue }
                    let stroke = CGRect(x: start, y: y - 1, width: end - start, height: 2)
                    let gradient = Gradient(stops: [
                        .init(color: tint.opacity(0.05 * blend), location: 0),
                        .init(color: tint.opacity(0.75 * blend), location: 0.65),
                        .init(color: Color.white.opacity(0.95 * blend), location: 1)
                    ])
                    context.fill(Path(roundedRect: stroke, cornerRadius: 1), with: .linearGradient(gradient, startPoint: CGPoint(x: start, y: y), endPoint: CGPoint(x: end, y: y)))
                }
            }
        }
    }
}
