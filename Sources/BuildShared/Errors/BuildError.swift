import Foundation

/// Errors that can occur during the build process
/// Provides detailed error information while maintaining NSError compatibility
public enum BuildError: Error, LocalizedError {
    case toolNotFound(String)
    case cloneFailed(url: String, reason: String)
    case buildFailed(platform: PlatformType, arch: ArchType, reason: String)
    case invalidConfiguration(String)
    case patchApplyFailed(String)
    case fileNotFound(URL)
    case directoryCreationFailed(URL, Error)
    case commandExecutionFailed(String, Int)
    case unknownPlatform(String)
    
    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool):
            return "Required tool not found: \(tool)"
        case .cloneFailed(let url, let reason):
            return "Failed to clone repository from \(url): \(reason)"
        case .buildFailed(let platform, let arch, let reason):
            return "Build failed for \(platform.rawValue) \(arch.rawValue): \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .patchApplyFailed(let patch):
            return "Failed to apply patch: \(patch)"
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .directoryCreationFailed(let url, let error):
            return "Failed to create directory at \(url.path): \(error.localizedDescription)"
        case .commandExecutionFailed(let command, let code):
            return "Command '\(command)' failed with exit code \(code)"
        case .unknownPlatform(let platform):
            return "Unknown platform: \(platform)"
        }
    }
    
    /// Converts to NSError for backward compatibility
    public var nsError: NSError {
        let domain = "BuildShared"
        let code: Int
        let userInfo: [String: Any]
        
        switch self {
        case .toolNotFound:
            code = 1001
        case .cloneFailed:
            code = 1002
        case .buildFailed:
            code = 1003
        case .invalidConfiguration:
            code = 1004
        case .patchApplyFailed:
            code = 1005
        case .fileNotFound:
            code = 1006
        case .directoryCreationFailed:
            code = 1007
        case .commandExecutionFailed:
            code = 1008
        case .unknownPlatform:
            code = 1009
        }
        
        userInfo = [NSLocalizedDescriptionKey: errorDescription ?? "Unknown error"]
        return NSError(domain: domain, code: code, userInfo: userInfo)
    }
}
