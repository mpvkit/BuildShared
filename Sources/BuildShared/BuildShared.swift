import Foundation

// Re-export all public types from submodules
// This maintains API compatibility with existing code

// BuildRunner - maintains API namespace for main commands
public enum BuildRunner {
    @discardableResult
    public static func performCommand(_ options: ArgumentOptions? = nil) throws -> ArgumentOptions {
        let finalOptions = try options ?? ArgumentOptions.parse(CommandLine.arguments)
        
        if Utility.shell("which brew") == nil {
            print("""
            You need to run the script first
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            """)
            return finalOptions
        }
        if Utility.shell("which pkg-config") == nil {
            Utility.shell("brew install pkg-config")
        }
        if Utility.shell("which wget") == nil {
            Utility.shell("brew install wget")
        }
        let path = URL.currentDirectory + "dist"
        if !FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: false, attributes: nil)
        }
        try? Utility.removeFiles(extensions: [".swift"], currentDirectoryURL: URL.currentDirectory + ["dist", "release"])
        FileManager.default.changeCurrentDirectoryPath(path.path)
        
        return finalOptions
    }
}
