import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private static let frameAutosaveName = "CodexMeterSettingsWindowV2"
    private static let minimumContentSize = NSSize(width: 840, height: 560)
    private static let defaultContentSize = NSSize(width: 980, height: 680)

    private var settingsWindow: NSWindow?

    var isSettingsWindowVisible: Bool {
        settingsWindow?.isVisible == true
    }

    func showSettings(for store: UsageStore, limitStore: AccountLimitStore) {
        let window: NSWindow

        if let settingsWindow {
            window = settingsWindow
        } else {
            let created = NSWindow(
                contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            created.title = "CodexMeter Settings"
            created.contentMinSize = Self.minimumContentSize
            created.isReleasedWhenClosed = false
            created.contentViewController = NSHostingController(
                rootView: SettingsView()
                    .environmentObject(store)
                    .environmentObject(limitStore)
            )
            created.delegate = self
            if !created.setFrameUsingName(Self.frameAutosaveName) {
                created.center()
            }
            created.setFrameAutosaveName(Self.frameAutosaveName)
            settingsWindow = created
            window = created
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

#if DEBUG
    var settingsWindowContentSizeForTesting: NSSize? {
        settingsWindow?.contentView?.bounds.size
    }

    var settingsWindowIsResizableForTesting: Bool {
        settingsWindow?.styleMask.contains(.resizable) ?? false
    }

    var settingsWindowMinimumContentSizeForTesting: NSSize? {
        settingsWindow?.contentMinSize
    }

    var settingsContentViewControllerForTesting: NSViewController? {
        settingsWindow?.contentViewController
    }

    func closeSettingsForTesting() {
        settingsWindow?.close()
    }
#endif
}
