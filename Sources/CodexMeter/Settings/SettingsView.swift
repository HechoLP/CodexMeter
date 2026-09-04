import SwiftUI

struct SettingsView: View {
    var onPaneTitleChange: (String) -> Void = { _ in }

    @EnvironmentObject private var env: SettingsEnvironment
    @EnvironmentObject private var claude: ClaudeIntegrationStore
    @State private var selection: SettingsPane? = .category(.general)
    @State private var search = ""

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SettingsSidebarSearchField(text: $search)
                    .padding(8)
                Divider()
                List(selection: $selection) {
                    Section {
                        ForEach(visibleCategories) { category in
                            SettingsChipLabel(
                                title: category.title,
                                systemImage: category.systemImage,
                                tint: category.chipTint
                            )
                            .tag(SettingsPane.category(category))
                        }
                    }
                    if !visibleProviders.isEmpty {
                        Section {
                            ForEach(visibleProviders) { provider in
                                SettingsChipLabel(
                                    title: provider.title,
                                    logoProvider: provider,
                                    statusDot: providerIsOn(provider) ? .green : nil,
                                    dimmed: !providerIsOn(provider)
                                )
                                .tag(SettingsPane.provider(provider))
                            }
                        } header: {
                            HStack {
                                Text("Providers")
                                Spacer()
                                Text("\(onCount) on")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .accessibilityLabel("Settings sections")
                .accessibilityHint("Use the arrow keys to choose a section, then press Tab to change its settings.")
            }
            .navigationSplitViewColumnWidth(min: 224, ideal: 250, max: 300)
            .navigationTitle("CodexMeter")
        } detail: {
            detailPane
                .navigationTitle(selection?.title ?? "Settings")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: 840, idealWidth: 980, maxWidth: .infinity,
            minHeight: 560, idealHeight: 680, maxHeight: .infinity
        )
        .onChange(of: selection) { _, newValue in
            onPaneTitleChange(newValue?.title ?? "CodexMeter Settings")
        }
        .onAppear { onPaneTitleChange(selection?.title ?? "CodexMeter Settings") }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selection {
        case .category(.general): GeneralSettingsView()
        case .category(.menuBar): MenuBarSettingsView()
        case .category(.advanced): AdvancedSettingsView()
        case .category(.about): AboutSettingsView()
        case .provider(let provider): ProviderSettingsView(provider: provider)
        case nil:
            ContentUnavailableView(
                "Choose a Section",
                systemImage: "sidebar.left",
                description: Text("Select a section from the sidebar to view its settings.")
            )
        }
    }

    private func providerIsOn(_ provider: UsageProvider) -> Bool {
        provider == .codex ? true : claude.isAvailable
    }

    private var onCount: Int {
        1 + (claude.isAvailable ? 1 : 0)
    }

    private var visibleCategories: [SettingsCategory] {
        SettingsCategory.allCases.filter { SettingsPane.category($0).matches(search) }
    }

    private var visibleProviders: [UsageProvider] {
        UsageProvider.allCases.filter { SettingsPane.provider($0).matches(search) }
    }
}
