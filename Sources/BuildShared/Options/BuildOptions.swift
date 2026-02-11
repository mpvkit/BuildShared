import Foundation

/// Internal representation of build options
/// Used internally while ArgumentOptions maintains public API compatibility
internal struct BuildOptions {
    var isDebug: Bool
    var isGPL: Bool
    var splitPlatforms: Bool
    var platforms: [PlatformType]
    var releaseVersion: String
    
    init(
        isDebug: Bool = false,
        isGPL: Bool = false,
        splitPlatforms: Bool = false,
        platforms: [PlatformType] = [],
        releaseVersion: String = "0.0.0"
    ) {
        self.isDebug = isDebug
        self.isGPL = isGPL
        self.splitPlatforms = splitPlatforms
        self.platforms = platforms
        self.releaseVersion = releaseVersion
    }
    
    /// Parse from command line arguments
    static func parse(_ arguments: [String]) throws -> BuildOptions {
        var options = BuildOptions()
        
        for argument in arguments {
            switch argument {
            case "enable-debug":
                options.isDebug = true
            case "enable-gpl":
                options.isGPL = true
            case "enable-split-platform":
                options.splitPlatforms = true
            default:
                if argument.hasPrefix("version=") {
                    options.releaseVersion = String(argument.dropFirst("version=".count))
                }
                if argument.hasPrefix("platform=") {
                    options.platforms = try parsePlatforms(String(argument.dropFirst("platform=".count)))
                }
            }
        }
        
        return options
    }
    
    private static func parsePlatforms(_ value: String) throws -> [PlatformType] {
        var platforms: [PlatformType] = []
        
        for val in value.split(separator: ",") {
            let platformStr = val.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch platformStr {
            case "ios":
                platforms += [.ios, .isimulator]
            case "tvos":
                platforms += [.tvos, .tvsimulator]
            case "xros":
                platforms += [.xros, .xrsimulator]
            default:
                guard let platform = PlatformType(rawValue: platformStr) else {
                    throw BuildError.unknownPlatform(String(val))
                }
                if !platforms.contains(platform) {
                    platforms.append(platform)
                }
            }
        }
        
        return platforms
    }
}

/// Internal build context for managing build state
/// Replaces global variables while maintaining compatibility
internal class BuildContext {
    let options: BuildOptions
    let platforms: [PlatformType]
    
    init(options: BuildOptions) {
        self.options = options
        self.platforms = options.platforms.isEmpty ? PlatformType.allCases : options.platforms
    }
}
