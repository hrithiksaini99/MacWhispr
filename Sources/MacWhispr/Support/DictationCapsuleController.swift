import AppKit
import SwiftUI

private final class CapsulePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class DictationCapsuleController: NSObject {
    let state = DictationCapsuleState()
    var onStop: (() -> Void)?
    private var panel: CapsulePanel?
    private var dismissal: Task<Void, Never>?
    private var screen: NSScreen?

    override init() {
        super.init()
        updateAccessibility()
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateAccessibility), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    func show(_ phase: CapsulePhase) {
        dismissal?.cancel()
        dismissal = nil
        if panel == nil { createPanel() }
        if phase == .listening || screen == nil {
            screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        }
        state.transition(to: phase)
        positionPanel()
        guard let panel else { return }
        // Recording feedback is visible on the first frame, without an entry fade.
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        if phase == .pasted { dismiss(after: 0.85) }
        if phase == .failed { dismiss(after: 4) }
    }

    func hide() {
        dismissal?.cancel()
        dismissal = nil
        state.transition(to: .hidden)
        panel?.orderOut(nil)
    }

    func updateLevel(_ decibels: Float) { state.updateLevel(decibels) }
    func updateShortcut(_ shortcut: HotKeyShortcut) { state.shortcutDisplayName = shortcut.displayName }

    private func createPanel() {
        let panel = CapsulePanel(contentRect: NSRect(x: 0, y: 0, width: CapsuleLayout.panelWidth, height: CapsuleLayout.panelHeight), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "MacWhispr Dictation"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: DictationCapsuleView(state: state, onStop: { [weak self] in self?.onStop?() }, onDismiss: { [weak self] in self?.hide() }))
        self.panel = panel
    }

    private func positionPanel() {
        guard let panel, let screen = screen ?? NSScreen.main else { return }
        let bounds = screen.visibleFrame
        let x = min(max(bounds.minX, bounds.midX - panel.frame.width / 2), bounds.maxX - panel.frame.width)
        panel.setFrameOrigin(NSPoint(x: x, y: bounds.minY + 12))
    }

    private func dismiss(after seconds: Double) {
        dismissal = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            catch { return }
            self?.hide()
        }
    }

    @objc private func displaysChanged() {
        if let screen, !NSScreen.screens.contains(screen) { self.screen = NSScreen.main }
        positionPanel()
    }

    @objc private func updateAccessibility() {
        state.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    deinit {
        dismissal?.cancel()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
