import SwiftUI

struct MenuPopoverView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.openSettings) private var openSettings
    @AppStorage("numberStyle") private var numberStyleRawValue = TokenNumberStyle.compact.rawValue
    @AppStorage("showCachedInput") private var showCachedInput = true
    @AppStorage("showLastUpdated") private var showLastUpdated = true

    private let formatter = TokenFormatter()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                usageSummary
                Divider()
                periodLinks
                Divider()
                footer
            }
            .frame(width: 320)
            .background(.background)
            .navigationDestination(for: UsagePeriod.self) { period in
                PeriodDetailView(period: period)
                    .environmentObject(store)
            }
        }
        .task {
            await store.refresh()
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

    private var usageSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatted(store.snapshot.today.totalTokens))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("Total tokens today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 8) {
                metricRow("Input", value: store.snapshot.today.inputTokens, symbol: "arrow.up")
                if showCachedInput {
                    metricRow("Cached input", value: store.snapshot.today.cachedInputTokens, symbol: "bolt.horizontal")
                }
                metricRow("Output", value: store.snapshot.today.outputTokens, symbol: "arrow.down")
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var periodLinks: some View {
        VStack(spacing: 0) {
            periodLink("This Week", period: .week, value: store.snapshot.week.totalTokens)
            periodLink("This Month", period: .month, value: store.snapshot.month.totalTokens)
            periodLink("All Time", period: .allTime, value: store.snapshot.allTime.totalTokens)
        }
        .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if showLastUpdated {
                Label(store.statusMessage, systemImage: statusSymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(store.isRefreshing)
            .help("Refresh usage")
            .accessibilityLabel("Refresh usage")

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Open Settings")
            .accessibilityLabel("Open Settings")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var statusSymbol: String {
        switch store.snapshot.quality {
        case .exact: "checkmark.circle"
        case .partial, .stale: "clock"
        case .unavailable: "questionmark.circle"
        case .error: "exclamationmark.triangle"
        }
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
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    private func periodLink(_ title: String, period: UsagePeriod, value: Int64) -> some View {
        NavigationLink(value: period) {
            HStack {
                Text(title)
                Spacer()
                Text(formatted(value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func formatted(_ value: Int64) -> String {
        formatter.string(
            from: value,
            style: TokenNumberStyle(rawValue: numberStyleRawValue) ?? .compact
        )
    }
}
