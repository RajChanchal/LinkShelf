import CryptoKit
import Foundation

/// Name-based (RFC 4122 version 5) UUIDs, so re-running an import produces the
/// same identities for records that had none in the legacy format.
public enum DeterministicUUID {
    public static let linkShelfNamespace = UUID(uuid: (
        0x6B, 0x1C, 0x4E, 0x2A, 0x93, 0x57, 0x4F, 0x0D, 0xA1, 0x6E, 0x2F, 0x88, 0x5D, 0x3B, 0xC4, 0x71
    ))

    public static func make(name: String, namespace: UUID = linkShelfNamespace) -> UUID {
        var data = withUnsafeBytes(of: namespace.uuid) { Data($0) }
        data.append(Data(name.utf8))
        var bytes = Array(Insecure.SHA1.hash(data: data).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
