import ArgumentParser
import Foundation

/// Internal command for parsing build arguments
/// Uses Swift Argument Parser for modern CLI experience
internal struct BuildCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "build-shared",
        abstract: "Build shared libraries for multiple Apple platforms"
    )
    
    @Flag(name: .long, help: "Enable debug mode")
    var enableDebug: Bool = false
    
    @Flag(name: .long, help: "Enable GPL features")
    var enableGPL: Bool = false
    
    @Flag(name: .long, help: "Enable split platform XCFrameworks")
    var enableSplitPlatform: Bool = false
    
    @Option(
        name: .long,
        help: "Release version (e.g., 1.2.3)"
    )
    var version: String = "0.0.0"
    
    @Option(
        name: .long,
        parsing: .upToNextOption,
        help: "Target platforms (ios, macos, tvos, xros, or comma-separated list)"
    )
    var platform: [String] = []
    
    /// Returns the parsed platforms from the platform strings
    var parsedPlatforms: [PlatformType] {
        var parsedPlatforms: [PlatformType] = []
        
        for platformStr in platform {
            for val in platformStr.split(separator: ",") {
                let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                switch trimmed {
                case "ios":
                    parsedPlatforms += [.ios, .isimulator]
                case "tvos":
                    parsedPlatforms += [.tvos, .tvsimulator]
                case "xros":
                    parsedPlatforms += [.xros, .xrsimulator]
                default:
                    if let p = PlatformType(rawValue: trimmed), !parsedPlatforms.contains(p) {
                        parsedPlatforms.append(p)
                    }
                }
            }
        }
        
        return parsedPlatforms
    }
    
    /// Validates the parsed arguments
    func validate() throws {
        // Validate platforms
        for platformStr in platform {
            for val in platformStr.split(separator: ",") {
                let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                switch trimmed {
                case "ios", "tvos", "xros":
                    continue
                default:
                    guard PlatformType(rawValue: trimmed) != nil else {
                        throw ValidationError("Unknown platform: \(val)")
                    }
                }
            }
        }
    }
    
    /// Converts to internal BuildOptions
    var buildOptions: BuildOptions {
        BuildOptions(
            isDebug: enableDebug,
            isGPL: enableGPL,
            splitPlatforms: enableSplitPlatform,
            platforms: parsedPlatforms,
            releaseVersion: version
        )
    }
}
