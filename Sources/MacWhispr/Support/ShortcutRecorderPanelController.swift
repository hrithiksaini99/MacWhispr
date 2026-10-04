import AppKit
import Carbon

@MainActor
final class ShortcutRecorderPanelController: NSWindowController, NSWindowDelegate {
    var onApply: ((HotKeyShortcut) -> Result<Void, Error>)?
    var onDismiss: (() -> Void)?
    private let recorder = ShortcutRecorderButton(frame: .zero)
    private let status = NSTextField(labelWithString: "")

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 228),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.init(window: panel)
        panel.title = "Recording Shortcut"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.delegate = self
        configureContent()
    }

    func present() {
        guard let window else { return }
        recorder.shortcut = .current
        recorder.isRecording = true
        status.stringValue = "Press a shortcut using Command, Option, or Control."
        status.textColor = .secondaryLabelColor
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(recorder)
    }

    private func configureContent() {
        guard let window else { return }
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        let title = NSTextField(labelWithString: "Choose your recording shortcut")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.alignment = .center

        let detail = NSTextField(wrappingLabelWithString: "The shortcut works from any app. Press Escape to cancel.")
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        detail.alignment = .center

        recorder.shortcut = .current
        recorder.target = self
        recorder.action = #selector(capturedShortcut(_:))
        recorder.setAccessibilityLabel("Record a new dictation shortcut")

        status.font = .systemFont(ofSize: 11)
        status.alignment = .center
        status.lineBreakMode = .byTruncatingTail

        let reset = NSButton(title: "Use Control–Space", target: self, action: #selector(resetShortcut))
        reset.bezelStyle = .inline
        reset.font = .systemFont(ofSize: 11)

        let stack = NSStackView(views: [title, detail, recorder, status, reset])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -32),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: 8),
            recorder.widthAnchor.constraint(equalToConstant: 210),
            recorder.heightAnchor.constraint(equalToConstant: 44),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func capturedShortcut(_ sender: ShortcutRecorderButton) {
        guard let shortcut = sender.shortcut else { return }
        apply(shortcut)
    }

    @objc private func resetShortcut() { apply(.defaultShortcut) }

    private func apply(_ shortcut: HotKeyShortcut) {
        switch onApply?(shortcut) ?? .failure(ShortcutRegistrationError.unavailable) {
        case .success:
            recorder.shortcut = shortcut
            window?.close()
        case .failure:
            recorder.isRecording = true
            status.stringValue = "That shortcut is already in use. Try another combination."
            status.textColor = .systemOrange
            window?.makeFirstResponder(recorder)
        }
    }

    func windowWillClose(_ notification: Notification) { onDismiss?() }
}

private final class ShortcutRecorderButton: NSButton {
    var shortcut: HotKeyShortcut? { didSet { updateTitle() } }
    var isRecording = false { didSet { updateTitle() } }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        font = .monospacedSystemFont(ofSize: 18, weight: .medium)
        focusRingType = .exterior
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            window?.close()
            return
        }
        guard let value = HotKeyShortcut.from(event: event) else {
            NSSound.beep()
            return
        }
        shortcut = value
        isRecording = false
        _ = sendAction(action, to: target)
    }

    private func updateTitle() {
        title = isRecording ? "Type shortcut…" : (shortcut?.displayName ?? "Set shortcut")
    }
}

enum ShortcutRegistrationError: LocalizedError {
    case unavailable
    var errorDescription: String? { "The shortcut could not be registered." }
}
