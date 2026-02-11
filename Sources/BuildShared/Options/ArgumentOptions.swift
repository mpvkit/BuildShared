import Foundation

/// Public options class that maintains API compatibility
public class ArgumentOptions {
    private let arguments: [String]
    
    /// Enable debug mode
    public var enableDebug: Bool = false
    
    /// Enable split platform XCFrameworks
    public var enableSplitPlatform: Bool = false
    
    /// Enable GPL features
    public var enableGPL: Bool = false
    
    /// Target platforms (empty means all platforms)
    public var platforms: [PlatformType] = []
    
    /// Release version string
    public var releaseVersion: String = "0.0.0"
    
    /// Creates options with empty arguments
    public init() {
        self.arguments = []
    }
    
    /// Creates options with specific arguments
    public init(arguments: [String]) {
        self.arguments = arguments
    }
    
    /// Check if arguments contain a specific flag
    public func contains(_ argument: String) -> Bool {
        return arguments.firstIndex(of: argument) != nil
    }
    
    /// Parse command line arguments into options
    /// - Parameter arguments: Command line arguments (including executable path at index 0)
    /// - Returns: Parsed ArgumentOptions instance
    /// - Throws: NSError if parsing fails
    public static func parse(_ arguments: [String]) throws -> ArgumentOptions {
        let options = ArgumentOptions(arguments: Array(arguments.dropFirst()))
        for argument in arguments {
            switch argument {
            case "enable-debug":
                options.enableDebug = true
            case "enable-gpl":
                options.enableGPL = true
            case "enable-split-platform":
                options.enableSplitPlatform = true
            default:
                if argument.hasPrefix("version=") {
                    let version = String(argument.suffix(argument.count - "version=".count))
                    options.releaseVersion = version
                }
                if argument.hasPrefix("platform=") {
                    let values = String(argument.suffix(argument.count - "platform=".count))
                    for val in values.split(separator: ",") {
                        let platformStr = val.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        switch platformStr {
                        case "ios":
                            options.platforms += [PlatformType.ios, PlatformType.isimulator]
                        case "tvos":
                            options.platforms += [PlatformType.tvos, PlatformType.tvsimulator]
                        case "xros":
                            options.platforms += [PlatformType.xros, PlatformType.xrsimulator]
                        default:
                            guard let other = PlatformType(rawValue: platformStr) else {
                                throw NSError(domain: "unknown platform: \(val)", code: 1)
                            }
                            if !options.platforms.contains(other) {
                                options.platforms += [other]
                            }
                        }
                    }
                }
            }
        }
        
        return options
    }
}
