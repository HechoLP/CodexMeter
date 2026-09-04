import Charts
import SwiftUI

struct AccountLimitsView: View {
    let snapshot: AccountLimitsSnapshot?
    let status: AccountLimitStatus
    let statusMessage: String
    let isRefreshing: Bool
    let provider: UsageProvider
    let refresh: @MainActor () async -> Void
    @AppStorage("additionalLimitsEnabled") private var additionalLimitsEnabled = AppPreferences.defaultAdditionalLimitsEnabled
    @AppStorage("resetCreditsEnabled") private var resetCreditsEnabled = AppPreferences.defaultResetCreditsEnabled

    var body: some View {
        ContentFittingScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let snapshot {
                    let windows = visibleWindows(snapshot.windows)
                    if windows.isEmpty {
                        unavailable(
                            snapshot.windows.isEmpty
                                ? "No account limit windows were returned."
                                : "No \(provider.tabTitle) limit window was reported. Enable additional limits to view the other windows."
                        )
                    } else {
                        ForEach(windows) { window in
                            limitCard(window)
                        }
                    }
                    if provider == .codex, resetCreditsEnabled, let credits = snapshot.resetCredits {
                        resetCreditsCard(credits)
                    }
                    DisclosureGroup("About these limits") {
                        Text(provider == .codex
                             ? "Reported by Codex; read-only. Reset credits are never consumed here. Pace assumes even use; run-out times are estimates, not guarantees."
                             : "Reported by Claude Code; read-only. Limits update after a Claude response. Pace assumes even use; run-out times are estimates, not guarantees.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .font(.caption)
                    HStack(spacing: 5) {
                        Image(systemName: status == .stale ? "wifi.slash" : "clock")
                        Text(limitStatusText(snapshot))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if isRefreshing || status == .loading {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Reading account limits…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    unavailable(statusMessage)
                }
            }
            .padding(16)
        }
        .frame(width: MenuPopoverMetrics.width)
        .task {
            if snapshot == nil { await refresh() }
        }
    }

    private func limitCard(_ window: AccountLimitWindow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(window.displayName).font(.subheadline.weight(.semibold))
                    Text(window.windowLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(window.remainingPercent, format: .number.precision(.fractionLength(0)))
                    .font(.headline.monospacedDigit())
                Text("% left").font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: window.remainingPercent, total: 100)
                .accessibilityLabel("\(window.displayName), \(window.windowLabel), remaining")
                .accessibilityValue("\(Int(window.remainingPercent.rounded())) percent")
            if let reset = window.resetsAt {
                Text("Resets \(reset, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Resets \(reset.formatted(date: .complete, time: .shortened))")
            }
            if status.allowsPaceEstimates,
               let pace = window.pace(at: Date()) {
                HStack(spacing: 4) {
                    Image(systemName: pace.state == .ahead ? "exclamationmark.triangle" : "speedometer")
                        .accessibilityHidden(true)
                    Text(pace.summary)
                    if let projected = pace.projectedExhaustion {
                        Text("· estimated run-out")
                        Text(projected, style: .relative)
                    }
                }
                .font(.caption)
                .foregroundStyle(pace.state == .ahead ? .orange : .secondary)
                .accessibilityElement(children: .combine)
                .help("Pace compares current use with even use across the reported limit window. Run-out time uses the current window average.")
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private func resetCreditsCard(_ credits: ResetCreditSummary) -> some View {
        HStack {
            Label("Reset credits", systemImage: "arrow.counterclockwise.circle")
            Spacer()
            Text(credits.unlimited ? "Unlimited" : credits.availableCount?.formatted() ?? "Available")
                .monospacedDigit()
            if let expiration = credits.expiresAt {
                Text("· \(expiration, format: .dateTime.month(.abbreviated).day())")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private func unavailable(_ text: String) -> some View {
        ContentUnavailableView("Limits Unavailable", systemImage: "gauge.with.dots.needle.0percent", description: Text(text))
            .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func visibleWindows(_ windows: [AccountLimitWindow]) -> [AccountLimitWindow] {
        provider == .codex
            ? AccountLimitPresentation.visibleWindows(windows, includesAdditional: additionalLimitsEnabled)
            : windows
    }

    private func limitStatusText(_ snapshot: AccountLimitsSnapshot) -> String {
        let age = max(0, Date().timeIntervalSince(snapshot.fetchedAt))
        let ageText: String
        switch age {
        case ..<5:
            ageText = "just now"
        case ..<60:
            ageText = "\(Int(age)) sec ago"
        case ..<3_600:
            ageText = "\(Int(age / 60)) min ago"
        case ..<86_400:
            ageText = "\(Int(age / 3_600)) hr ago"
        default:
            let days = Int(age / 86_400)
            ageText = "\(days) \(days == 1 ? "day" : "days") ago"
        }
        if status == .stale {
            return provider == .codex
                ? "Offline · last updated \(ageText)"
                : "Last known · updated \(ageText)"
        }
        return "Updated \(ageText)"
    }
}

enum AnalyticsChartMetric: String, CaseIterable, Identifiable {
    case tokens
    case cost

    var id: Self { self }
    var title: String { self == .tokens ? "Tokens" : "Cost" }

    func resolved(costEstimatesEnabled: Bool) -> Self {
        costEstimatesEnabled ? self : .tokens
    }
}

/// One compact header followed by a content-fitting, height-limited viewport.
private struct AnalyticsDetailLayout<Controls: View, Content: View>: View {
    @EnvironmentObject private var store: UsageStore
    @ViewBuilder var controls: Controls
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controls
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .layoutPriority(1)
            Divider()
            analyticsSnapshotStatus(store)
                .fixedSize(horizontal: false, vertical: true)
            ContentFittingScrollView(maximumHeight: MenuPopoverMetrics.analyticsViewportMaximumHeight) {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: MenuPopoverMetrics.width, alignment: .topLeading)
    }
}

private struct AnalyticsRangePicker: View {
    @Binding var range: AnalyticsRange

    var body: some View {
        Picker("Range", selection: $range) {
            ForEach(AnalyticsRange.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct UsageAnalyticsView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var navigation: MenuNavigation
    @AppStorage("costEstimatesEnabled") private var costEstimatesEnabled = AppPreferences.defaultCostEstimatesEnabled

    private var range: AnalyticsRange { navigation.usageRange }
    private var showsCost: Bool { costEstimatesEnabled && store.provider.supportsCostEstimates }
    private var chartMetric: AnalyticsChartMetric {
        navigation.chartMetric.resolved(costEstimatesEnabled: showsCost)
    }
    private var selectedBucketDate: Date? { navigation.selectedBucketDate }

    var body: some View {
        AnalyticsDetailLayout {
            VStack(alignment: .leading, spacing: 10) {
                AnalyticsRangePicker(range: $navigation.usageRange)
                if showsCost {
                    Picker("Chart metric", selection: $navigation.chartMetric) {
                        ForEach(AnalyticsChartMetric.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        } content: {
            if let snapshot = store.analyticsSnapshots[range] {
                VStack(alignment: .leading, spacing: 16) {
                    totalCard(snapshot)
                    usageChart(snapshot)
                    modelBreakdown(snapshot)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
            } else {
                loading
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
        }
        .task(id: range) { await store.refreshAnalytics(range: range) }
        .onChange(of: range) { _, _ in navigation.selectedBucketDate = nil }
        .onChange(of: chartMetric) { _, _ in navigation.selectedBucketDate = nil }
    }

    private func totalCard(_ snapshot: AnalyticsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(snapshot.usage.totalTokens.formatted())
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("tokens")
                .font(.caption)
                .foregroundStyle(.secondary)
            if showsCost {
                EstimatedCostLabel(snapshot: snapshot)
            }
        }
    }

    private func usageChart(_ snapshot: AnalyticsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chartMetric == .tokens ? "Token activity" : "Estimated API-equivalent cost")
                .font(.subheadline.weight(.semibold))
            if chartMetric == .cost, hasUnavailableCostBucket(snapshot) {
                Text("Cost unavailable for one or more intervals in this range.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 112)
            } else {
                Chart(snapshot.buckets) { bucket in
                    BarMark(
                        x: .value("Time", bucket.start),
                        y: .value(chartMetric.title, chartValue(bucket, quality: snapshot.quality))
                    )
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(3)
                }
                .chartYAxis(.hidden)
                .chartXSelection(value: $navigation.selectedBucketDate)
                .frame(height: 112)
                .accessibilityLabel("\(chartMetric.title) chart for \(range.title)")
            }
            if let bucket = selectedBucket(in: snapshot) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(bucket.start.formatted(date: range == .today ? .omitted : .abbreviated, time: range == .today ? .shortened : .omitted))
                        .font(.caption.weight(.semibold))
                    Text("\(bucket.usage.totalTokens.formatted()) tokens")
                        .font(.caption).foregroundStyle(.secondary)
                    if showsCost {
                        EstimatedCostText(
                            models: bucket.models,
                            through: bucket.end,
                            quality: snapshot.quality,
                            compact: true
                        )
                    }
                    usageBreakdown(bucket.usage)
                }
                .padding(10)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func modelBreakdown(_ snapshot: AnalyticsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Models").font(.subheadline.weight(.semibold))
            if snapshot.models.isEmpty {
                Text("No model-tagged usage in this range.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.models) { model in
                    MenuLink(destination: .model(id: model.id, range: range)) {
                        analyticsRow(
                            model.displayName,
                            tokens: model.usage.totalTokens,
                            models: [model],
                            through: snapshot.through,
                            quality: snapshot.quality,
                            horizontalPadding: 8
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var loading: some View {
        analyticsPlaceholder(store: store, title: "Usage Unavailable", minimumHeight: 180)
    }

    private func chartValue(_ bucket: UsageBucket, quality: DataQuality) -> Double {
        switch chartMetric {
        case .tokens: Double(bucket.usage.totalTokens)
        case .cost: estimatedCost(for: bucket.models, through: bucket.end, quality: quality)
            .map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0
        }
    }

    private func hasUnavailableCostBucket(_ snapshot: AnalyticsSnapshot) -> Bool {
        snapshot.quality != .exact || snapshot.buckets.contains {
            $0.usage.totalTokens > 0
                && estimatedCost(for: $0.models, through: $0.end, quality: snapshot.quality) == nil
        }
    }

    private func selectedBucket(in snapshot: AnalyticsSnapshot) -> UsageBucket? {
        guard let selectedBucketDate else { return nil }
        return snapshot.buckets.min {
            abs($0.start.timeIntervalSince(selectedBucketDate)) < abs($1.start.timeIntervalSince(selectedBucketDate))
        }
    }
}

struct ProjectsAnalyticsView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var navigation: MenuNavigation
    private var range: AnalyticsRange { navigation.projectsRange }

    var body: some View {
        analyticsList {
            if let snapshot = store.analyticsSnapshots[range] {
                ForEach(snapshot.projects) { project in
                    MenuLink(destination: .project(id: project.id, range: range)) {
                        analyticsRow(
                            project.name,
                            detail: pluralized(project.sessionCount, singular: "session", plural: "sessions"),
                            tokens: project.usage.totalTokens,
                            models: project.models,
                            through: snapshot.through,
                            quality: snapshot.quality
                        )
                    }
                }
            }
        }
        .task(id: range) { await store.refreshAnalytics(range: range) }
    }

    private func analyticsList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        AnalyticsDetailLayout {
            AnalyticsRangePicker(range: $navigation.projectsRange)
        } content: {
            VStack(spacing: 0) {
                if store.analyticsSnapshots[range] == nil {
                    analyticsPlaceholder(store: store, title: "Projects Unavailable", minimumHeight: 180)
                } else if store.analyticsSnapshots[range]?.projects.isEmpty == true {
                    Text("No project-tagged usage in this range.")
                        .font(.caption).foregroundStyle(.secondary).padding(24)
                }
                content()
            }
        }
    }
}

struct SessionsAnalyticsView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var navigation: MenuNavigation
    private var range: AnalyticsRange { navigation.sessionsRange }
    @AppStorage("agentDetailsEnabled") private var agentDetailsEnabled = AppPreferences.defaultAgentDetailsEnabled
    @AppStorage("attachmentMetadataEnabled") private var attachmentMetadataEnabled = AppPreferences.defaultAttachmentMetadataEnabled

    var body: some View {
        AnalyticsDetailLayout {
            AnalyticsRangePicker(range: $navigation.sessionsRange)
        } content: {
            VStack(spacing: 0) {
                if store.analyticsSnapshots[range] == nil {
                    analyticsPlaceholder(store: store, title: "Sessions Unavailable", minimumHeight: 180)
                } else if store.analyticsSnapshots[range]?.sessions.isEmpty == true {
                    Text("No sessions in this range.").font(.caption).foregroundStyle(.secondary).padding(24)
                }
                if let snapshot = store.analyticsSnapshots[range] {
                    ForEach(snapshot.sessions) { session in
                        MenuLink(destination: .session(id: session.id, range: range)) {
                            analyticsRow(
                                session.displayName,
                                detail: sessionDetail(session),
                                tokens: session.usage.totalTokens,
                                models: session.models,
                                through: snapshot.through,
                                quality: snapshot.quality
                            )
                        }
                    }
                }
            }
        }
        .task(id: range) { await store.refreshAnalytics(range: range) }
    }

    private func sessionDetail(_ session: SessionUsageSummary) -> String {
        var parts = [session.lastActivityAt.formatted(date: .abbreviated, time: .shortened)]
        if agentDetailsEnabled, session.directSubagentCount > 0 {
            parts.append(pluralized(session.directSubagentCount, singular: "agent", plural: "agents"))
        }
        if attachmentMetadataEnabled, session.imageAttachmentCount > 0 {
            parts.append(pluralized(session.imageAttachmentCount, singular: "whole-session image", plural: "whole-session images"))
        }
        return parts.joined(separator: " · ")
    }
}

struct ProjectDetailView: View {
    @EnvironmentObject private var store: UsageStore
    let id: String
    let range: AnalyticsRange

    var body: some View {
        ContentFittingScrollView {
            if let snapshot = store.analyticsSnapshots[range],
               let project = snapshot.projects.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 14) {
                    analyticsHeader(project.name, tokens: project.usage.totalTokens)
                    if store.provider.supportsCostEstimates {
                        EstimatedCostText(
                            models: project.models,
                            through: snapshot.through,
                            quality: snapshot.quality,
                            compact: false
                        )
                    }
                    LabeledContent("Sessions", value: project.sessionCount.formatted())
                    usageBreakdown(project.usage)
                    modelRows(project.models)
                }
                .padding(16)
            }
        }
        .frame(width: MenuPopoverMetrics.width)
    }
}

struct SessionDetailView: View {
    @EnvironmentObject private var store: UsageStore
    let id: String
    let range: AnalyticsRange
    @AppStorage("agentDetailsEnabled") private var agentDetailsEnabled = AppPreferences.defaultAgentDetailsEnabled
    @AppStorage("attachmentMetadataEnabled") private var attachmentMetadataEnabled = AppPreferences.defaultAttachmentMetadataEnabled

    var body: some View {
        ContentFittingScrollView {
            if let snapshot = store.analyticsSnapshots[range],
               let session = snapshot.sessions.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 14) {
                    analyticsHeader(session.displayName, tokens: session.usage.totalTokens)
                    if store.provider.supportsCostEstimates {
                        EstimatedCostText(
                            models: session.models,
                            through: snapshot.through,
                            quality: snapshot.quality,
                            compact: false
                        )
                    }
                    LabeledContent("Last activity", value: session.lastActivityAt.formatted(date: .abbreviated, time: .shortened))
                    if let startedAt = session.startedAt {
                        LabeledContent("Started", value: startedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if agentDetailsEnabled {
                        LabeledContent("Direct sub-agents", value: session.directSubagentCount.formatted())
                        agentRows(for: session)
                    }
                    if attachmentMetadataEnabled, store.provider == .codex {
                        LabeledContent("Whole-session images", value: session.imageAttachmentCount.formatted())
                            .help("Counts cover the whole session after the local-history cutoff, not just this range. Local metadata may be incomplete; attachment contents are never stored.")
                    }
                    usageBreakdown(session.usage)
                    modelRows(session.models)
                }
                .padding(16)
            }
        }
        .frame(width: MenuPopoverMetrics.width)
    }

    @ViewBuilder
    private func agentRows(for session: SessionUsageSummary) -> some View {
        let children = store.analyticsSnapshots[range]?.sessions.filter { $0.parentSessionID == session.id } ?? []
        if !children.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Text("Sub-agents").font(.subheadline.weight(.semibold))
                ForEach(children) { child in
                    MenuLink(destination: .session(id: child.id, range: range)) {
                        HStack {
                            Text(child.displayName).lineLimit(1)
                            Spacer()
                            Text(child.usage.totalTokens.formatted()).monospacedDigit().foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .font(.caption)
                }
                Text("Sub-agent tokens are separate from this total.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

struct ModelDetailView: View {
    @EnvironmentObject private var store: UsageStore
    let id: String
    let range: AnalyticsRange

    var body: some View {
        ContentFittingScrollView {
            if let snapshot = store.analyticsSnapshots[range],
               let model = snapshot.models.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 14) {
                    analyticsHeader(model.displayName, tokens: model.usage.totalTokens)
                    if store.provider.supportsCostEstimates {
                        EstimatedCostText(
                            models: [model],
                            through: snapshot.through,
                            quality: snapshot.quality,
                            compact: false
                        )
                    }
                    usageBreakdown(model.usage)
                    LabeledContent(
                        "Projects",
                        value: snapshot.projects.filter { $0.models.contains(where: { $0.id == id }) }.count.formatted()
                    )
                    LabeledContent(
                        "Sessions",
                        value: snapshot.sessions.filter { $0.models.contains(where: { $0.id == id }) }.count.formatted()
                    )
                }
                .padding(16)
            }
        }
        .frame(width: MenuPopoverMetrics.width)
    }
}

struct EstimatedCostLabel: View {
    let snapshot: AnalyticsSnapshot
    let showsUnavailable: Bool

    init(snapshot: AnalyticsSnapshot, showsUnavailable: Bool = true) {
        self.snapshot = snapshot
        self.showsUnavailable = showsUnavailable
    }

    var body: some View {
        EstimatedCostText(
            models: snapshot.models,
            through: snapshot.through,
            quality: snapshot.quality,
            compact: false,
            showsUnavailable: showsUnavailable
        )
    }
}

struct EstimatedCostText: View {
    @AppStorage("costEstimatesEnabled") private var costEstimatesEnabled = AppPreferences.defaultCostEstimatesEnabled
    let models: [ModelUsageSummary]
    let through: Date
    let quality: DataQuality
    let compact: Bool
    let showsUnavailable: Bool

    nonisolated init(
        models: [ModelUsageSummary],
        through: Date,
        quality: DataQuality,
        compact: Bool,
        showsUnavailable: Bool = true
    ) {
        self.models = models
        self.through = through
        self.quality = quality
        self.compact = compact
        self.showsUnavailable = showsUnavailable
    }

    var body: some View {
        if costEstimatesEnabled {
            if let amount = estimatedCost(for: models, through: through, quality: quality) {
                Text(compact ? "~\(currency(amount))" : "Estimated API cost · ~\(currency(amount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Current official API pricing estimate. This is not a bill or subscription charge.")
            } else if showsUnavailable {
                Text("Estimated cost unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(
                        quality == .exact
                            ? "Some records have unknown models or incomplete pricing metadata."
                            : "Local usage is incomplete, so a complete cost estimate cannot be shown."
                    )
            }
        }
    }
}

@ViewBuilder
func analyticsRow(
    _ title: String,
    detail: String? = nil,
    tokens: Int64,
    models: [ModelUsageSummary],
    through: Date,
    quality: DataQuality,
    horizontalPadding: CGFloat = 16
) -> some View {
    HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .help(title)
                Spacer(minLength: 8)
                Text(tokens.formatted())
                    .font(.subheadline.monospacedDigit())
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(detail)
                }
                Spacer(minLength: 0)
                // Unknown costs belong in the item's detail, not on every list row.
                EstimatedCostText(models: models, through: through, quality: quality, compact: true, showsUnavailable: false)
                    .lineLimit(1)
            }
        }
        Image(systemName: "chevron.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.vertical, 10)
    .contentShape(Rectangle())
}

@ViewBuilder
private func analyticsHeader(_ title: String, tokens: Int64) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.headline)
        Text(tokens.formatted())
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        Text("tokens").font(.caption).foregroundStyle(.secondary)
    }
}

@ViewBuilder
private func usageBreakdown(_ usage: TokenUsage) -> some View {
    VStack(spacing: 6) {
        LabeledContent("Input", value: usage.inputTokens.formatted())
        LabeledContent("Cached input", value: usage.cachedInputTokens.formatted())
        LabeledContent("Output", value: usage.outputTokens.formatted())
    }
    .font(.subheadline)
}

@ViewBuilder
private func modelRows(_ models: [ModelUsageSummary]) -> some View {
    VStack(alignment: .leading, spacing: 7) {
        Text("Models").font(.subheadline.weight(.semibold))
        ForEach(models) { model in
            HStack {
                Text(model.displayName).lineLimit(1)
                Spacer()
                Text(model.usage.totalTokens.formatted()).monospacedDigit().foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }
}

private func estimatedCost(
    for models: [ModelUsageSummary],
    through: Date,
    quality: DataQuality
) -> Decimal? {
    guard quality == .exact else { return nil }
    let samples = models.map {
        ModelTokenUsageSample(
            modelID: $0.modelID ?? "unknown",
            usage: $0.usage,
            highContextUsage: $0.highContextUsage,
            hasUnknownPricingContext: $0.hasUnknownPricingContext,
            occurredAt: through
        )
    }
    return CostEstimator().estimate(samples).amountUSD
}

private func currency(_ value: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.maximumFractionDigits = value < 1 ? 4 : 2
    return formatter.string(from: value as NSDecimalNumber) ?? "$—"
}

private func pluralized(_ count: Int, singular: String, plural: String) -> String {
    "\(count) \(count == 1 ? singular : plural)"
}

@MainActor
@ViewBuilder
private func analyticsPlaceholder(store: UsageStore, title: String, minimumHeight: CGFloat) -> some View {
    if store.isAnalyticsRefreshing || store.analyticsStatusMessage == "Analytics are ready to load" {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(store.analyticsStatusMessage).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight)
    } else {
        ContentUnavailableView(
            title,
            systemImage: "chart.xyaxis.line",
            description: Text(store.analyticsStatusMessage)
        )
        .frame(maxWidth: .infinity, minHeight: minimumHeight)
    }
}

@MainActor
@ViewBuilder
private func analyticsSnapshotStatus(_ store: UsageStore) -> some View {
    if store.analyticsStatusMessage == "Showing the last analytics snapshot" {
        Label(store.analyticsStatusMessage, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
}
