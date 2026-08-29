import AppKit
import SwiftUI

enum MenuPopoverMetrics {
    static let width: CGFloat = 344
    static let minimumBodyHeight: CGFloat = 300
    static let idealBodyHeight: CGFloat = 440
    static let maximumBodyHeight: CGFloat = 540
}

enum MenuPopoverCategory: String, CaseIterable, Identifiable {
    case localUsage
    case accountLimits
    case tokenHistory
    case explore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localUsage: "Local Usage"
        case .accountLimits: "Account Limits"
        case .tokenHistory: "Token History"
        case .explore: "Explore"
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

struct MenuPopoverView: View {
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
    @AppStorage("projectsEnabled") private var projectsEnabled = AppPreferences.defaultProjectsEnabled
    @AppStorage("sessionsEnabled") private var sessionsEnabled = AppPreferences.defaultSessionsEnabled
    @State private var refreshTurns = 0

    private let formatter = TokenFormatter()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        localUsageSection
                        if accountLimitsEnabled {
                            Divider()
                            accountLimitsPreview
                        }
                        Divider()
                        tokenHistorySection
                        if analyticsEnabled {
                            Divider()
                            exploreSection
                        }
                    }
                }
                .scrollIndicators(.hidden)
                // A ScrollView has no useful intrinsic height inside MenuBarExtra.
                // Without a lower bound AppKit can reopen the popover at the
                // header-and-footer minimum, collapsing the entire usage body.
                .frame(
                    minHeight: MenuPopoverMetrics.minimumBodyHeight,
                    idealHeight: MenuPopoverMetrics.idealBodyHeight,
                    maxHeight: MenuPopoverMetrics.maximumBodyHeight
                )
                Divider()
                footer
            }
            .frame(width: MenuPopoverMetrics.width)
            .background(.background)
            .navigationDestination(for: UsagePeriod.self) { period in
                PeriodDetailView(period: period)
                    .environmentObject(store)
                    .environmentObject(profileStore)
            }
            .navigationDestination(for: MenuDestination.self) { destination in
                switch destination {
                case .limits:
                    AccountLimitsView()
                case .usage:
                    UsageAnalyticsView()
                case .projects:
                    ProjectsAnalyticsView()
                case .sessions:
                    SessionsAnalyticsView()
                case let .project(id, range):
                    ProjectDetailView(id: id, range: range)
                case let .session(id, range):
                    SessionDetailView(id: id, range: range)
                case let .model(id, range):
                    ModelDetailView(id: id, range: range)
                }
            }
        }
        .onChange(of: isRefreshing) { _, isRefreshing in
            guard isRefreshing, !reduceMotion else { return }
            refreshTurns += 1
        }
    }

    private var accountLimitsPreview: some View {
        VStack(alignment: .leading, spacing: 11) {
            NavigationLink(value: MenuDestination.limits) {
                HStack(spacing: 8) {
                    Image(systemName: MenuPopoverCategory.accountLimits.symbol)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(MenuPopoverCategory.accountLimits.title)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if let windows = limitStore.snapshot?.windows, !windows.isEmpty {
                        let visibleCount = visibleAccountLimitWindows(windows).count
                        Text("\(visibleCount) \(visibleCount == 1 ? "window" : "windows")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu.category.accountLimits")
            .accessibilityHint("Open all account limit details")

            if let snapshot = limitStore.snapshot {
                let windows = visibleAccountLimitWindows(snapshot.windows)
                if windows.isEmpty {
                    compactLimitStatus("No Codex limit window was reported.", symbol: "gauge.with.dots.needle.0percent")
                } else {
                    ForEach(Array(windows.prefix(2))) { window in
                        compactLimitRow(
                            window,
                            showsPace: limitStore.status.allowsPaceEstimates
                        )
                    }
                    if windows.count > 2 {
                        Text("\(windows.count - 2) more windows in Limits")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if limitStore.status == .stale {
                        compactLimitStatus(
                            "Offline · showing last known limits",
                            symbol: "wifi.slash"
                        )
                    }
                }
            } else if limitStore.isRefreshing || limitStore.status == .loading {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text("Reading account limits…")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .frame(minHeight: 28)
            } else {
                compactLimitStatus(limitStore.statusMessage, symbol: "exclamationmark.triangle")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "diamond")
                .font(.system(size: 13, weight: .semibold))
                .accessibilityHidden(true)
            Text("CodexMeter")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var localUsageSection: some View {
        VStack(spacing: 0) {
            categoryHeader(.localUsage, context: "This Mac · Today")
            localUsageSummary
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
                        Text(store.statusMessage)
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
                        Text("Total tokens today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("This Mac total tokens today, \(formatted(store.snapshot.today.totalTokens))")
                    .help("Cached input is already included in Input. Total equals Input plus Output.")

                    VStack(spacing: 8) {
                        metricRow("Input", value: store.snapshot.today.inputTokens, symbol: "arrow.up")
                        if showCachedInput {
                            metricRow("Cached input", value: store.snapshot.today.cachedInputTokens, symbol: "bolt.horizontal")
                        }
                        metricRow("Output", value: store.snapshot.today.outputTokens, symbol: "arrow.down")
                    }
                    if analyticsEnabled, costEstimatesEnabled,
                       let analytics = store.analyticsSnapshots[.today] {
                        EstimatedCostLabel(snapshot: analytics, showsUnavailable: false)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var tokenHistorySection: some View {
        VStack(spacing: 0) {
            categoryHeader(.tokenHistory, context: historyContext)
            if usesProfileTotals {
                profilePeriodLinks
            } else {
                localPeriodLinks
            }
        }
    }

    private var localPeriodLinks: some View {
        VStack(spacing: 0) {
            periodLink("This Week", period: .week, value: displayedTotal(for: .week))
            periodLink("This Month", period: .month, value: displayedTotal(for: .month))
            periodLink("Local History", period: .allTime, value: displayedTotal(for: .allTime))
        }
        .padding(.vertical, 6)
    }

    private var profilePeriodLinks: some View {
        VStack(spacing: 0) {
            if let snapshot = profileStore.snapshot {
                periodLink("This Week", period: .week, value: snapshot.week)
                periodLink("This Month", period: .month, value: snapshot.month)
                periodLink("Lifetime", period: .allTime, value: snapshot.lifetime)
            }
        }
        .padding(.bottom, 6)
    }

    private var exploreSection: some View {
        VStack(spacing: 0) {
            categoryHeader(.explore)
            exploreLinks
        }
    }

    private var exploreLinks: some View {
        HStack(spacing: 0) {
            exploreLink("Usage", symbol: "chart.xyaxis.line", destination: .usage)
            if projectsEnabled {
                Divider().frame(height: 30)
                exploreLink("Projects", symbol: "folder", destination: .projects)
            }
            if sessionsEnabled {
                Divider().frame(height: 30)
                exploreLink("Sessions", symbol: "text.bubble", destination: .sessions)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if shouldShowStatus {
                Label {
                    if profileStore.isEnabled, let profileSnapshot = profileStore.snapshot {
                        if profileStore.status == .ready {
                            Text("Profile through \(profileDate(profileSnapshot.statsAsOf))")
                        } else {
                            Text("Profile through \(profileDate(profileSnapshot.statsAsOf)) · \(profileStore.statusMessage)")
                        }
                    } else if profileStore.isEnabled {
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
            }
            Spacer()
            Button {
                Task {
                    async let localRefresh: Void = store.refresh()
                    async let profileRefresh: Void = profileStore.refresh(
                        weekStart: WeekStart(rawValue: weekStartRawValue) ?? .monday
                    )
                    async let limitsRefresh: Void = limitStore.refresh()
                    _ = await (localRefresh, profileRefresh, limitsRefresh)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(Double(refreshTurns) * 360))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.5),
                        value: refreshTurns
                    )
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .disabled(isRefreshing || store.isMaintainingData || store.isImportingHistory)
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh usage")
            .accessibilityLabel("Refresh usage")

            Button {
                SettingsWindowController.shared.showSettings(for: store, limitStore: limitStore)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .keyboardShortcut(",", modifiers: .command)
            .help("Open Settings")
            .accessibilityLabel("Open Settings")

            Menu {
                Button("Open OpenAI Status") {
                    open("https://status.openai.com")
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
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .help("More actions")
            .accessibilityLabel("More actions")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var shouldShowStatus: Bool {
        let qualityNeedsStatus = switch store.snapshot.quality {
        case .stale, .unavailable, .error: true
        case .exact, .partial: false
        }
        return profileStore.isEnabled || showLastUpdated || isRefreshing || store.isImportingHistory || qualityNeedsStatus
    }

    private var statusSymbol: String {
        if isRefreshing { return "arrow.triangle.2.circlepath" }
        if profileStore.isEnabled {
            return profileStore.status == .ready ? "checkmark.circle" : "exclamationmark.triangle"
        }
        return store.operationAwareStatusSymbol
    }

    private var usesProfileTotals: Bool {
        profileStore.isEnabled && profileStore.snapshot != nil
    }

    private var historyContext: String {
        guard usesProfileTotals, let snapshot = profileStore.snapshot else {
            return "This Mac"
        }
        return "ChatGPT · Through \(profileDate(snapshot.statsAsOf))"
    }

    private var isRefreshing: Bool {
        store.isRefreshing || profileStore.isRefreshing || limitStore.isRefreshing
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
        context: String? = nil
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("menu.category.\(category.rawValue)")
    }

    private func metricRow(_ title: String, value: Int64, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 14)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatted(value))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: value)
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(formatted(value)) tokens")
    }

    private func periodLink(_ title: String, period: UsagePeriod, value: Int64) -> some View {
        NavigationLink(value: period) {
            HStack {
                Text(title)
                Spacer()
                Text(formatted(value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: value)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(!usesProfileTotals && store.snapshot.updatedAt == nil)
        .accessibilityLabel("\(title), \(formatted(value)) tokens")
    }

    private func formatted(_ value: Int64) -> String {
        formatter.string(
            from: value,
            style: TokenNumberStyle(rawValue: numberStyleRawValue) ?? .compact
        )
    }

    private func visibleAccountLimitWindows(_ windows: [AccountLimitWindow]) -> [AccountLimitWindow] {
        let visible = additionalLimitsEnabled
            ? windows
            : windows.filter { $0.limitID.lowercased() == "codex" }
        return visible.sorted {
            if $0.windowDurationMinutes == $1.windowDurationMinutes {
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return $0.windowDurationMinutes < $1.windowDurationMinutes
        }
    }

    @ViewBuilder
    private func compactLimitRow(
        _ window: AccountLimitWindow,
        now: Date = Date(),
        showsPace: Bool
    ) -> some View {
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
                if showsPace, let pace = window.pace(at: now) {
                    if window.resetsAt != nil {
                        Text("·")
                    }
                    Text(pace.compactSummary)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .help("Pace compares current use with even use across the reported limit window.")
        }
        .accessibilityElement(children: .combine)
    }

    private func compactLimitStatus(_ message: String, symbol: String) -> some View {
        Label(message, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
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

    private func exploreLink(
        _ title: String,
        symbol: String,
        destination: MenuDestination
    ) -> some View {
        NavigationLink(value: destination) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(title)")
        .accessibilityHint("Shows detailed local Codex \(title.lowercased())")
    }

    private func open(_ rawURL: String) {
        guard let url = URL(string: rawURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
