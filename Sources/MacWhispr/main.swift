import AppKit
import AVFoundation
import ApplicationServices
import Carbon
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = Logger(subsystem: "dev.macwhispr.app", category: "Dictation")
    private let menu = MenuBarController()
    private let audio = DictationService()
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var busy = false
    private var recording = false
    private var activeApp: NSRunningApplication?
    private let hotKeyID = EventHotKeyID(signature: 0x4D575350, id: 1)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menu.onToggle = { [weak self] in self?.toggle() }
        menu.onMode = { [weak self] mode in ActivationMode.current = mode; self?.menu.refresh() }
        menu.onDevice = { [weak self] id in AudioInputDeviceManager.preferredID = id; self?.menu.refresh() }
        menu.onModel = { [weak self] model in self?.select(model) }
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in DispatchQueue.main.async { self.menu.refresh() } }
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        installHotKey()
        if !ModelManager.isInstalled(ModelManager.selected) { menu.state = "Download a model" }
    }
    private func installHotKey() {
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)), EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            let app = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr, id.signature == app.hotKeyID.signature, id.id == app.hotKeyID.id else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { app.handleHotKey(pressed: GetEventKind(event) == UInt32(kEventHotKeyPressed)) }
            return noErr
        }
        let status = InstallEventHandler(GetApplicationEventTarget(), callback, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        guard status == noErr else { fail("Could not install the hotkey handler."); return }
        let registration = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKey)
        guard registration == noErr else { fail("Control–Space could not be registered. Change the conflicting system shortcut in Keyboard Settings."); return }
        logger.info("Control-Space hotkey registered")
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
        do { try audio.start(); recording = true; menu.recording = true; menu.state = "Recording"; logger.info("Recording started"); NSSound(named: "Tink")?.play() }
        catch { fail(error.localizedDescription) }
    }
    private func stop() {
        guard recording, let (url, peak) = audio.stop() else { return }
        recording = false; menu.recording = false; busy = true; menu.state = "Transcribing"
        logger.info("Recording stopped; transcription started")
        NSSound(named: "Pop")?.play()
        let model = ModelManager.selected
        Task {
            defer { try? FileManager.default.removeItem(at: url); busy = false }
            do {
                guard peak > -50 else { throw MacWhisprError("No speech detected from \(AudioInputDeviceManager.currentName). Check your microphone and try again.") }
                let text = try await Transcriber.transcribe(audio: url, model: model)
                activeApp?.activate(options: [])
                try? await Task.sleep(nanoseconds: 120_000_000)
                try PasteService.paste(text)
                print(text)
                menu.state = "Ready"
            } catch { fail(error.localizedDescription) }
        }
    }
    private func select(_ model: WhisperModel) {
        if ModelManager.isInstalled(model) { ModelManager.selected = model; menu.state = "Ready"; menu.refresh(); return }
        guard !menu.downloading else { return }
        menu.downloading = true; menu.downloadProgress = 0; menu.state = "Downloading \(model.name)"
        Task { [self] in
            do {
                try await ModelManager.download(model) { fraction in DispatchQueue.main.async { self.menu.downloadProgress = fraction } }
                ModelManager.selected = model; menu.state = "Ready"
            } catch { fail(error.localizedDescription) }
            menu.downloading = false; menu.refresh()
        }
    }
    private func fail(_ message: String) {
        menu.state = "Action required"
        logger.error("Action required: \(message, privacy: .public)")
        fputs("MacWhispr: \(message)\n", stderr)
        let notice = UNMutableNotificationContent(); notice.title = "MacWhispr"; notice.body = message; notice.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: notice, trigger: nil)) { [weak self] error in
            if error != nil { DispatchQueue.main.async { self?.showAlert(message) } }
        }
    }
    private func showAlert(_ message: String) { NSApp.activate(ignoringOtherApps: true); let alert = NSAlert(); alert.messageText = "MacWhispr"; alert.informativeText = message; alert.runModal() }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
    func applicationWillTerminate(_ notification: Notification) { if let hotKey { UnregisterEventHotKey(hotKey) }; if let eventHandler { RemoveEventHandler(eventHandler) }; _ = audio.stop() }
}

import UserNotifications
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
