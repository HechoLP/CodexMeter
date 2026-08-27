import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            AppearanceSettingsView()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            UsageSettingsView()
                .tabItem { Label("Usage", systemImage: "chart.bar") }
            DataSettingsView()
                .tabItem { Label("Data", systemImage: "externaldrive") }
            AdvancedSettingsView()
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 390)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage("refreshMode") private var refreshMode = "automatic"
    @AppStorage("weekStart") private var weekStart = WeekStart.monday.rawValue

    var body: some View {
        Form {
            Section("Refresh") {
                Picker("Refresh", selection: $refreshMode) {
                    Text("Automatic").tag("automatic")
                    Text("30 Seconds").tag("30")
                    Text("1 Minute").tag("60")
                    Text("5 Minutes").tag("300")
                    Text("Manual").tag("manual")
                }
            }
            Section("Calendar") {
                Picker("Week starts on", selection: $weekStart) {
                    Text("Monday").tag(WeekStart.monday.rawValue)
                    Text("Sunday").tag(WeekStart.sunday.rawValue)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage("menuBarDisplay") private var display = MenuBarDisplay.total.rawValue
    @AppStorage("menuBarPeriod") private var period = UsagePeriod.today.rawValue
    @AppStorage("numberStyle") private var numberStyle = TokenNumberStyle.compact.rawValue
    @AppStorage("showCachedInput") private var showCachedInput = true
    @AppStorage("showLastUpdated") private var showLastUpdated = true

    var body: some View {
        Form {
            Picker("Menu bar display", selection: $display) {
                ForEach(MenuBarDisplay.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            Picker("Menu bar period", selection: $period) {
                Text("Today").tag(UsagePeriod.today.rawValue)
                Text("This Week").tag(UsagePeriod.week.rawValue)
                Text("This Month").tag(UsagePeriod.month.rawValue)
            }
            Picker("Number format", selection: $numberStyle) {
                Text("Compact").tag(TokenNumberStyle.compact.rawValue)
                Text("Detailed").tag(TokenNumberStyle.detailed.rawValue)
            }
            Section("Popover") {
                Toggle("Show cached input", isOn: $showCachedInput)
                Toggle("Show last updated", isOn: $showLastUpdated)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct UsageSettingsView: View {
    var body: some View {
        Form {
            Section("Included metrics") {
                LabeledContent("Input tokens", value: "On")
                LabeledContent("Cached input", value: "On")
                LabeledContent("Output tokens", value: "On")
            }
            Text("Total tokens are calculated as input plus output. Cached input is shown as a subset of input and is not added twice.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct DataSettingsView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        Form {
            Section("Codex Local Data") {
                LabeledContent("Status", value: store.statusMessage)
            }
            Section {
                Button("Rebuild Statistics") {}
                    .disabled(true)
                Button("Clear Local History", role: .destructive) {}
                    .disabled(true)
            }
            Text("Data maintenance actions become available after the local database is initialized.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AdvancedSettingsView: View {
    @AppStorage("debugLogging") private var debugLogging = false

    var body: some View {
        Form {
            Section("Diagnostics") {
                Toggle("Enable debug logging", isOn: $debugLogging)
            }
            Text("Diagnostics never include prompts, responses, source code, terminal output, or authentication tokens.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "diamond")
                .font(.system(size: 40, weight: .medium))
                .accessibilityHidden(true)
            Text("CodexMeter")
                .font(.title2.bold())
            Text("Version 0.1.0")
                .foregroundStyle(.secondary)
            Text("Unofficial utility. Not affiliated with or endorsed by OpenAI.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
