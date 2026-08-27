import Foundation

enum AppPaths {
    static var applicationSupportDirectory: URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("CodexMeter", isDirectory: true)
    }

    static var databaseURL: URL {
        applicationSupportDirectory.appendingPathComponent("CodexMeter.sqlite")
    }

    static var logDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
    }

    @discardableResult
    static func prepareApplicationSupportDirectory(
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = applicationSupportDirectory
        try prepareOwnerOnlyDirectory(at: directory, fileManager: fileManager)
        return directory
    }

    static func prepareOwnerOnlyDirectory(
        at directory: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
    }
}
