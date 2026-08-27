import SwiftUI

struct PeriodDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: UsageStore
    @AppStorage("numberStyle") private var numberStyleRawValue = TokenNumberStyle.compact.rawValue
    @AppStorage("showCachedInput") private var showCachedInput = true

    let period: UsagePeriod
    private let formatter = TokenFormatter()

    var body: some View {
        let usage = store.snapshot.totals(for: period)
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatted(usage.totalTokens))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: usage.totalTokens)
                Text("Total tokens")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) total tokens, \(formatted(usage.totalTokens))")

            Divider()

            detailRow("Input", usage.inputTokens)
            if showCachedInput {
                detailRow("Cached input", usage.cachedInputTokens)
            }
            detailRow("Output", usage.outputTokens)

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
        case .today: "Today"
        case .week: "This Week"
        case .month: "This Month"
        case .allTime: "All Time"
        }
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
