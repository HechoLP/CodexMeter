import AppKit
import SwiftUI

@MainActor
enum ProviderLogoAsset {
    private static let images: [UsageProvider: NSImage] = Dictionary(
        uniqueKeysWithValues: UsageProvider.allCases.compactMap { provider -> (UsageProvider, NSImage)? in
            let packagedURL = Bundle.main.url(
                forResource: provider.logoResourceName,
                withExtension: "svg",
                subdirectory: "ProviderLogos"
            )
            let url = packagedURL ?? {
                Bundle.module.url(
                    forResource: provider.logoResourceName,
                    withExtension: "svg",
                    subdirectory: "ProviderLogos"
                ) ?? Bundle.module.url(
                    forResource: provider.logoResourceName,
                    withExtension: "svg"
                )
            }()
            guard let url, let image = NSImage(contentsOf: url) else {
                return nil
            }
            image.isTemplate = true
            return (provider, image)
        }
    )

    static func image(for provider: UsageProvider) -> NSImage? {
        images[provider]
    }
}

struct ProviderLogo: View {
    let provider: UsageProvider

    var body: some View {
        Group {
            if let image = ProviderLogoAsset.image(for: provider) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else {
                Image(systemName: provider.symbol)
                    .font(.system(size: 16, weight: .medium))
            }
        }
        .frame(width: 15, height: 15)
    }
}
