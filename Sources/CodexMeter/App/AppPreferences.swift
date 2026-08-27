import Foundation

enum AppPreferences {
    static let defaultMenuBarDisplay = MenuBarDisplay.iconOnly.rawValue
    static let defaultShowMenuBarIcon = true
    static let defaultShowMenuBarText = false

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(
            defaults: [
                "menuBarDisplay": defaultMenuBarDisplay,
                "showMenuBarIcon": defaultShowMenuBarIcon,
                "showMenuBarText": defaultShowMenuBarText
            ]
        )
    }

    static func shouldShowMenuBarIcon(
        display: String,
        showIcon: Bool,
        showText: Bool
    ) -> Bool {
        display == MenuBarDisplay.iconOnly.rawValue || showIcon || !showText
    }

    static func shouldShowMenuBarText(
        display: String,
        showText: Bool,
        text: String
    ) -> Bool {
        display != MenuBarDisplay.iconOnly.rawValue && showText && !text.isEmpty
    }
}
