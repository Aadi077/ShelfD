import AppKit
import ShelfDCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @State private var launchError: String?
    @State private var selectedApp: String?

    var body: some View {
        Form {
            Section {
                Toggle("Open ShelfD at login", isOn: Binding(
                    get: { preferences.launchAtLogin },
                    set: { enabled in
                        do {
                            try preferences.setLaunchAtLogin(enabled)
                            launchError = nil
                        } catch {
                            launchError = error.localizedDescription
                        }
                    }
                ))
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                Picker("Shake sensitivity", selection: $preferences.sensitivity) {
                    ForEach(ShakeSensitivity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Gentle opens a shelf with a small wiggle. Firm needs a longer, wider shake.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                if preferences.excludedApps.isEmpty {
                    Text("No excluded apps").foregroundStyle(.secondary)
                } else {
                    List(preferences.excludedApps, id: \.self, selection: $selectedApp) { id in
                        AppRow(bundleID: id)
                    }
                    .frame(minHeight: 90)
                }
                HStack {
                    Button("Add App…", action: addApp)
                    Button("Remove") {
                        preferences.excludedApps.removeAll { $0 == selectedApp }
                        selectedApp = nil
                    }
                    .disabled(selectedApp == nil)
                }
            } header: {
                Text("Excluded apps")
            } footer: {
                Text("Shaking while dragging from these apps won't open a shelf.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !preferences.excludedApps.contains(id) {
                preferences.excludedApps.append(id)
            }
        }
    }
}

private struct AppRow: View {
    let bundleID: String

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        HStack {
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable().frame(width: 18, height: 18)
            }
            Text(url.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID)
        }
    }
}

/// Shows the settings window, bringing ShelfD forward since it has no Dock icon.
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(preferences: .shared)))
            window.title = "ShelfD Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
