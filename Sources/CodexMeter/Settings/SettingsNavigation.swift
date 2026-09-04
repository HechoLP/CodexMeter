import SwiftUI

/// Shared settings that are not tied to one service. Per-provider settings
/// (account, limits, local data, analytics options) live in `SettingsPane.provider`.
enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case general
    case menuBar
    case advanced
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .menuBar: "Menu Bar"
        case .advanced: "Diagnostics"
        case .about: "Information"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .menuBar: "menubar.rectangle"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle"
        }
    }

    var chipTint: Color {
        switch self {
        case .general: .gray
        case .menuBar: .purple
        case .advanced: .pink
        case .about: .gray
        }
    }
}

/// One selectable entry in the settings sidebar: a shared category or a provider.
enum SettingsPane: Hashable, Identifiable {
    case category(SettingsCategory)
    case provider(UsageProvider)

    var id: String {
        switch self {
        case .category(let category): "category.\(category.rawValue)"
        case .provider(let provider): "provider.\(provider.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .category(let category): category.title
        case .provider(let provider): provider.title
        }
    }

    var systemImage: String {
        switch self {
        case .category(let category): category.systemImage
        case .provider(let provider): provider.symbol
        }
    }

    var chipTint: Color {
        switch self {
        case .category(let category): category.chipTint
        case .provider(let provider): provider == .codex ? .green : .orange
        }
    }

    static var allCases: [SettingsPane] {
        SettingsCategory.allCases.map(SettingsPane.category)
            + UsageProvider.allCases.map(SettingsPane.provider)
    }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(trimmed) { return true }
        if case .provider(let provider) = self {
            return provider.tabTitle.localizedCaseInsensitiveContains(trimmed)
        }
        return false
    }
}

enum SettingsSidebarSort: String, CaseIterable, Identifiable {
    case recommended
    case name

    var id: Self { self }
    var title: String { self == .recommended ? "Recommended" : "Name" }
}
