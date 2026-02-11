import Foundation

/// Represents a binary target in the Swift Package
public class PackageTarget {
    /// The name of the target
    public let name: String
    
    /// The URL to download the binary
    public let url: String
    
    /// The checksum for verifying the binary
    public let checksum: String
    
    /// Creates a new package target
    /// - Parameters:
    ///   - name: Target name
    ///   - url: Download URL
    ///   - checksum: Verification checksum
    public init(name: String, url: String, checksum: String) {
        self.name = name
        self.url = url
        self.checksum = checksum
    }
    
    /// Factory method for creating targets
    /// - Parameters:
    ///   - name: Target name
    ///   - url: Download URL
    ///   - checksum: Verification checksum
    /// - Returns: A new PackageTarget instance
    public static func target(
        name: String,
        url: String,
        checksum: String
    ) -> PackageTarget {
        return PackageTarget(name: name, url: url, checksum: checksum)
    }
}
