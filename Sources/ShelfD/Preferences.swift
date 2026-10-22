import AppKit
import Combine
import ServiceManagement
import ShelfDCore

/// User settings, stored in UserDefaults.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    @Published var sensitivity: ShakeSensitivity {
        didSet { defaults.set(sensitivity.rawValue, forKey: "sensitivity") }
    }

    /// Bundle identifiers of apps in which a shake never opens a shelf.
    @Published var excludedApps: [String] {
        didSet { defaults.set(excludedApps, forKey: "excludedApps") }
    }

    private init() {
        sensitivity = ShakeSensitivity(rawValue: defaults.string(forKey: "sensitivity") ?? "") ?? .normal
        excludedApps = defaults.stringArray(forKey: "excludedApps") ?? []
    }

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        objectWillChange.send()
    }

    func isExcluded(_ app: NSRunningApplication?) -> Bool {
        guard let id = app?.bundleIdentifier else { return false }
        return excludedApps.contains(id)
    }
}
