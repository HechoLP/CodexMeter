import AppKit
import SwiftUI

enum MenuPopoverMetrics {
    static let width: CGFloat = 372
    static let detailMaximumHeight: CGFloat = 520
    static let analyticsViewportMaximumHeight: CGFloat = 440
    static let detailHeaderHeight: CGFloat = 44
}

enum MenuPopoverSection: String, CaseIterable, Identifiable {
    case overview
    case codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Token Usage"
        case .codex: "Codex Limits"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .codex: "terminal"
        }
    }

    var categories: [MenuPopoverCategory] {
        switch self {
        case .overview: [.localUsage, .tokenHistory, .explore]
        case .codex: [.accountLimits]
        }
    }
}

enum MenuPopoverCategory: String, CaseIterable, Identifiable {
    case accountLimits
    case localUsage
    case tokenHistory
    case explore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accountLimits: "Usage limits"
        case .localUsage: "Today"
        case .tokenHistory: "History"
        case .explore: "Details"
        }
    }

    var symbol: String {
        switch self {
        case .localUsage: "chart.bar"
        case .accountLimits: "gauge.with.dots.needle.50percent"
        case .tokenHistory: "clock.arrow.circlepath"
        case .explore: "square.grid.2x2"
        }
    }
}

enum MenuProviderSelection {
    static func apply(_ provider: UsageProvider, selection: inout String,
                      section: inout MenuPopoverSection) {
        selection = provider.rawValue
        if provider == .claude { section = .overview }
    }
}

struct MenuPopoverView: View {
    @StateObject private var navigation: MenuNavigation
    private let accounts: CodexAccountStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var profileStore: ProfileUsageStore
    @EnvironmentObject private var limitStore: AccountLimitStore
    @AppStorage("numberStyle") private var numberStyleRawValue = TokenNumberStyle.compact.rawValue
    @AppStorage("showCachedInput") private var showCachedInput = true
    @AppStorage("showLastUpdated") private var showLastUpdated = true
    @AppStorage("weekStart") private var weekStartRawValue = WeekStart.monday.rawValue
    @AppStorage("analyticsEnabled") private var analyticsEnabled = AppPreferences.defaultAnalyticsEnabled
    @AppStorage("costEstimatesEnabled") private var costEstimatesEnabled = AppPreferences.defaultCostEstimatesEnabled
    @AppStorage("accountLimitsEnabled") private var accountLimitsEnabled = AppPreferences.defaultAccountLimitsEnabled
    @AppStorage("additionalLimitsEnabled") private var additionalLimitsEnabled = AppPreferences.defaultAdditionalLimitsEnabled
    @AppStorage("resetCreditsEnabled") private var resetCreditsEnabled = AppPreferences.defaultResetCreditsEnabled
    @AppStorage("projectsEnabled") private var projectsEnabled = AppPreferences.defaultProjectsEnabled
    @AppStorage("sessionsEnabled") private var sessionsEnabled = AppPreferences.defaultSessionsEnabled
    @State private var selectedSection = MenuPopoverSection.overview
    @State private var refreshTurns = 0
    @AppStorage("usageProvider") private var usageProvider = UsageProvider.codex.rawValue

    private let formatter = TokenFormatter()

    init(accounts: CodexAccountStore, navigation: MenuNavigation = MenuNavigation(),
         section: MenuPopoverSection = .overview) {
        self.accounts = accounts
        _navigation = StateObject(wrappedValue: navigation)
        _selectedSection = State(initialValue: section)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let destination = navigation.destination {
                detailHeader(destination)
                Divider()
                destinationView(destination)
                    .id(destination)
            } else {
                header
                Group {
                    switch store.provider == .claude ? .overview : selectedSection {
                    case .overview:
                        overviewContent
                    case .codex:
                        codexContent
                    }
                }
                .id(selectedSection)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
                Divider()
                footer
            }
        }
        .frame(width: MenuPopoverMetrics.width, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(.background)
        .environmentObject(navigation)
        .onChange(of: isRefreshing) { _, isRefreshing in
            guard isRefreshing, !reduceMotion else { return }
            refreshTurns += 1
        }
    }

    private func detailHeader(_ destination: MenuDestination) -> some View {
        HStack(spacing: 8) {
            Button {
                navigation.back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .keyboardShortcut("[", modifiers: .command)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("menu.navigation.back")
            .help("Back")
            Text(destination.title(usesProfileTotals: usesProfileTotals))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Text(store.provider.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if destination == .limits {
                Button {
                    Task { await limitStore.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 28, height: 28)
                }
                .disabled(limitStore.isRefreshing)
                .accessibilityLabel("Refresh account limits")
                .help("Refresh account limits")
            }
        }
        .buttonStyle(MenuInteractionStyle())
        .padding(.horizontal, 12)
        .frame(height: MenuPopoverMetrics.detailHeaderHeight)
    }

    @ViewBuilder
    private func destinationView(_ destination: MenuDestination) -> some View {
        switch destination {
        case .limits: AccountLimitsView()
        case .usage: UsageAnalyticsView()
        case .projects: ProjectsAnalyticsView()
        case .sessions: SessionsAnalyticsView()
        case let .period(period): PeriodDetailView(period: period)
        case let .project(id, range): ProjectDetailView(id: id, range: range)
        case let .session(id, range): SessionDetailView(id: id, range: range)
        case let .model(id, range): ModelDetailView(id: id, range: range)
        }
    }

    private var overviewContent: some View {
        VStack(spacing: 0) {
            localUsageSection
            if analyticsEnabled {
                Divider()
                exploreSection
            }
        }
    }

    @ViewBuilder
    private var codexContent: some View {
        if accountLimitsEnabled {
            accountLimitsPreview
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Codex Limits are turned off", systemImage: "gauge.with.dots.needle.0percent")
                    .font(.headline)
                Text("Enable Account Limits in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    SettingsWindowController.shared.showSettings(for: store, limitStore: limitStore)
                }
                .buttonStyle(.link)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
    }

    private var accountLimitsPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuLink(destination: .limits) {
                categoryHeader(.accountLimits, showsDisclosure: true)
            }
            .accessibilityIdentifier("menu.category.accountLimits")
            .accessibilityHint("Open all account limit details")

            VStack(alignment: .leading, spacing: 12) {
                if let snapshot = limitStore.snapshot {
                    let windows = visibleAccountLimitWindows(snapshot.windows)
                    if windows.isEmpty {
                        compactLimitStatus(
                            "No Codex usage limits were reported.",
                            symbol: "gauge.with.dots.needle.0percent"
                        )
                    } else {
                        ForEach(Array(windows.prefix(3))) { window in
                            compactLimitRow(window)
                        }
                        if windows.count > 3 {
                            MenuLink(destination: .limits) {
                                Text("View \(windows.count - 3) more")
                                    .font(.caption)
                                    .padding(.vertical, 6)
                            }
                        }
                        if limitStore.status == .stale {
                            compactLimitStatus(
                                "Offline · showing last known limits",
                                symbol: "wifi.slash"
                            )
                        }
                    }
                    if resetCreditsEnabled, let credits = snapshot.resetCredits {
                        resetCreditsSummary(credits)
                    }
                } else if limitStore.isRefreshing || limitStore.status == .loading {
                    HStack(spacing: 9) {
                        ProgressView().controlSize(.small)
                        Text("Reading account limits…")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .frame(minHeight: 36)
                } else {
                    compactLimitStatus(limitStore.statusMessage, symbol: "exclamationmark.triangle")
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "diamond")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)
                Text("CodexMeter")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 15)
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                ForEach(UsageProvider.allCases) { provider in
                    providerTab(provider)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if store.provider == .codex {
                CodexAccountSwitcher(accounts: accounts)

                HStack(spacing: 8) {
                    ForEach(MenuPopoverSection.allCases) { section in
                        sectionTab(section)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }

            Divider()
        }
    }

    private func providerTab(_ provider: UsageProvider) -> some View {
        let isSelected = usageProvider == provider.rawValue
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                MenuProviderSelection.apply(provider, selection: &usageProvider, section: &selectedSection)
            }
        } label: {
            VStack(spacing: 1) {
                ProviderLogo(provider: provider)
                    .accessibilityHidden(true)
                Text(provider.tabTitle)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(
                isSelected ? Color(nsColor: .alternateSelectedControlTextColor) : Color.secondary
            )
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                isSelected ? Color(nsColor: .controlAccentColor) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuInteractionStyle())
        .keyboardShortcut(provider == .codex ? "1" : "2", modifiers: [.command, .shift])
        .accessibilityLabel(provider.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Show \(provider.title) usage")
        .accessibilityIdentifier("menu.provider.\(provider.rawValue)")
    }

    private func sectionTab(_ section: MenuPopoverSection) -> some View {
        let isSelected = selectedSection == section
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: section.symbol)
                    .font(.system(size: 14, weight: .medium))
                Text(section.title)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 36)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 52, height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuInteractionStyle())
        .keyboardShortcut(section == .overview ? "1" : "2", modifiers: .command)
        .accessibilityLabel(section.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Show \(section.title.lowercased())")
        .accessibilityIdentifier("menu.section.\(section.rawValue)")
    }

    private var localUsageSection: some View {
        VStack(spacing: 0) {
            categoryHeader(.localUsage, context: "This Mac")
            localUsageSummary
            if store.provider == .codex || store.snapshot.updatedAt != nil {
                Divider().padding(.leading, 18)
                categoryHeader(.tokenHistory, context: historyContext)
                if usesProfileTotals {
                    profilePeriodLinks
                } else {
                    localPeriodLinks
                }
            }
        }
    }

    private var localUsageSummary: some View {
        Group {
            if store.snapshot.updatedAt == nil {
                HStack(spacing: 12) {
                    if store.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.isRefreshing ? "Reading local usage" : "No local usage yet")
                            .font(.headline)
                        Text(store.provider == .claude && store.hasLoadedSnapshot
                             && store.snapshot.quality == .unavailable && !store.isRefreshing
                             ? "Start a Claude Code session, then Refresh."
                             : store.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(minHeight: 96)
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatted(store.snapshot.today.totalTokens))
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.24),
                                value: store.snapshot.today.totalTokens
                            )
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("This Mac total tokens today, \(formatted(store.snapshot.today.totalTokens))")
                    .help("Cached input is already included in Input. Total equals Input plus Output.")

                    HStack(spacing: 0) {
                        metricSummary("Input", value: store.snapshot.today.inputTokens, symbol: "arrow.up")
                        if showCachedInput {
                            Divider().frame(height: 34)
                            metricSummary(
                                "Cached input",
                                value: store.snapshot.today.cachedInputTokens,
                                symbol: "bolt.horizontal"
                            )
                        }
                        Divider().frame(height: 34)
                        metricSummary("Output", value: store.snapshot.today.outputTokens, symbol: "arrow.down")
                    }
                    if analyticsEnabled, costEstimatesEnabled,
                       let analytics = store.analyticsSnapshots[.today] {
                        EstimatedCostLabel(snapshot: analytics, showsUnavailable: false)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private var localPeriodLinks: some View {
        VStack(spacing: 0) {
            periodRowLink("This Week", period: .week, value: displayedTotal(for: .week))
            periodRowLink("This Month", period: .month, value: displayedTotal(for: .month))
            periodRowLink("Local History", period: .allTime, value: displayedTotal(for: .allTime))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var profilePeriodLinks: some View {
        VStack(spacing: 0) {
            if let snapshot = profileStore.snapshot {
                periodRowLink("This Week", period: .week, value: snapshot.week)
                periodRowLink("This Month", period: .month, value: snapshot.month)
                periodRowLink("Lifetime", period: .allTime, value: snapshot.lifetime)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var exploreSection: some View {
        exploreLinks
            .padding(.top, 8)
    }

    private var exploreLinks: some View {
        VStack(spacing: 0) {
            exploreRowLink("Usage", symbol: "chart.xyaxis.line", destination: .usage)
            if projectsEnabled {
                exploreRowLink("Projects", symbol: "folder", destination: .projects)
            }
            if sessionsEnabled {
                exploreRowLink("Sessions", symbol: "text.bubble", destination: .sessions)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if shouldShowStatus {
                HStack {
                    Label {
                        if store.provider == .codex && selectedSection == .codex {
                            Text(limitStore.statusMessage)
                        } else if profileEnabled, let profileSnapshot = profileStore.snapshot {
                            if profileStore.status == .ready {
                                Text("Account totals through \(profileDate(profileSnapshot.statsAsOf))")
                            } else {
                                Text("Through \(profileDate(profileSnapshot.statsAsOf)) · \(profileStore.statusMessage)")
                            }
                        } else if profileEnabled {
                            Text("\(profileStore.statusMessage) · showing This Mac")
                        } else if showLastUpdated,
                                  !store.isRefreshing,
                                  !store.isImportingHistory,
                                  let lastSourceRefreshAt = store.lastSourceRefreshAt,
                                  store.snapshot.quality != .stale,
                                  store.snapshot.quality != .error {
                            HStack(spacing: 3) {
                                Text("Updated")
                                Text(lastSourceRefreshAt, style: .relative)
                            }
                        } else {
                            Text(store.statusMessage)
                        }
                    } icon: {
                        Image(systemName: statusSymbol)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.18),
                        value: store.statusMessage
                    )
                    Spacer()
                }
            }

            HStack(spacing: 18) {
                Button {
                    Task {
                        guard store.provider == .codex else {
                            await store.refresh()
                            return
                        }
                        async let localRefresh: Void = store.refresh()
                        async let profileRefresh: Void = profileStore.refresh(
                            weekStart: WeekStart(rawValue: weekStartRawValue) ?? .monday
                        )
                        async let limitsRefresh: Void = limitStore.refresh()
                        _ = await (localRefresh, profileRefresh, limitsRefresh)
                    }
                } label: {
                    Label {
                        Text("Refresh")
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(Double(refreshTurns) * 360))
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.5),
                                value: refreshTurns
                            )
                    }
                    .padding(.horizontal, 6)
                    .frame(minHeight: 28)
                }
                .disabled(isRefreshing || store.isMaintainingData || store.isImportingHistory)
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh usage")

                Button {
                    SettingsWindowController.shared.showSettings(for: store, limitStore: limitStore)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .padding(.horizontal, 6)
                        .frame(minHeight: 28)
                }
                .keyboardShortcut(",", modifiers: .command)
                .help("Open Settings")

                Spacer()

                Menu {
                    if store.provider == .codex {
                        Button("Open OpenAI Status") {
                            open("https://status.openai.com")
                        }
                    }
                    Button("Open CodexMeter on GitHub") {
                        open("https://github.com/HechoLP/CodexMeter")
                    }
                    Button("Check for Updates…") {
                        UpdateService.shared.checkForUpdates()
                    }
                    .disabled(!UpdateService.shared.isAvailable)
                    Divider()
                    Button("Quit CodexMeter") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: .command)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                        .font(.caption.weight(.medium))
                        .frame(minHeight: 28)
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
                .menuIndicator(.hidden)
                .help("More actions")
            }
            .buttonStyle(MenuInteractionStyle())
            .font(.caption.weight(.medium))
            .frame(minHeight: 28)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var shouldShowStatus: Bool {
        if store.provider == .codex && selectedSection == .codex {
            return accountLimitsEnabled
        }
        let qualityNeedsStatus = switch store.snapshot.quality {
        case .stale, .unavailable, .error: true
        case .exact, .partial: false
        }
        return profileEnabled || showLastUpdated || isRefreshing || store.isImportingHistory || qualityNeedsStatus
    }

    private var statusSymbol: String {
        if isRefreshing { return "arrow.triangle.2.circlepath" }
        if store.provider == .codex && selectedSection == .codex {
            return switch limitStore.status {
            case .ready: "checkmark.circle"
            case .stale: "clock.badge.exclamationmark"
            case .disabled: "gauge.with.dots.needle.0percent"
            case .loading: "arrow.triangle.2.circlepath"
            case .unavailable: "exclamationmark.triangle"
            }
        }
        if profileEnabled {
            return profileStore.status == .ready ? "checkmark.circle" : "exclamationmark.triangle"
        }
        return store.operationAwareStatusSymbol
    }

    private var usesProfileTotals: Bool {
        profileEnabled && profileStore.snapshot != nil
    }

    private var profileEnabled: Bool {
        store.provider.supportsAccountTotals && profileStore.isEnabled
    }

    private var historyContext: String {
        guard usesProfileTotals, let snapshot = profileStore.snapshot else {
            return "This Mac"
        }
        return "ChatGPT · Through \(profileDate(snapshot.statsAsOf))"
    }

    private var isRefreshing: Bool {
        store.isRefreshing || (store.provider == .codex && (profileStore.isRefreshing || limitStore.isRefreshing))
    }

    private func displayedTotal(for period: UsagePeriod) -> Int64 {
        UsageDisplayPolicy.displayedTotal(
            for: period,
            localUsage: store.snapshot.totals(for: period),
            profileSnapshot: usesProfileTotals ? profileStore.snapshot : nil
        )
    }

    private func profileDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func categoryHeader(
        _ category: MenuPopoverCategory,
        context: String? = nil,
        showsDisclosure: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.symbol)
                .frame(width: 14)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(category.title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 8)
            if let context {
                Text(context)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("menu.category.\(category.rawValue)")
    }

    private func metricSummary(_ title: String, value: Int64, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
                Text(title)
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            Text(formatted(value))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: value)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(formatted(value)) tokens")
    }

    private func periodRowLink(_ title: String, period: UsagePeriod, value: Int64) -> some View {
        MenuLink(destination: .period(period)) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(formatted(value))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: value)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .contentShape(Rectangle())
        }
        .disabled(!usesProfileTotals && store.snapshot.updatedAt == nil)
        .accessibilityLabel("\(title), \(formatted(value)) tokens")
        .accessibilityHint("Open \(title.lowercased()) details")
    }

    private func formatted(_ value: Int64) -> String {
        formatter.string(
            from: value,
            style: TokenNumberStyle(rawValue: numberStyleRawValue) ?? .compact
        )
    }

    private func visibleAccountLimitWindows(_ windows: [AccountLimitWindow]) -> [AccountLimitWindow] {
        AccountLimitPresentation.visibleWindows(windows, includesAdditional: additionalLimitsEnabled)
    }

    @ViewBuilder
    private func compactLimitRow(_ window: AccountLimitWindow) -> some View {
        let remaining = window.remainingPercent
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(limitTitle(window))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if remaining <= 25 {
                    Label(remaining <= 10 ? "Critical" : "Low", systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.titleOnly)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(remaining <= 10 ? .red : .orange)
                }
                Spacer()
                Text("\(Int(remaining.rounded()))% left")
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            ProgressView(value: remaining, total: 100)
                .tint(limitAccent(remaining))
                .accessibilityLabel("\(limitTitle(window)) remaining")
                .accessibilityValue("\(Int(remaining.rounded())) percent")
            HStack(spacing: 4) {
                if let reset = window.resetsAt {
                    Text("Resets")
                    Text(reset, style: .relative)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
    }

    private func compactLimitStatus(_ message: String, symbol: String) -> some View {
        Label(message, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
    }

    private func resetCreditsSummary(_ credits: ResetCreditSummary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.counterclockwise.circle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Reset credits")
                .font(.caption.weight(.semibold))
            Spacer()
            Text(credits.unlimited ? "Unlimited" : credits.availableCount?.formatted() ?? "Available")
                .font(.caption.weight(.semibold).monospacedDigit())
            if let expiration = credits.expiresAt {
                Text("· \(expiration, format: .dateTime.month(.abbreviated).day())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }

    private func limitTitle(_ window: AccountLimitWindow) -> String {
        window.displayName.caseInsensitiveCompare("Codex") == .orderedSame
            ? window.windowLabel
            : "\(window.displayName) · \(window.windowLabel)"
    }

    private func limitAccent(_ remaining: Double) -> Color {
        if remaining <= 10 { return .red }
        if remaining <= 25 { return .orange }
        return .accentColor
    }

    private func exploreRowLink(
        _ title: String,
        symbol: String,
        destination: MenuDestination
    ) -> some View {
        MenuLink(destination: destination) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline)
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 38)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Open \(title)")
        .accessibilityHint(store.provider.analyticsHint(for: title))
    }

    private func open(_ rawURL: String) {
        guard let url = URL(string: rawURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
