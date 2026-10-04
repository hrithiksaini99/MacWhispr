import Darwin
import Foundation

enum Transcriber {
    static func binaryURL() -> URL? {
        let env = ProcessInfo.processInfo.environment["MACWHISPR_WHISPER"]
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/whisper-cli").path
        let candidates = [env, bundled, "/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli"].compactMap { $0 }
        return candidates.map(URL.init(fileURLWithPath:)).first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func transcribe(audio: URL, model: WhisperModel) async throws -> String {
        guard let binary = binaryURL() else { throw MacWhisprError("The speech engine is missing. Reinstall MacWhispr, or install whisper.cpp for a source build.") }
        guard ModelManager.isInstalled(model) else { throw MacWhisprError("Download the selected model from the menu first.") }
        let language = model.id.hasSuffix(".en") ? "en" : "auto"
        let args = ["-m", ModelManager.url(for: model).path, "-f", audio.path, "-l", language, "-nt", "-np"]
        let size = (try? audio.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let seconds = Double(size) / 32_000
        let runner = TranscriptionProcess()
        let worker = Task.detached(priority: .userInitiated) {
            try runner.run(executable: binary, arguments: args, timeout: max(120, min(1800, seconds * 20 + 60)))
        }
        return try await withTaskCancellationHandler(operation: {
            let text = try await worker.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw MacWhisprError("No speech was recognized. Try speaking closer to the microphone.") }
            return text
        }, onCancel: { runner.cancel() })
    }
}

// Disk-backed output avoids pipe deadlocks when a backend writes verbose diagnostics.
// One runner owns exactly one process; the lock serializes launch and cancellation.
final class TranscriptionProcess: @unchecked Sendable {
    private let process = Process()
    private let lock = NSLock()
    private var cancelled = false
    private var timedOut = false

    func run(executable: URL, arguments: [String], timeout: TimeInterval) throws -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("macwhispr-process-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let outputURL = directory.appendingPathComponent("stdout")
        let errorURL = directory.appendingPathComponent("stderr")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600]),
              FileManager.default.createFile(atPath: errorURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw MacWhisprError("Could not create transcription output files.")
        }
        let output = try FileHandle(forWritingTo: outputURL)
        let errors = try FileHandle(forWritingTo: errorURL)
        defer { try? output.close(); try? errors.close() }
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        lock.lock()
        if cancelled { lock.unlock(); throw CancellationError() }
        do { try process.run() } catch { lock.unlock(); throw error }
        lock.unlock()

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + max(0.05, timeout))
        timer.setEventHandler { [weak self] in self?.stop(timedOut: true) }
        timer.resume()
        defer { timer.cancel() }
        process.waitUntilExit()
        lock.lock()
        let didCancel = cancelled
        let didTimeOut = timedOut
        lock.unlock()
        if didCancel { throw CancellationError() }
        if didTimeOut { throw MacWhisprError("Transcription took too long. Try a shorter recording or a smaller model.") }
        guard process.terminationStatus == 0 else {
            let handle = try FileHandle(forReadingFrom: errorURL)
            defer { try? handle.close() }
            let count = try handle.seekToEnd()
            try handle.seek(toOffset: count > 16_384 ? count - 16_384 : 0)
            let data = try handle.readToEnd() ?? Data()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Speech engine exited unexpectedly."
            throw MacWhisprError("Transcription failed: \(message)")
        }
        return try String(contentsOf: outputURL, encoding: .utf8)
    }

    func cancel() { stop(timedOut: false) }

    private func stop(timedOut: Bool) {
        lock.lock()
        if timedOut {
            guard process.isRunning else { lock.unlock(); return }
            self.timedOut = true
        } else { cancelled = true }
        if process.isRunning { process.terminate() }
        lock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) { [self] in
            lock.lock()
            defer { lock.unlock() }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }
}
