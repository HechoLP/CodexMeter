import SwiftUI

struct MenuBarSettingsView: View {
    @AppStorage("menuBarDisplay") private var display = AppPreferences.defaultMenuBarDisplay
    @AppStorage("menuBarPeriod") private var period = UsagePeriod.today.rawValue
    @AppStorage("numberStyle") private var numberStyle = TokenNumberStyle.compact.rawValue
    @AppStorage("showCachedInput") private var showCachedInput = true
    @AppStorage("showLastUpdated") private var showLastUpdated = true
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = AppPreferences.defaultShowMenuBarIcon
    @AppStorage("showMenuBarText") private var showMenuBarText = AppPreferences.defaultShowMenuBarText

    var body: some View {
        SettingsForm {
            SettingsSection(title: "Menu Bar") {
                SettingsToggleRow("Show icon", isOn: iconVisibility, isEnabled: showMenuBarText)
                SettingsToggleRow("Show token text", isOn: textVisibility)
            }

            SettingsSection(title: "Token Text") {
                SettingsPickerRow(title: "Content", selection: $display) {
                    ForEach(MenuBarDisplay.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                SettingsPickerRow(title: "Period", selection: $period) {
                    Text("Today").tag(UsagePeriod.today.rawValue)
                    Text("This Week").tag(UsagePeriod.week.rawValue)
                    Text("This Month").tag(UsagePeriod.month.rawValue)
                }
                SettingsPickerRow(title: "Number format", selection: $numberStyle) {
                    Text("Compact").tag(TokenNumberStyle.compact.rawValue)
                    Text("Detailed").tag(TokenNumberStyle.detailed.rawValue)
                }
            }
            .disabled(!showMenuBarText)

            SettingsSection(title: "Popover") {
                SettingsToggleRow("Show cached input", isOn: $showCachedInput)
                SettingsToggleRow("Show last updated", isOn: $showLastUpdated)
            }
        }
    }

    private var iconVisibility: Binding<Bool> {
        Binding(
            get: { showMenuBarIcon },
            set: { newValue in
                showMenuBarIcon = newValue
                if !newValue && !showMenuBarText {
                    showMenuBarText = true
                }
            }
        )
    }

    private var textVisibility: Binding<Bool> {
        Binding(
            get: { showMenuBarText },
            set: { newValue in
                showMenuBarText = newValue
                if !newValue && !showMenuBarIcon {
                    showMenuBarIcon = true
                }
            }
        )
    }
}
