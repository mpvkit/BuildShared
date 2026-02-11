import Foundation

internal struct MesonBuildSystem: InitializableBuildSystem {
    static var name: String { "Meson" }
    
    static func detect(in directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: (directory + "meson.build").path)
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
        // Ensure meson and ninja are installed
        if Utility.shell("which meson") == nil {
            Utility.shell("brew install meson")
        }
        if Utility.shell("which ninja") == nil {
            Utility.shell("brew install ninja")
        }
        
        let crossFile = createCrossFile(
            buildURL: buildURL,
            platform: platform,
            arch: arch,
            environment: environment,
            prefix: prefix
        )
        
        let meson = Utility.shell("which meson", isOutput: true)!
        try Utility.launch(
            path: meson,
            arguments: ["setup", buildURL.path, "--cross-file=\(crossFile.path)"] + arguments,
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
        let meson = Utility.shell("which meson", isOutput: true)!
        try Utility.launch(
            path: meson,
            arguments: ["compile", "--clean"],
            currentDirectoryURL: buildURL,
            environment: environment
        )
        try Utility.launch(
            path: meson,
            arguments: ["compile", "--verbose"],
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
        let meson = Utility.shell("which meson", isOutput: true)!
        try Utility.launch(
            path: meson,
            arguments: ["install"],
            currentDirectoryURL: buildURL,
            environment: environment
        )
    }
    
    private func createCrossFile(
        buildURL: URL,
        platform: PlatformType,
        arch: ArchType,
        environment: [String: String],
        prefix: URL?
    ) -> URL {
        let crossFile = buildURL + "crossFile.meson"
        let prefixPath = prefix ?? buildURL
        
        // Extract cFlags and ldFlags from environment
        let cFlagsStr = environment["CFLAGS"] ?? ""
        let ldFlagsStr = environment["LDFLAGS"] ?? ""
        
        let cFlags = cFlagsStr.split(separator: " ").map { "'\($0)'" }.joined(separator: ", ")
        let ldFlags = ldFlagsStr.split(separator: " ").map { "'\($0)'" }.joined(separator: ", ")
        
        let content = """
        [binaries]
        c = '/usr/bin/clang'
        cpp = '/usr/bin/clang++'
        objc = '/usr/bin/clang'
        objcpp = '/usr/bin/clang++'
        ar = '\(platform.xcrunFind(tool: "ar"))'
        strip = '\(platform.xcrunFind(tool: "strip"))'
        pkg-config = 'pkg-config'

        [properties]
        has_function_printf = true
        has_function_hfkerhisadf = false

        [host_machine]
        system = 'darwin'
        subsystem = '\(platform.mesonSubSystem)'
        kernel = 'xnu'
        cpu_family = '\(arch.cpuFamily)'
        cpu = '\(arch.targetCpu)'
        endian = 'little'

        [built-in options]
        default_library = 'static'
        buildtype = 'release'
        prefix = '\(prefixPath.path)'
        c_args = [\(cFlags)]
        cpp_args = [\(cFlags)]
        objc_args = [\(cFlags)]
        objcpp_args = [\(cFlags)]
        c_link_args = [\(ldFlags)]
        cpp_link_args = [\(ldFlags)]
        objc_link_args = [\(ldFlags)]
        objcpp_link_args = [\(ldFlags)]
        """
        
        FileManager.default.createFile(
            atPath: crossFile.path,
            contents: content.data(using: .utf8),
            attributes: nil
        )
        
        return crossFile
    }
}
