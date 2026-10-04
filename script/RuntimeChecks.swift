import Foundation
import Carbon

@main
struct RuntimeChecks {
    static func require(_ value: Bool, _ message: String) throws {
        if !value { throw MacWhisprError(message) }
    }
    static func main() async throws {
        let shell = URL(fileURLWithPath: "/bin/sh")
        let text = try TranscriptionProcess().run(executable: shell, arguments: ["-c", "head -c 262144 /dev/zero >&2; printf 'verified words'"], timeout: 5)
        try require(text == "verified words", "Diagnostics contaminated stdout or blocked execution")
        print("PASS: large stderr cannot block transcript output")
        do {
            _ = try TranscriptionProcess().run(executable: shell, arguments: ["-c", "printf 'specific engine failure' >&2; exit 7"], timeout: 5)
            throw MacWhisprError("Expected failure")
        } catch let error as MacWhisprError {
            try require(error.message.contains("specific engine failure"), "Exit diagnostics were lost")
        }
        print("PASS: nonzero exit retains bounded diagnostic output")
        let start = Date()
        do {
            _ = try TranscriptionProcess().run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"], timeout: 0.1)
            throw MacWhisprError("Expected timeout")
        } catch let error as MacWhisprError {
            try require(error.message.contains("too long"), "Timeout was not classified")
        }
        try require(Date().timeIntervalSince(start) < 4, "Timed out process did not terminate")
        print("PASS: deadline terminates the owned process")
        let runner = TranscriptionProcess()
        let task = Task.detached { try runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"], timeout: 5) }
        try await Task.sleep(nanoseconds: 100_000_000)
        runner.cancel()
        do { _ = try await task.value; throw MacWhisprError("Expected cancellation") }
        catch is CancellationError {}
        print("PASS: cancellation terminates the owned process")
        let cancelled = TranscriptionProcess()
        cancelled.cancel()
        do { _ = try cancelled.run(executable: shell, arguments: ["-c", "exit 0"], timeout: 5); throw MacWhisprError("Expected cancellation before launch") }
        catch is CancellationError {}
        print("PASS: cancellation before launch is honored")
        try require(WhisperModel.all.map(\.id).count == Set(WhisperModel.all.map(\.id)).count, "Duplicate model identifiers")
        print("PASS: model catalog identifiers are unique")
        let shortcut = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(controlKey | optionKey), keyLabel: "R")
        try require(shortcut.displayName == "⌃⌥R", "Shortcut display order is incorrect")
        let previousShortcut = HotKeyShortcut.current
        HotKeyShortcut.current = shortcut
        try require(HotKeyShortcut.current == shortcut, "Shortcut did not persist")
        HotKeyShortcut.current = previousShortcut
        print("PASS: personalized shortcut persists and renders consistently")
        print("7 runtime checks passed")
    }
}
