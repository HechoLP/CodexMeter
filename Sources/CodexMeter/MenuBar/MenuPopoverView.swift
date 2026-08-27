import AppKit
import SwiftUI

struct MenuPopoverView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: UsageStore
    @AppStorage("numberStyle") private var numberStyleRawValue = TokenNumberStyle.compact.rawValue
    @AppStorage("showCachedInput") private var showCachedInput = true
    @AppStorage("showLastUpdated") private var showLastUpdated = true
    @State private var refreshTurns = 0

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
        .onChange(of: store.isRefreshing) { _, isRefreshing in
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

    private var usageSummary: some View {
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
                    .accessibilityLabel("Total tokens today, \(formatted(store.snapshot.today.totalTokens))")

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
            if shouldShowStatus {
                Label {
                    if showLastUpdated,
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
                Task { await store.refresh() }
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
            .disabled(store.isRefreshing || store.isMaintainingData || store.isImportingHistory)
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
        return showLastUpdated || store.isRefreshing || store.isImportingHistory || qualityNeedsStatus
    }

    private var statusSymbol: String {
        store.operationAwareStatusSymbol
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
        .disabled(store.snapshot.updatedAt == nil)
        .accessibilityLabel("\(title), \(formatted(value)) tokens")
    }

    private func formatted(_ value: Int64) -> String {
        formatter.string(
            from: value,
            style: TokenNumberStyle(rawValue: numberStyleRawValue) ?? .compact
        )
    }
}
