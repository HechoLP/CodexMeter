import Darwin
import Foundation

enum CredentialFileSecurity {
    /// POSIX 0600/0700 does not override macOS extended ACL grants. Inspect the
    /// opened inode, not its pathname. Deny entries and grants to this user are
    /// safe; reject other grants (including inheritance-only entries) and errors.
    static func hasOwnerOnlyACL(_ descriptor: Int32) -> Bool {
        guard let acl = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED) else {
            // On macOS a valid inode with no extended ACL returns ENOENT.
            // Unsupported ACL queries and other inspection errors stay closed.
            var info = stat()
            return errno == ENOENT && fstat(descriptor, &info) == 0
        }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        guard acl_valid(acl) == 0 else { return false }
        var entry: acl_entry_t?
        var position = ACL_FIRST_ENTRY.rawValue
        while true {
            errno = 0
            // Darwin returns -1/EINVAL at the end of a valid ACL, including an
            // empty ACL (unlike the POSIX API's 0-at-end convention).
            guard acl_get_entry(acl, position, &entry) == 0 else { return errno == EINVAL }
            position = ACL_NEXT_ENTRY.rawValue
            guard let entry else { return false }
            var tag = ACL_UNDEFINED_TAG
            guard acl_get_tag_type(entry, &tag) == 0 else { return false }
            if tag == ACL_EXTENDED_DENY { continue }
            guard tag == ACL_EXTENDED_ALLOW, isCurrentUser(entry) else { return false }
        }
    }

    private static func isCurrentUser(_ entry: acl_entry_t) -> Bool {
        guard let qualifier = acl_get_qualifier(entry) else { return false }
        defer { acl_free(qualifier) }
        var account = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: 16_384)
        guard getpwuuid_r(qualifier.assumingMemoryBound(to: UInt8.self), &account,
                         &buffer, buffer.count, &result) == 0, result != nil
        else { return false }
        return account.pw_uid == geteuid()
    }

    /// Check inheritance BEFORE mkdir: removing a grant after creation cannot
    /// revoke a descriptor another user already opened. Never repair user ACLs.
    static func makeTemporaryHome(
        in parent: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let parentFD = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parentFD >= 0 else { throw AccountSwitchError.unsafeFile }
        defer { close(parentFD) }
        var info = stat()
        guard fstat(parentFD, &info) == 0, info.st_uid == geteuid(),
              info.st_mode & 0o022 == 0, hasOwnerOnlyACL(parentFD)
        else { throw AccountSwitchError.unsafeFile }
        let name = "codexmeter-account-\(UUID().uuidString)"
        guard mkdirat(parentFD, name, 0o700) == 0 else { throw AccountSwitchError.unsafeFile }
        var accepted = false
        defer { if !accepted { unlinkat(parentFD, name, AT_REMOVEDIR) } }
        let directoryFD = openat(parentFD, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directoryFD >= 0 else { throw AccountSwitchError.unsafeFile }
        defer { close(directoryFD) }
        guard fstat(directoryFD, &info) == 0, info.st_uid == geteuid(),
              info.st_mode & 0o077 == 0, hasOwnerOnlyACL(directoryFD)
        else { throw AccountSwitchError.unsafeFile }
        accepted = true
        return parent.appendingPathComponent(name, isDirectory: true)
    }
}
