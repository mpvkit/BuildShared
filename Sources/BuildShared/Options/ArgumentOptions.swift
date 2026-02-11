import Foundation
import ArgumentParser

/// Public options class that maintains API compatibility
/// Internally uses ArgumentParser for modern CLI parsing
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
        // Use ArgumentParser internally
        do {
            let command = try BuildCommand.parseAsRoot(arguments)
            
            guard let buildCommand = command as? BuildCommand else {
                throw NSError(domain: "BuildShared", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to parse command"
                ])
            }
            
            // Convert to legacy ArgumentOptions format
            let options = ArgumentOptions(arguments: Array(arguments.dropFirst()))
            options.enableDebug = buildCommand.enableDebug
            options.enableGPL = buildCommand.enableGPL
            options.enableSplitPlatform = buildCommand.enableSplitPlatform
            options.platforms = buildCommand.parsedPlatforms
            options.releaseVersion = buildCommand.version
            
            return options
        } catch let error as ValidationError {
            // Convert ArgumentParser validation error to NSError
            throw NSError(domain: "BuildShared", code: 1, userInfo: [
                NSLocalizedDescriptionKey: error.message
            ])
        } catch {
            // Re-throw other errors as NSError
            throw NSError(domain: "BuildShared", code: 1, userInfo: [
                NSLocalizedDescriptionKey: error.localizedDescription
            ])
        }
    }
}
