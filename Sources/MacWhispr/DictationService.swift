import AppKit
import AVFoundation
import ApplicationServices
import Foundation

final class DictationService: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private(set) var peak: Float = -160
    private(set) var recordingURL: URL?
    var onSilence: (() -> Void)?
    var onLevel: ((Float) -> Void)?

    func start() throws {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { throw MacWhisprError("Microphone access is required. Open System Settings → Privacy & Security → Microphone.") }
        guard AudioInputDeviceManager.applyPreferredDevice() else { throw MacWhisprError("Selected microphone is unavailable. Choose another input device.") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("macwhispr-\(UUID().uuidString).wav")
        let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatLinearPCM), AVSampleRateKey: 16000.0, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.record() else { throw MacWhisprError("Could not start the microphone. Check the selected input device.") }
        self.recorder = recorder
        recordingURL = url
        peak = -160
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let level = recorder.peakPower(forChannel: 0)
            self.peak = max(self.peak, level)
            self.onLevel?(level)
        }
    }
    func stop() -> (URL, Float)? {
        timer?.invalidate(); timer = nil
        recorder?.stop(); recorder = nil
        guard let url = recordingURL else { return nil }
        recordingURL = nil
        return (url, peak)
    }
}

enum Transcriber {
    static func binaryURL() -> URL? {
        let env = ProcessInfo.processInfo.environment["MACWHISPR_WHISPER"]
        let candidates = [env, "/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli"].compactMap { $0 }
        return candidates.map(URL.init(fileURLWithPath:)).first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
    static func transcribe(audio: URL, model: WhisperModel) async throws -> String {
        guard let binary = binaryURL() else { throw MacWhisprError("whisper-cli is missing. Install it with: brew install whisper.cpp") }
        guard ModelManager.isInstalled(model) else { throw MacWhisprError("Download the selected model from the menu first.") }
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let output = Pipe(); let errors = Pipe()
            process.executableURL = binary
            process.arguments = ["-m", ModelManager.url(for: model).path, "-f", audio.path, "-nt", "-np"]
            process.standardOutput = output; process.standardError = errors
            try process.run()
            let stdout = output.fileHandleForReading.readDataToEndOfFile()
            let stderr = errors.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw MacWhisprError("Transcription failed: \(String(data: stderr, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error")") }
            let text = (String(data: stdout, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw MacWhisprError("No speech was recognized. Try speaking closer to the microphone.") }
            return text
        }.value
    }
}

enum PasteService {
    static func paste(_ text: String) throws {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        guard AXIsProcessTrusted() else { throw MacWhisprError("Transcription copied. Enable MacWhispr in System Settings → Privacy & Security → Accessibility to paste automatically.") }
        guard let source = CGEventSource(stateID: .hidSystemState), let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true), let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { throw MacWhisprError("Transcription copied, but paste could not be sent.") }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
    }
}
