import Foundation

struct TokenUsage: Codable, Equatable, Sendable {
    let inputTokens: Int64
    let cachedInputTokens: Int64
    let outputTokens: Int64

    static let zero = TokenUsage(inputTokens: 0, cachedInputTokens: 0, outputTokens: 0)

    var totalTokens: Int64 {
        inputTokens
            .saturatedAdding(cachedInputTokens)
            .saturatedAdding(outputTokens)
    }

    var isValid: Bool {
        inputTokens >= 0
            && cachedInputTokens >= 0
            && outputTokens >= 0
            && cachedInputTokens <= inputTokens
    }

    func adding(_ other: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: inputTokens.saturatedAdding(other.inputTokens),
            cachedInputTokens: cachedInputTokens.saturatedAdding(other.cachedInputTokens),
            outputTokens: outputTokens.saturatedAdding(other.outputTokens)
        )
    }

    func subtractingFloorAtZero(_ previous: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: max(0, inputTokens - previous.inputTokens),
            cachedInputTokens: max(0, cachedInputTokens - previous.cachedInputTokens),
            outputTokens: max(0, outputTokens - previous.outputTokens)
        )
    }

    func componentWiseMaximum(with other: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: max(inputTokens, other.inputTokens),
            cachedInputTokens: max(cachedInputTokens, other.cachedInputTokens),
            outputTokens: max(outputTokens, other.outputTokens)
        )
    }

    func isComponentWiseAtLeast(_ other: TokenUsage) -> Bool {
        inputTokens >= other.inputTokens
            && cachedInputTokens >= other.cachedInputTokens
            && outputTokens >= other.outputTokens
    }
}

private extension Int64 {
    func saturatedAdding(_ other: Int64) -> Int64 {
        let result = addingReportingOverflow(other)
        return result.overflow ? Int64.max : result.partialValue
    }
}
