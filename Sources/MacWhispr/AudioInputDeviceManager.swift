import AVFoundation
import CoreAudio
import Foundation

struct AudioInputOption: Equatable { let id: String; let name: String }

enum AudioInputDeviceManager {
    static let systemDefault = AudioInputOption(id: "", name: "System Default")
    static var preferredID: String {
        get { UserDefaults.standard.string(forKey: "preferredInputDeviceUID") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "preferredInputDeviceUID") }
    }
    static func availableInputs() -> [AudioInputOption] {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .externalUnknown], mediaType: .audio, position: .unspecified)
        return [systemDefault] + session.devices.map { AudioInputOption(id: $0.uniqueID, name: $0.localizedName) }
    }
    static var currentName: String { availableInputs().first { $0.id == preferredID }?.name ?? "System Default" }
    @discardableResult static func applyPreferredDevice() -> Bool {
        guard !preferredID.isEmpty else { return true }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return false }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return false }
        for id in ids {
            var uidAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var uid: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &uidSize, &uid) == noErr, let deviceUID = uid?.takeUnretainedValue() as String? else { continue }
            if deviceUID == preferredID {
                var chosen = id
                var defaultAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
                return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &chosen) == noErr
            }
        }
        return false
    }
}
