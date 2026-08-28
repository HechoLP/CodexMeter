import AppKit
import SwiftUI

struct MenuPopoverView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var profileStore: ProfileUsageStore
    @AppStorage("numberStyle") private var numberStyleRawValue = TokenNumberStyle.compact.rawValue
    @AppStorage("showCachedInput") private var showCachedInput = true
    @AppStorage("showLastUpdated") private var showLastUpdated = true
    @AppStorage("weekStart") private var weekStartRawValue = WeekStart.monday.rawValue
    @State private var refreshTurns = 0

    private let formatter = TokenFormatter()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if usesProfileTotals {
                    profileUsageSummary
                    Divider()
                    periodLinks
                    Divider()
                    localBreakdown
                } else {
                    localUsageSummary
                    Divider()
                    periodLinks
                }
                Divider()
                footer
            }
            .frame(width: 320)
            .background(.background)
            .navigationDestination(for: UsagePeriod.self) { period in
                PeriodDetailView(period: period)
                    .environmentObject(store)
                    .environmentObject(profileStore)
            }
        }
        .onChange(of: isRefreshing) { _, isRefreshing in
            guard isRefreshing, !reduceMotion else { return }
            refreshTurns += 1
        }
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
                        Text("This Mac tokens today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("This Mac total tokens today, \(formatted(store.snapshot.today.totalTokens))")

                    VStack(spacing: 8) {
                        metricRow("Input", value: store.snapshot.today.inputTokens, symbol: "arrow.up")
                        if showCachedInput {
                            metricRow("Cached input", value: store.snapshot.today.cachedInputTokens, symbol: "bolt.horizontal")
                        }
                        metricRow("Output", value: store.snapshot.today.outputTokens, symbol: "arrow.down")
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var profileUsageSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ChatGPT account")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let snapshot = profileStore.snapshot {
                Text(formatted(snapshot.today))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: snapshot.today)
                Text("Profile day · \(profileDate(snapshot.statsAsOf))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("ChatGPT profile tokens for \(profileDate(snapshot.statsAsOf))")
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .accessibilityElement(children: .combine)
    }

    private var localBreakdown: some View {
        Group {
            if store.snapshot.updatedAt == nil {
                HStack(spacing: 10) {
                    if store.isRefreshing || !store.hasLoadedSnapshot {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "externaldrive.badge.questionmark")
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.hasLoadedSnapshot ? "No local usage found" : "Reading this Mac's usage")
                            .font(.subheadline.weight(.semibold))
                        Text(store.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("This Mac today")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(formatted(store.snapshot.today.totalTokens))
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                    VStack(spacing: 8) {
                        metricRow("Input", value: store.snapshot.today.inputTokens, symbol: "arrow.up")
                        if showCachedInput {
                            metricRow("Cached input", value: store.snapshot.today.cachedInputTokens, symbol: "bolt.horizontal")
                        }
                        metricRow("Output", value: store.snapshot.today.outputTokens, symbol: "arrow.down")
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var periodLinks: some View {
        VStack(spacing: 0) {
            periodLink("This Week", period: .week, value: displayedTotal(for: .week))
            periodLink("This Month", period: .month, value: displayedTotal(for: .month))
            periodLink(usesProfileTotals ? "Lifetime" : "Local History", period: .allTime, value: displayedTotal(for: .allTime))
        }
        .padding(.vertical, 6)
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
                    _ = await (localRefresh, profileRefresh)
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
            .help("Refresh usage")
            .accessibilityLabel("Refresh usage")

            Button {
                SettingsWindowController.shared.showSettings(for: store)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .help("Open Settings")
            .accessibilityLabel("Open Settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .help("Quit CodexMeter")
            .accessibilityLabel("Quit CodexMeter")
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

    private var isRefreshing: Bool {
        store.isRefreshing || profileStore.isRefreshing
    }

    private func displayedTotal(for period: UsagePeriod) -> Int64 {
        guard usesProfileTotals, let snapshot = profileStore.snapshot else {
            return store.snapshot.totals(for: period).totalTokens
        }
        return switch period {
        case .today: snapshot.today
        case .week: snapshot.week
        case .month: snapshot.month
        case .allTime: snapshot.lifetime
        }
    }

    private func profileDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
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
}
