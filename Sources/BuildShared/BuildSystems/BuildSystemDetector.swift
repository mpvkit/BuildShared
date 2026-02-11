import Foundation

/// Detects and provides appropriate build system for a directory
internal enum BuildSystemDetector {
    /// All available build systems in priority order
    /// Priority: Meson > CMake > Waf > Make
    private static let buildSystems: [InitializableBuildSystem.Type] = [
        MesonBuildSystem.self,
        CMakeBuildSystem.self,
        WafBuildSystem.self,
        MakeBuildSystem.self
    ]
    
    /// Detect the appropriate build system for a directory
    /// - Parameter directory: Source directory to check
    /// - Returns: BuildSystem instance or nil if none detected
    static func detect(in directory: URL) -> BuildSystem? {
        for systemType in buildSystems {
            if systemType.detect(in: directory) {
                return systemType.init()
            }
        }
        return nil
    }
    
    /// Detect with fallback to MakeBuildSystem
    /// - Parameter directory: Source directory to check
    /// - Returns: BuildSystem instance (always returns a value)
    static func detectOrMake(in directory: URL) -> BuildSystem {
        detect(in: directory) ?? MakeBuildSystem()
    }
}
