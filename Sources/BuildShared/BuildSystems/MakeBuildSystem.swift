import Foundation

internal struct MakeBuildSystem: InitializableBuildSystem {
    static var name: String { "Make" }
    
    static func detect(in directory: URL) -> Bool {
        // Always detectable (fallback)
        true
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
        // Run autogen if exists
        let autogen = sourceURL + "autogen.sh"
        if FileManager.default.fileExists(atPath: autogen.path) {
            var env = environment
            env["NOCONFIGURE"] = "1"
            try Utility.launch(
                executableURL: autogen,
                arguments: [],
                currentDirectoryURL: sourceURL,
                environment: env
            )
        }
        
        // Run bootstrap if configure doesn't exist
        let configure = sourceURL + "configure"
        if !FileManager.default.fileExists(atPath: configure.path) {
            var bootstrap = sourceURL + "bootstrap"
            if !FileManager.default.fileExists(atPath: bootstrap.path) {
                bootstrap = sourceURL + ".bootstrap"
            }
            if FileManager.default.fileExists(atPath: bootstrap.path) {
                try Utility.launch(
                    executableURL: bootstrap,
                    arguments: [],
                    currentDirectoryURL: sourceURL,
                    environment: environment
                )
            }
        }
        
        // Run configure
        if FileManager.default.fileExists(atPath: configure.path) {
            let prefixPath = prefix?.path ?? buildURL.path
            var args = ["--prefix=\(prefixPath)"]
            args.append(contentsOf: arguments)
            try Utility.launch(
                executableURL: configure,
                arguments: args,
                currentDirectoryURL: buildURL,
                environment: environment
            )
        }
    }
    
    func build(
        buildURL: URL,
        platform: PlatformType,
        arch: ArchType,
        environment: [String: String]
    ) throws {
        try Utility.launch(
            path: "/usr/bin/make",
            arguments: ["-j8"],
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
        try Utility.launch(
            path: "/usr/bin/make",
            arguments: ["-j8", "install"],
            currentDirectoryURL: buildURL,
            environment: environment
        )
    }
}
