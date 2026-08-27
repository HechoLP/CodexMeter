import SwiftUI

struct PeriodDetailView: View {
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
                Text("Total tokens")
                    .foregroundStyle(.secondary)
            }

            Divider()

            detailRow("Input", usage.inputTokens)
            if showCachedInput {
                detailRow("Cached input", usage.cachedInputTokens)
            }
            detailRow("Output", usage.outputTokens)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 320)
        .frame(minHeight: 240, alignment: .topLeading)
        .navigationTitle(title)
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
            Text(formatted(value)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func formatted(_ value: Int64) -> String {
        formatter.string(
            from: value,
            style: TokenNumberStyle(rawValue: numberStyleRawValue) ?? .compact
        )
    }
}
