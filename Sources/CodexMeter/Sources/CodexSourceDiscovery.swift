import Darwin
import Foundation

struct CodexSessionSource: Equatable, Sendable {
    let url: URL
    let identity: String
    let size: Int64
}

struct CodexSourceDiscovery: Sendable {
    func defaultRoots(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        let codex = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        return [
            codex.appendingPathComponent("sessions", isDirectory: true),
            codex.appendingPathComponent("archived_sessions", isDirectory: true)
        ]
    }

    func discover(in roots: [URL]) throws -> [CodexSessionSource] {
        var discovered: [CodexSessionSource] = []
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]

        for root in roots {
            let rootPath = root.standardizedFileURL.path
            guard FileManager.default.fileExists(atPath: rootPath) else { continue }
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let candidate as URL in enumerator {
                try Task.checkCancellation()
                let values = try candidate.resourceValues(forKeys: Set(keys))
                if values.isSymbolicLink == true {
                    if values.isDirectory == true { enumerator.skipDescendants() }
                    continue
                }
                guard values.isRegularFile == true, candidate.pathExtension == "jsonl" else { continue }

                let standardized = candidate.standardizedFileURL
                guard standardized.path == rootPath || standardized.path.hasPrefix(rootPath + "/") else {
                    continue
                }
                guard let stat = fileStat(at: standardized.path), stat.isRegular else { continue }
                discovered.append(
                    CodexSessionSource(
                        url: standardized,
                        identity: "\(stat.device):\(stat.inode)",
                        size: stat.size
                    )
                )
            }
        }

        return discovered.sorted { $0.url.path < $1.url.path }
    }

    private func fileStat(at path: String) -> (device: UInt64, inode: UInt64, size: Int64, isRegular: Bool)? {
        var value = stat()
        guard lstat(path, &value) == 0 else { return nil }
        let fileType = value.st_mode & S_IFMT
        return (
            device: UInt64(value.st_dev),
            inode: UInt64(value.st_ino),
            size: Int64(value.st_size),
            isRegular: fileType == S_IFREG
        )
    }
}
