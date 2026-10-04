import AppKit
import AVFoundation
import ApplicationServices
import Carbon
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = Logger(subsystem: "dev.macwhispr.app", category: "Dictation")
    private let menu = MenuBarController()
    private let audio = DictationService()
    private let capsule = DictationCapsuleController()
    private let shortcutPanel = ShortcutRecorderPanelController()
    private var previewTimer: Timer?
    private var transcriptionTask: Task<Void, Never>?
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var busy = false
    private var recording = false
    private var activeApp: NSRunningApplication?
    private let hotKeyID = EventHotKeyID(signature: 0x4D575350, id: 1)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if ProcessInfo.processInfo.arguments.contains("--preview-shortcut") {
            shortcutPanel.onApply = { _ in .success(()) }
            shortcutPanel.present()
            return
        }
        if let phase = previewPhase {
            previewCapsule(phase)
            return
        }
        menu.onToggle = { [weak self] in self?.toggle() }
        menu.onMode = { [weak self] mode in ActivationMode.current = mode; self?.menu.refresh() }
        menu.onShortcut = { [weak self] in self?.beginShortcutCapture() }
        menu.onDevice = { [weak self] id in AudioInputDeviceManager.preferredID = id; self?.menu.refresh() }
        menu.onModel = { [weak self] model in self?.select(model) }
        capsule.onStop = { [weak self] in self?.stop() }
        audio.onLevel = { [weak self] level in self?.capsule.updateLevel(level) }
        shortcutPanel.onApply = { [weak self] shortcut in
            self?.registerHotKey(shortcut, persist: true) ?? .failure(ShortcutRegistrationError.unavailable)
        }
        shortcutPanel.onDismiss = { [weak self] in
            guard let self, self.hotKey == nil else { return }
            _ = self.registerHotKey(.current, persist: false)
        }
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in DispatchQueue.main.async { self.menu.refresh() } }
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        installHotKeyHandler()
        if case .failure = registerHotKey(.current, persist: false) {
            HotKeyShortcut.current = .defaultShortcut
            if case .failure = registerHotKey(.defaultShortcut, persist: false) {
                fail("The recording shortcut could not be registered. Choose another shortcut from the MacWhispr menu.")
            }
        }
        if !ModelManager.isInstalled(ModelManager.selected) { menu.state = "Download a model" }
    }
    private func installHotKeyHandler() {
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)), EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            let app = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr, id.signature == 0x4D575350, id.id == 1 else { return OSStatus(eventNotHandledErr) }
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            DispatchQueue.main.async { app.handleHotKey(pressed: pressed) }
            return noErr
        }
        let status = InstallEventHandler(GetApplicationEventTarget(), callback, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        if status != noErr { fail("Could not install the shortcut handler.") }
    }

    private func registerHotKey(_ shortcut: HotKeyShortcut, persist: Bool) -> Result<Void, Error> {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else { return .failure(ShortcutRegistrationError.unavailable) }
        hotKey = reference
        if persist { HotKeyShortcut.current = shortcut }
        menu.shortcut = shortcut
        capsule.updateShortcut(shortcut)
        logger.info("Recording shortcut registered: \(shortcut.displayName, privacy: .public)")
        return .success(())
    }

    private func beginShortcutCapture() {
        guard !recording && !busy else { return }
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        shortcutPanel.present()
    }
    private func handleHotKey(pressed: Bool) {
        logger.info("Hotkey \(pressed ? "pressed" : "released", privacy: .public)")
        if ActivationMode.current == .toggle {
            if pressed { toggle() }
        } else if pressed {
            if !recording { start() }
        } else if recording { stop() }
    }
    private func toggle() { recording ? stop() : start() }
    private func start() {
        guard !busy else { return }
        guard ModelManager.isInstalled(ModelManager.selected) else { fail("Select a model in the menu to download it before dictating."); return }
        guard Transcriber.binaryURL() != nil else { fail("Install whisper.cpp with: brew install whisper.cpp"); return }
        activeApp = NSWorkspace.shared.frontmostApplication
        do {
            try audio.start()
            recording = true
            menu.recording = true
            menu.state = "Recording"
            capsule.show(.listening)
            logger.info("Recording started")
            NSSound(named: "Tink")?.play()
        }
        catch { fail(error.localizedDescription) }
    }
    private func stop() {
        guard recording, let (url, peak) = audio.stop() else { return }
        recording = false; menu.recording = false; busy = true; menu.state = "Transcribing"
        capsule.show(.transcribing)
        logger.info("Recording stopped; transcription started")
        NSSound(named: "Pop")?.play()
        let model = ModelManager.selected
        transcriptionTask = Task {
            defer { try? FileManager.default.removeItem(at: url); busy = false; transcriptionTask = nil }
            do {
                guard peak > -50 else { throw MacWhisprError("No speech detected from \(AudioInputDeviceManager.currentName). Check your microphone and try again.") }
                let text = try await Transcriber.transcribe(audio: url, model: model)
                activeApp?.activate(options: [])
                try? await Task.sleep(nanoseconds: 120_000_000)
                try PasteService.paste(text)
                menu.state = "Ready"
                capsule.show(.pasted)
            } catch is CancellationError {
                // Quitting cancels the owned engine without an error notification.
            } catch { fail(error.localizedDescription) }
        }
    }
    private func select(_ model: WhisperModel) {
        if ModelManager.isInstalled(model) {
            ModelManager.selected = model
            if !recording && !busy { menu.state = "Ready" }
            menu.refresh()
            return
        }
        guard !menu.downloading else { return }
        menu.downloading = true; menu.downloadProgress = 0; menu.state = "Downloading \(model.name)"
        Task { [self] in
            do {
                try await ModelManager.download(model) { fraction in DispatchQueue.main.async { self.menu.downloadProgress = fraction } }
                ModelManager.selected = model
                if !recording && !busy { menu.state = "Ready" }
            } catch { fail(error.localizedDescription, showCapsule: false) }
            menu.downloading = false; menu.refresh()
        }
    }
    private func fail(_ message: String, showCapsule: Bool = true) {
        menu.state = "Action required"
        if showCapsule { capsule.show(.failed) }
        logger.error("Action required: \(message, privacy: .public)")
        fputs("MacWhispr: \(message)\n", stderr)
        let notice = UNMutableNotificationContent(); notice.title = "MacWhispr"; notice.body = message; notice.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: notice, trigger: nil)) { [weak self] error in
            if error != nil { DispatchQueue.main.async { self?.showAlert(message) } }
        }
    }
    private func showAlert(_ message: String) { NSApp.activate(ignoringOtherApps: true); let alert = NSAlert(); alert.messageText = "MacWhispr"; alert.informativeText = message; alert.runModal() }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
    func applicationWillTerminate(_ notification: Notification) {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        if let (url, _) = audio.stop() { try? FileManager.default.removeItem(at: url) }
        previewTimer?.invalidate()
        transcriptionTask?.cancel()
        capsule.hide()
    }

    private var previewPhase: CapsulePhase? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--preview-recording") { return .listening }
        if args.contains("--preview-transcribing") { return .transcribing }
        return nil
    }

    // Visual development preview: no microphone, inference, or paste is performed.
    private func previewCapsule(_ phase: CapsulePhase) {
        if ProcessInfo.processInfo.arguments.contains("--preview-reduce-motion") {
            capsule.state.reduceMotion = true
        }
        capsule.show(phase)
        capsule.onStop = { [weak self] in
            self?.previewTimer?.invalidate()
            self?.capsule.show(.transcribing)
        }
        if phase == .listening {
            previewTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                let level = Float(-28 + 19 * sin(Date.timeIntervalSinceReferenceDate * 2.3))
                Task { @MainActor in self?.capsule.updateLevel(level) }
            }
            RunLoop.main.add(previewTimer!, forMode: .common)
        }
    }
}

import UserNotifications
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    withExtendedLifetime(delegate) { application.run() }
}
