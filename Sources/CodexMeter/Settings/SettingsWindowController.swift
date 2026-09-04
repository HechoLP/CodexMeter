import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private static let frameAutosaveName = "CodexMeterSettingsWindowV2"
    private static let minimumContentSize = NSSize(width: 840, height: 560)
    private static let defaultContentSize = NSSize(width: 980, height: 680)

    private var settingsWindow: NSWindow?
    private var environment: SettingsEnvironment?

    var isSettingsWindowVisible: Bool {
        settingsWindow?.isVisible == true
    }

    /// Wired once at launch from `CodexMeterApp` with the app's real stores.
    func configure(environment: SettingsEnvironment) {
        self.environment = environment
    }

    func present() {
        let environment = self.environment ?? SettingsEnvironment()
        let window = settingsWindow ?? makeWindow(environment: environment)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(environment: SettingsEnvironment) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CodexMeter Settings"
        window.contentMinSize = Self.minimumContentSize
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: SettingsView(onPaneTitleChange: { [weak window] title in
                window?.title = title
            })
            .environmentObject(environment)
            .environmentObject(environment.claude)
        )
        window.delegate = self
        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)
        settingsWindow = window
        return window
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
