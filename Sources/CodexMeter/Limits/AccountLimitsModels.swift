import Foundation

struct AccountLimitWindow: Equatable, Sendable, Identifiable {
    let id: String
    let limitID: String
    let displayName: String
    let windowDurationMinutes: Int
    let usedPercent: Double
    let resetsAt: Date?

    var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }

    var windowLabel: String {
        switch windowDurationMinutes {
        case 270...330: return "5 hours"
        case 9_000...11_000: return "Weekly"
        default:
            if windowDurationMinutes >= 1_440 {
                let days = windowDurationMinutes / 1_440
                return "\(days) \(days == 1 ? "day" : "days")"
            }
            return "\(windowDurationMinutes) \(windowDurationMinutes == 1 ? "minute" : "minutes")"
        }
    }
}

struct ResetCreditSummary: Equatable, Sendable {
    let availableCount: Int?
    let unlimited: Bool
    let expiresAt: Date?
}

struct AccountLimitsSnapshot: Equatable, Sendable {
    let windows: [AccountLimitWindow]
    let resetCredits: ResetCreditSummary?
    let fetchedAt: Date
}

enum AccountLimitStatus: Equatable, Sendable {
    case disabled
    case loading
    case ready
    case stale
    case unavailable
}

enum AccountLimitError: Error, LocalizedError, Equatable {
    case trustedAppServerNotFound
    case processLaunchFailed
    case timedOut
    case responseTooLarge
    case malformedResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .trustedAppServerNotFound:
            "A trusted Codex app-server was not found."
        case .processLaunchFailed:
            "Codex app-server could not be started."
        case .timedOut:
            "Codex account limits timed out."
        case .responseTooLarge:
            "Codex app-server returned too much data."
        case .malformedResponse:
            "Codex app-server returned an unsupported response."
        case let .server(message):
            message
        }
    }
}
