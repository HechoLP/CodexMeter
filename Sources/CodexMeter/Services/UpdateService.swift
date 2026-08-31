import CoreFoundation
import Foundation
import Sparkle

@MainActor
final class UpdateService {
    static let shared = UpdateService()

    private var updaterController: SPUStandardUpdaterController?

    private init() {}

    var isAvailable: Bool {
        updaterController != nil || Self.canStartUpdater(bundle: .main)
    }

    var automaticallyChecksForUpdates: Bool {
        updaterController?.updater.automaticallyChecksForUpdates
            ?? (Bundle.main.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool ?? false)
    }

    func start() {
        guard updaterController == nil, Self.canStartUpdater(bundle: .main) else { return }
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        start()
        updaterController?.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        start()
        updaterController?.checkForUpdates(nil)
    }

    nonisolated static func canStartUpdater(bundle: Bundle) -> Bool {
        canStartUpdater(
            bundleURL: bundle.bundleURL,
            infoDictionary: bundle.infoDictionary ?? [:]
        )
    }

    nonisolated static func canStartUpdater(
        bundleURL: URL,
        infoDictionary: [String: Any]
    ) -> Bool {
        guard bundleURL.pathExtension == "app",
              let feed = infoDictionary["SUFeedURL"] as? String,
              let feedURL = URL(string: feed),
              feedURL.scheme == "https",
              feedURL.host != nil,
              let publicKey = infoDictionary["SUPublicEDKey"] as? String,
              !publicKey.isEmpty,
              infoDictionary["SURequireSignedFeed"] as? Bool == true,
              infoDictionary["SUVerifyUpdateBeforeExtraction"] as? Bool == true,
              let expiration = infoDictionary["SUSignedFeedFailureExpirationInterval"] as? NSNumber,
              CFGetTypeID(expiration) != CFBooleanGetTypeID(),
              expiration.doubleValue == 0 else {
            return false
        }
        // Sparkle otherwise allows failed-signature feed metadata after 20 days.
        // Zero keeps authentication mandatory indefinitely, including key rotation.
        return true
    }
}
