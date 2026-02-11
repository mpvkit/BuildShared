import Foundation

internal struct WafBuildSystem: InitializableBuildSystem {
    static var name: String { "Waf" }
    
    /// Detects waf build system
    /// Looks for waf or waf-light or any waf* executable
    static func detect(in directory: URL) -> Bool {
        let wafNames = ["waf", "waf-light", "waf3"]
        for name in wafNames {
            if FileManager.default.fileExists(atPath: (directory + name).path) {
                return true
            }
        }
        return false
    }
    
    private func findWaf(in directory: URL) -> URL? {
        let wafNames = ["waf", "waf-light", "waf3"]
        for name in wafNames {
            let path = directory + name
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }
        return nil
    }
    
    func configure(
        buildURL: URL,
        sourceURL: URL,
        platform: PlatformType,
        arch: ArchType,
        environment: [String: String],
        arguments: [String],
        prefix: URL?
    ) throws {
        guard let waf = findWaf(in: sourceURL) else {
            throw BuildError.toolNotFound("waf")
        }
        
        var args = ["configure"]
        if let prefix = prefix {
            args.append("--prefix=\(prefix.path)")
        }
        args.append(contentsOf: arguments)
        
        try Utility.launch(
            path: waf.path,
            arguments: args,
            currentDirectoryURL: sourceURL,
            environment: environment
        )
    }
    
    func build(
        buildURL: URL,
        platform: PlatformType,
        arch: ArchType,
        environment: [String: String]
    ) throws {
        guard let waf = findWaf(in: buildURL) else {
            throw BuildError.toolNotFound("waf")
        }
        
        try Utility.launch(
            path: waf.path,
            arguments: ["build"],
            currentDirectoryURL: buildURL,
            environment: environment
        )
    }
    
    func install(
        buildURL: URL,
        platform: PlatformType,
        arch: ArchType,
        environment: [String: String]
    ) throws {
        guard let waf = findWaf(in: buildURL) else {
            throw BuildError.toolNotFound("waf")
        }
        
        try Utility.launch(
            path: waf.path,
            arguments: ["install"],
            currentDirectoryURL: buildURL,
            environment: environment
        )
    }
}
