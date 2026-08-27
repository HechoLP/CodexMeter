import Foundation

struct UsageNormalizationState: Equatable, Sendable {
    var cumulativeHighWaterMark: TokenUsage?
    var quality: DataQuality

    static let empty = UsageNormalizationState(cumulativeHighWaterMark: nil, quality: .exact)
}

struct UsageNormalizationResult: Equatable, Sendable {
    let delta: TokenUsage?
    let state: UsageNormalizationState
    let diagnostic: String?
}

struct UsageNormalizer: Sendable {
    func normalize(
        _ observation: CodexTokenObservation,
        metadata: SessionMetadata?,
        state: UsageNormalizationState
    ) -> UsageNormalizationResult {
        guard let cumulative = observation.cumulativeUsage else {
            return UsageNormalizationResult(
                delta: nil,
                state: UsageNormalizationState(
                    cumulativeHighWaterMark: state.cumulativeHighWaterMark,
                    quality: .partial
                ),
                diagnostic: "missing cumulative token usage"
            )
        }

        guard let previous = state.cumulativeHighWaterMark else {
            if metadata?.inheritsHistory == true {
                return UsageNormalizationResult(
                    delta: nil,
                    state: UsageNormalizationState(cumulativeHighWaterMark: cumulative, quality: .partial),
                    diagnostic: "inherited history baseline is unresolved"
                )
            }

            guard observation.lastUsage == cumulative else {
                return UsageNormalizationResult(
                    delta: nil,
                    state: UsageNormalizationState(cumulativeHighWaterMark: cumulative, quality: .partial),
                    diagnostic: "initial cumulative baseline is unresolved"
                )
            }

            return UsageNormalizationResult(
                delta: cumulative == .zero ? nil : cumulative,
                state: UsageNormalizationState(cumulativeHighWaterMark: cumulative, quality: state.quality),
                diagnostic: nil
            )
        }

        guard cumulative.isComponentWiseAtLeast(previous) else {
            if observation.lastUsage == cumulative {
                return UsageNormalizationResult(
                    delta: cumulative == .zero ? nil : cumulative,
                    state: UsageNormalizationState(cumulativeHighWaterMark: cumulative, quality: .partial),
                    diagnostic: "cumulative counter restarted"
                )
            }

            return UsageNormalizationResult(
                delta: nil,
                state: UsageNormalizationState(
                    cumulativeHighWaterMark: previous.componentWiseMaximum(with: cumulative),
                    quality: .partial
                ),
                diagnostic: "cumulative token usage decreased or interleaved"
            )
        }

        let delta = cumulative.subtractingFloorAtZero(previous)
        return UsageNormalizationResult(
            delta: delta == .zero ? nil : delta,
            state: UsageNormalizationState(cumulativeHighWaterMark: cumulative, quality: state.quality),
            diagnostic: nil
        )
    }
}
