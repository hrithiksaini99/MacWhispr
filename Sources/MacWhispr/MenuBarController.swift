import AppKit
import AVFoundation
import ApplicationServices

final class MenuBarController: NSObject, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var onToggle: (() -> Void)?
    var onMode: ((ActivationMode) -> Void)?
    var onModel: ((WhisperModel) -> Void)?
    var onDevice: ((String) -> Void)?
    var onDownload: ((WhisperModel) -> Void)?
    var state = "Ready" { didSet { refresh() } }
    var recording = false { didSet { refresh() } }
    var downloading = false { didSet { refresh() } }
    var downloadProgress: Double = 0 { didSet { refresh() } }

    override init() {
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "MacWhispr")
        statusItem.button?.image?.isTemplate = true
        let menu = NSMenu(); menu.delegate = self; statusItem.menu = menu
        refresh()
    }
    func menuWillOpen(_ menu: NSMenu) { refresh() }
    func refresh() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        statusItem.button?.title = downloading ? " \(Int(downloadProgress * 100))%" : ""
        statusItem.button?.image = NSImage(systemSymbolName: recording ? "waveform.circle.fill" : "waveform", accessibilityDescription: state)
        menu.addItem(NSMenuItem(title: "Status: \(state)", action: nil, keyEquivalent: ""))
        let toggle = NSMenuItem(title: recording ? "Stop Dictation" : "Start Dictation", action: #selector(toggleAction), keyEquivalent: "")
        toggle.target = self; toggle.isEnabled = !downloading && state != "Transcribing"
        menu.addItem(toggle)
        menu.addItem(.separator())
        let modes = NSMenu()
        for mode in ActivationMode.allCases {
            let item = NSMenuItem(title: mode.label, action: #selector(modeAction(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = mode.rawValue; item.state = mode == .current ? .on : .off; modes.addItem(item)
        }
        let modeItem = NSMenuItem(title: "Activation Mode", action: nil, keyEquivalent: "")
        modeItem.submenu = modes; menu.addItem(modeItem)
        let devices = NSMenu()
        for device in AudioInputDeviceManager.availableInputs() {
            let item = NSMenuItem(title: device.name, action: #selector(deviceAction(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = device.id; item.state = device.id == AudioInputDeviceManager.preferredID ? .on : .off; devices.addItem(item)
        }
        let deviceItem = NSMenuItem(title: "Input Device: \(AudioInputDeviceManager.currentName)", action: nil, keyEquivalent: "")
        deviceItem.submenu = devices; menu.addItem(deviceItem)
        let models = NSMenu()
        for model in WhisperModel.all {
            let installed = ModelManager.isInstalled(model)
            let item = NSMenuItem(title: "\(model.name) — \(installed ? "Installed" : "\(model.sizeMB) MB, Download")", action: #selector(modelAction(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = model.id; item.toolTip = model.note; item.state = model == ModelManager.selected ? .on : .off; item.isEnabled = !downloading; models.addItem(item)
        }
        let modelItem = NSMenuItem(title: "Model: \(ModelManager.selected.name)", action: nil, keyEquivalent: "")
        modelItem.submenu = models; menu.addItem(modelItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Microphone: \(AVCaptureDevice.authorizationStatus(for: .audio) == .authorized ? "Granted" : "Required")", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Accessibility: \(AXIsProcessTrusted() ? "Granted" : "Required")", action: nil, keyEquivalent: ""))
        let mic = NSMenuItem(title: "Open Microphone Settings", action: #selector(openMicrophone), keyEquivalent: ""); mic.target = self; menu.addItem(mic)
        let access = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibility), keyEquivalent: ""); access.target = self; menu.addItem(access)
        let folder = NSMenuItem(title: "Open Model Folder", action: #selector(openFolder), keyEquivalent: ""); folder.target = self; menu.addItem(folder)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MacWhispr", action: #selector(quitAction), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
    }
    @objc private func toggleAction() { onToggle?() }
    @objc private func modeAction(_ sender: NSMenuItem) { guard let raw = sender.representedObject as? String, let mode = ActivationMode(rawValue: raw) else { return }; onMode?(mode) }
    @objc private func modelAction(_ sender: NSMenuItem) { guard let id = sender.representedObject as? String, let model = WhisperModel.all.first(where: { $0.id == id }) else { return }; onModel?(model) }
    @objc private func deviceAction(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { onDevice?(id) } }
    @objc private func openMicrophone() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }
    @objc private func openAccessibility() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }
    @objc private func openFolder() { try? FileManager.default.createDirectory(at: ModelManager.directory, withIntermediateDirectories: true); NSWorkspace.shared.open(ModelManager.directory) }
    @objc private func quitAction() { NSApp.terminate(nil) }
}
