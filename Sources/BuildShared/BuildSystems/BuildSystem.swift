import Foundation

/// Protocol for build system implementations
/// Internal protocol - users extend BaseBuild, not BuildSystem directly
internal protocol BuildSystem {
    /// Human-readable name of the build system
    static var name: String { get }
    
    /// Check if this build system can handle the source directory
    /// - Parameter directory: Source directory URL
    /// - Returns: true if this build system should be used
    static func detect(in directory: URL) -> Bool
    
    /// Configure the build
    /// - Parameters:
    ///   - buildURL: Build/scratch directory
    ///   - sourceURL: Source code directory
    ///   - platform: Target platform
    ///   - arch: Target architecture
    ///   - environment: Environment variables
    ///   - arguments: Additional configure arguments
    /// - Throws: BuildError if configuration fails
    func configure(
        buildURL: URL,
        sourceURL: URL,
        platform: PlatformType,
        arch: ArchType,
        environment: [String: String],
        arguments: [String]
    ) throws
    
    /// Execute the build
    /// - Parameters:
    ///   - buildURL: Build directory
    ///   - platform: Target platform
    ///   - arch: Target architecture
    ///   - environment: Environment variables
    /// - Throws: BuildError if build fails
    func build(
        buildURL: URL,
        platform: PlatformType,
        arch: ArchType,
        environment: [String: String]
    ) throws
    
    /// Install the built artifacts
    /// - Parameters:
    ///   - buildURL: Build directory
    ///   - platform: Target platform
    ///   - arch: Target architecture
    ///   - environment: Environment variables
    /// - Throws: BuildError if installation fails
    func install(
        buildURL: URL,
        platform: PlatformType,
        arch: ArchType,
        environment: [String: String]
    ) throws
}

/// Protocol for build systems that can be initialized with no arguments
internal protocol InitializableBuildSystem: BuildSystem {
    init()
}
