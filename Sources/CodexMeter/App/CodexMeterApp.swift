import AppKit
import SwiftUI

/*
 THESIS: Codex usage should read like a quiet macOS instrument, not a web dashboard squeezed into the menu bar.
 OWN-WORLD: System materials, semantic labels, hairline separators, tabular numerals, and one diamond meter mark.
 STORY: Launch, see today's total, click once for its composition and nearby periods, then return to work.
 FIRST VIEWPORT: A 320-point popover leads with today's total, follows with input/cached/output rows, then week/month/all-time links and a compact status footer.
 FORM: Native macOS utility, selected from the binding product brief; code-first session with no decorative visual comp.
 FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
*/
@main
struct CodexMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: UsageStore
    @AppStorage("menuBarDisplay") private var menuBarDisplay = AppPreferences.defaultMenuBarDisplay
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = AppPreferences.defaultShowMenuBarIcon
    @AppStorage("showMenuBarText") private var showMenuBarText = AppPreferences.defaultShowMenuBarText

    init() {
        AppPreferences.registerDefaults()
        let store = UsageStore()
        _store = StateObject(wrappedValue: store)
        Task { @MainActor [weak store] in
            await store?.refresh()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPopoverView()
                .environmentObject(store)
        } label: {
            HStack(spacing: 4) {
                if resolvedShowIcon {
                    Image(systemName: "diamond")
                        .accessibilityHidden(true)
                }
                if resolvedShowText {
                    Text(store.menuBarText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 220)
                }
            }
                .accessibilityLabel(store.menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }

    private var resolvedShowIcon: Bool {
        AppPreferences.shouldShowMenuBarIcon(
            display: menuBarDisplay,
            showIcon: showMenuBarIcon,
            showText: showMenuBarText
        )
    }

    private var resolvedShowText: Bool {
        AppPreferences.shouldShowMenuBarText(
            display: menuBarDisplay,
            showText: showMenuBarText,
            text: store.menuBarText
        )
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
