import Foundation

internal struct CMakeBuildSystem: InitializableBuildSystem {
    static var name: String { "CMake" }
    
    static func detect(in directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: (directory + "CMakeLists.txt").path)
    }
    
    func configure(
        buildURL: URL,
        sourceURL: URL,
        platform: PlatformType,
        arch: ArchType,
        environment: [String: String],
        arguments: [String]
    ) throws {
        if Utility.shell("which cmake") == nil {
            Utility.shell("brew install cmake")
        }
        
        let cmake = Utility.shell("which cmake", isOutput: true)!
        let thinDirPath = buildURL.path
        
        var cmakeArgs = [
            sourceURL.path,
            "-DCMAKE_VERBOSE_MAKEFILE=0",
            "-DCMAKE_BUILD_TYPE=Release",
            "-DCMAKE_OSX_SYSROOT=\(platform.sdk.lowercased())",
            "-DCMAKE_OSX_ARCHITECTURES=\(arch.rawValue)",
            "-DCMAKE_SYSTEM_NAME=\(platform.cmakeSystemName)",
            "-DCMAKE_SYSTEM_PROCESSOR=\(arch.rawValue)",
            "-DCMAKE_INSTALL_PREFIX=\(thinDirPath)",
            "-DBUILD_SHARED_LIBS=0",
            "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
        ]
        cmakeArgs.append(contentsOf: arguments)
        
        try Utility.launch(
            path: cmake,
            arguments: cmakeArgs,
            currentDirectoryURL: buildURL,
            environment: environment
        )
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
