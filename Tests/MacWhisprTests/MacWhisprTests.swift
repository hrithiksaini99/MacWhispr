import XCTest
import Carbon
@testable import MacWhispr

final class MacWhisprTests: XCTestCase {
    func testModelCatalogHasUniqueIDsAndFilenames() {
        XCTAssertEqual(Set(WhisperModel.all.map(\.id)).count, WhisperModel.all.count)
        XCTAssertEqual(Set(WhisperModel.all.map(\.filename)).count, WhisperModel.all.count)
        XCTAssertTrue(WhisperModel.all.allSatisfy { $0.filename.hasPrefix("ggml-") && $0.filename.hasSuffix(".bin") })
    }
    func testModePersistence() {
        let previous = ActivationMode.current
        defer { ActivationMode.current = previous }
        ActivationMode.current = .pushToTalk
        XCTAssertEqual(ActivationMode.current, .pushToTalk)
        ActivationMode.current = .toggle
        XCTAssertEqual(ActivationMode.current, .toggle)
    }

    func testShortcutPersistenceAndDisplay() {
        let previous = HotKeyShortcut.current
        defer { HotKeyShortcut.current = previous }
        let shortcut = HotKeyShortcut(keyCode: 49, modifiers: UInt32(controlKey | optionKey), keyLabel: "Space")
        HotKeyShortcut.current = shortcut
        XCTAssertEqual(HotKeyShortcut.current, shortcut)
        XCTAssertEqual(shortcut.displayName, "⌃⌥Space")
    }
}
