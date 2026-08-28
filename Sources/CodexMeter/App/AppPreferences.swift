import Foundation

enum AppPreferences {
    static let defaultMenuBarDisplay = MenuBarDisplay.total.rawValue
    static let defaultShowMenuBarIcon = true
    static let defaultShowMenuBarText = false
    static let defaultProfileSyncEnabled = false
    private static let legacyIconOnlyDisplay = "iconOnly"

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(
            defaults: [
                "menuBarDisplay": defaultMenuBarDisplay,
                "showMenuBarIcon": defaultShowMenuBarIcon,
                "showMenuBarText": defaultShowMenuBarText,
                "profileSyncEnabled": defaultProfileSyncEnabled
            ]
        )
        migrateLegacyIconOnlyPreference(in: defaults)
    }

    static func shouldShowMenuBarIcon(
        display _: String,
        showIcon: Bool,
        showText: Bool
    ) -> Bool {
        showIcon || !showText
    }

    static func shouldShowMenuBarText(
        display _: String,
        showText: Bool,
        text: String
    ) -> Bool {
        showText && !text.isEmpty
    }

    private static func migrateLegacyIconOnlyPreference(in defaults: UserDefaults) {
        guard defaults.string(forKey: "menuBarDisplay") == legacyIconOnlyDisplay else { return }
        defaults.set(MenuBarDisplay.total.rawValue, forKey: "menuBarDisplay")
        defaults.set(true, forKey: "showMenuBarIcon")
        defaults.set(false, forKey: "showMenuBarText")
    }
}
