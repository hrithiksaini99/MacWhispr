import AppKit
import Carbon
import Foundation

struct HotKeyShortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    static let defaultShortcut = HotKeyShortcut(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey),
        keyLabel: "Space"
    )

    private static let keyCodeKey = "recordingShortcutKeyCode"
    private static let modifiersKey = "recordingShortcutModifiers"
    private static let labelKey = "recordingShortcutLabel"

    static var current: HotKeyShortcut {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: keyCodeKey) != nil,
                  defaults.object(forKey: modifiersKey) != nil,
                  let label = defaults.string(forKey: labelKey),
                  !label.isEmpty else { return .defaultShortcut }
            return HotKeyShortcut(
                keyCode: UInt32(defaults.integer(forKey: keyCodeKey)),
                modifiers: UInt32(defaults.integer(forKey: modifiersKey)),
                keyLabel: label
            )
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(Int(newValue.keyCode), forKey: keyCodeKey)
            defaults.set(Int(newValue.modifiers), forKey: modifiersKey)
            defaults.set(newValue.keyLabel, forKey: labelKey)
        }
    }

    var displayName: String {
        var value = ""
        if modifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        return value + keyLabel
    }

    static func from(event: NSEvent) -> HotKeyShortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbonModifiers: UInt32 = 0
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

        // A global shortcut needs a primary modifier to avoid stealing normal typing.
        let primary = UInt32(controlKey | optionKey | cmdKey)
        guard carbonModifiers & primary != 0,
              let label = label(for: event),
              !modifierOnlyKeyCodes.contains(event.keyCode) else { return nil }
        return HotKeyShortcut(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers, keyLabel: label)
    }

    private static let modifierOnlyKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    private static func label(for event: NSEvent) -> String? {
        let named: [UInt16: String] = [
            UInt16(kVK_Space): "Space", UInt16(kVK_Return): "Return", UInt16(kVK_Tab): "Tab",
            UInt16(kVK_Delete): "Delete", UInt16(kVK_ForwardDelete): "Forward Delete",
            UInt16(kVK_Escape): "Escape", UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→",
            UInt16(kVK_UpArrow): "↑", UInt16(kVK_DownArrow): "↓", UInt16(kVK_Home): "Home",
            UInt16(kVK_End): "End", UInt16(kVK_PageUp): "Page Up", UInt16(kVK_PageDown): "Page Down",
            UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3", UInt16(kVK_F4): "F4",
            UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6", UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8",
            UInt16(kVK_F9): "F9", UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
            UInt16(kVK_F13): "F13", UInt16(kVK_F14): "F14", UInt16(kVK_F15): "F15",
            UInt16(kVK_F16): "F16", UInt16(kVK_F17): "F17", UInt16(kVK_F18): "F18", UInt16(kVK_F19): "F19"
        ]
        if let value = named[event.keyCode] { return value }
        let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !characters.isEmpty else { return nil }
        return characters.uppercased()
    }
}
