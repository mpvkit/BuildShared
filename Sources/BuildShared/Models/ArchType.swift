import Foundation

/// Represents CPU architecture types supported for building
public enum ArchType: String, CaseIterable {
    // swiftlint:disable identifier_name
    case arm64, x86_64, arm64e
    // swiftlint:enable identifier_name
    
    /// Returns true if this architecture matches the current executable's architecture
    public var executable: Bool {
        guard let architecture = Bundle.main.executableArchitectures?.first?.intValue else {
            return false
        }
        // NSBundleExecutableArchitectureARM64
        if architecture == 0x0100_000C, self == .arm64 {
            return true
        } else if architecture == NSBundleExecutableArchitectureX86_64, self == .x86_64 {
            return true
        }
        return false
    }
    
    /// CPU family name used by build systems (e.g., "aarch64" for ARM64)
    public var cpuFamily: String {
        switch self {
        case .arm64, .arm64e:
            return "aarch64"
        case .x86_64:
            return "x86_64"
        }
    }
    
    /// Target CPU name used by compilers (e.g., "arm64" or "x86_64")
    public var targetCpu: String {
        switch self {
        case .arm64, .arm64e:
            return "arm64"
        case .x86_64:
            return "x86_64"
        }
    }
    
    /// The architecture of the current host machine
    public static var hostArch: ArchType {
        #if arch(arm64)
        return .arm64
        #else
        return .x86_64
        #endif
    }
}
