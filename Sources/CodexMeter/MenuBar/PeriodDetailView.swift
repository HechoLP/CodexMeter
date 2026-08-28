import SwiftUI

struct PeriodDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var profileStore: ProfileUsageStore
    @AppStorage("numberStyle") private var numberStyleRawValue = TokenNumberStyle.compact.rawValue
    @AppStorage("showCachedInput") private var showCachedInput = true

    let period: UsagePeriod
    private let formatter = TokenFormatter()

    var body: some View {
        let usage = store.snapshot.totals(for: period)
        let total = displayedTotal(localUsage: usage)
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                if usesProfileTotals {
                    Text("ChatGPT account")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(formatted(total))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: total)
                Text(usesProfileTotals ? profileTotalLabel : "This Mac total tokens")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(usesProfileTotals ? "ChatGPT account" : "This Mac") \(title) total tokens, \(formatted(total))")
            .help(
                usesProfileTotals
                    ? "Aggregate ChatGPT account statistic; can lag behind live local activity."
                    : "Includes cached input reads, so this reads higher than the token count Codex itself displays."
            )

            Divider()

            if usesProfileTotals, store.snapshot.updatedAt == nil {
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
                if usesProfileTotals {
                    HStack {
                        Text(localBreakdownLabel)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(formatted(usage.totalTokens))
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }
                detailRow("Input", usage.inputTokens)
                if showCachedInput {
                    detailRow("Cached input", usage.cachedInputTokens)
                }
                detailRow("Output", usage.outputTokens)
            }

            statusLabel

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 320)
        .frame(minHeight: 240, alignment: .topLeading)
        .navigationTitle(title)
    }

    private var statusSymbol: String {
        store.operationAwareStatusSymbol
    }

    @ViewBuilder
    private var statusLabel: some View {
        if !store.isRefreshing,
           !profileStore.isRefreshing,
           !store.isImportingHistory,
           usesProfileTotals,
           let profileSnapshot = profileStore.snapshot {
            Label(
                profileStore.status == .ready
                    ? "Profile through \(profileDate(profileSnapshot.statsAsOf))"
                    : "Profile through \(profileDate(profileSnapshot.statsAsOf)) · \(profileStore.statusMessage)",
                systemImage: profileStore.status == .ready
                    ? "checkmark.circle"
                    : "exclamationmark.triangle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if !store.isRefreshing,
                  !store.isImportingHistory,
                  let lastSourceRefreshAt = store.lastSourceRefreshAt,
                  store.snapshot.quality != .stale,
                  store.snapshot.quality != .error {
            Label {
                HStack(spacing: 3) {
                    Text("Updated")
                    Text(lastSourceRefreshAt, style: .relative)
                }
            } icon: {
                Image(systemName: statusSymbol)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            Label(store.statusMessage, systemImage: statusSymbol)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        switch period {
        case .today: usesProfileTotals ? "Profile Day" : "Today"
        case .week: "This Week"
        case .month: "This Month"
        case .allTime: usesProfileTotals ? "Lifetime" : "Local History"
        }
    }

    private var localBreakdownLabel: String {
        switch period {
        case .today: "This Mac today"
        case .week: "This Mac this week"
        case .month: "This Mac this month"
        case .allTime: "This Mac local history"
        }
    }

    private var usesProfileTotals: Bool {
        profileStore.isEnabled && profileStore.snapshot != nil
    }

    private var profileTotalLabel: String {
        guard let snapshot = profileStore.snapshot else { return "Profile total tokens" }
        if period == .today {
            return "Profile day · \(profileDate(snapshot.statsAsOf))"
        }
        return "Profile total through \(profileDate(snapshot.statsAsOf))"
    }

    private func displayedTotal(localUsage: TokenUsage) -> Int64 {
        guard usesProfileTotals, let snapshot = profileStore.snapshot else {
            return localUsage.totalTokens
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

    private func detailRow(_ title: String, _ value: Int64) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(formatted(value))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: value)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(formatted(value)) tokens")
    }

    private func formatted(_ value: Int64) -> String {
        formatter.string(
            from: value,
            style: TokenNumberStyle(rawValue: numberStyleRawValue) ?? .compact
        )
    }
}
