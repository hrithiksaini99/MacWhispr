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
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let level = recorder.peakPower(forChannel: 0)
            self.peak = max(self.peak, level)
            self.onLevel?(level)
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func stop() -> (URL, Float)? {
        timer?.invalidate(); timer = nil
        recorder?.stop(); recorder = nil
        guard let url = recordingURL else { return nil }
        recordingURL = nil
        return (url, peak)
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
