import Foundation

enum ActivationMode: String, CaseIterable {
    case toggle, pushToTalk
    static var current: Self {
        get { Self(rawValue: UserDefaults.standard.string(forKey: "activationMode") ?? "toggle") ?? .toggle }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "activationMode") }
    }
    var label: String { self == .toggle ? "Toggle" : "Push to Talk" }
}
