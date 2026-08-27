import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var settingsWindow: NSWindow?

    var isSettingsWindowVisible: Bool {
        settingsWindow?.isVisible == true
    }

    func showSettings(for store: UsageStore) {
        let rootView = SettingsView().environmentObject(store)
        let window: NSWindow

        if let settingsWindow {
            settingsWindow.contentViewController = NSHostingController(rootView: rootView)
            window = settingsWindow
        } else {
            let created = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 390),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            created.title = "CodexMeter Settings"
            created.isReleasedWhenClosed = false
            created.contentViewController = NSHostingController(rootView: rootView)
            created.delegate = self
            if !created.setFrameUsingName("CodexMeterSettingsWindow") {
                created.center()
            }
            created.setFrameAutosaveName("CodexMeterSettingsWindow")
            settingsWindow = created
            window = created
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

#if DEBUG
    func closeSettingsForTesting() {
        settingsWindow?.close()
    }
#endif
}
