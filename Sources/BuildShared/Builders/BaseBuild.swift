import Foundation

open class BaseBuild {
    public static var defaultPath: String {
        "/Library/Frameworks/Python.framework/Versions/Current/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    public static var splitPlatformGroups: [String: [PlatformType]] {
        [
            PlatformType.macos.rawValue: [PlatformType.macos, PlatformType.maccatalyst],
            PlatformType.ios.rawValue: [PlatformType.ios, PlatformType.isimulator],
            PlatformType.tvos.rawValue: [PlatformType.tvos, PlatformType.tvsimulator],
            PlatformType.xros.rawValue: [PlatformType.xros, PlatformType.xrsimulator]
        ]
    }
    
    public let library: any BuildLibrary
    public let options: ArgumentOptions
    public let directoryURL: URL
    public let xcframeworkDirectoryURL: URL
    public var pullLatestVersion = false
    
    public init(library: any BuildLibrary, options: ArgumentOptions = ArgumentOptions()) {
        self.library = library
        self.options = options
        directoryURL = URL.currentDirectory + "\(library.rawValue)-\(library.version)"
        xcframeworkDirectoryURL = URL.currentDirectory + ["release", "xcframework"]
    }

    open func beforeBuild() throws {
        if FileManager.default.fileExists(atPath: directoryURL.path) {
            return 
        }

        // pull code from git
        if pullLatestVersion {
            try! Utility.launch(path: "/usr/bin/git", arguments: ["-c", "advice.detachedHead=false", "clone", "--recursive", "--depth", "1", library.url, directoryURL.path])
        } else {
            try! Utility.launch(path: "/usr/bin/git", arguments: ["-c", "advice.detachedHead=false", "clone", "--recursive", "--depth", "1", "--branch", library.version, library.url, directoryURL.path])
        }

        // apply patch
        let patch = URL.currentDirectory + "../Sources/BuildScripts/patch/\(library.rawValue)"
        if FileManager.default.fileExists(atPath: patch.path) {
            _ = try? Utility.launch(path: "/usr/bin/git", arguments: ["checkout", "."], currentDirectoryURL: directoryURL)
            let fileNames = try! FileManager.default.contentsOfDirectory(atPath: patch.path).sorted()
            for fileName in fileNames {
                if !fileName.hasSuffix(".patch") {
                    continue
                }
                try! Utility.launch(path: "/usr/bin/git", arguments: ["apply", "\((patch + fileName).path)"], currentDirectoryURL: directoryURL)
            }
        }
    }

    open func buildALL() throws {
        try beforeBuild()
        try? FileManager.default.removeItem(at: URL.currentDirectory + library.rawValue)
        try? FileManager.default.removeItem(at: directoryURL.appendingPathExtension("log"))
        
        let platforms = self.platforms()
        
        for platform in platforms {
            for arch in architectures(platform) {
                try build(platform: platform, arch: arch)
            }
        }
        try createXCFramework()
        try packageRelease()
        try afterBuild()
    }

    open func afterBuild() throws {
        try generatePackageManagerFile()
    }

    open func architectures(_ platform: PlatformType) -> [ArchType] {
        platform.architectures
    }

    open func platforms() -> [PlatformType] {
        options.platforms.isEmpty ? PlatformType.allCases : options.platforms
    }

    open func build(platform: PlatformType, arch: ArchType) throws {
        let buildURL = scratch(platform: platform, arch: arch)
        let thinURL = thinDir(platform: platform, arch: arch)
        try? FileManager.default.createDirectory(at: buildURL, withIntermediateDirectories: true, attributes: nil)
        let environ = environment(platform: platform, arch: arch)
        
        // Use BuildSystem abstraction
        let buildSystem = BuildSystemDetector.detectOrMake(in: directoryURL)
        let args = arguments(platform: platform, arch: arch)
        
        try buildSystem.configure(
            buildURL: buildURL,
            sourceURL: directoryURL,
            platform: platform,
            arch: arch,
            environment: environ,
            arguments: args,
            prefix: thinURL
        )
        
        try buildSystem.build(
            buildURL: buildURL,
            platform: platform,
            arch: arch,
            environment: environ
        )
        
        try buildSystem.install(
            buildURL: buildURL,
            platform: platform,
            arch: arch,
            environment: environ
        )
    }

    open func wafPath() -> String {
        "./waf"
    }

    open func wafBuildArg() -> [String] {
        ["build"]
    }

    open func wafInstallArg() -> [String] {
        []
    }

    open func configure(buildURL: URL, environ: [String: String], platform: PlatformType, arch: ArchType) throws {
        let autogen = directoryURL + "autogen.sh"
        if FileManager.default.fileExists(atPath: autogen.path) {
            var environ = environ
            environ["NOCONFIGURE"] = "1"
            try Utility.launch(executableURL: autogen, arguments: [], currentDirectoryURL: directoryURL, environment: environ)
        }
        let makeLists = directoryURL + "CMakeLists.txt"
        if FileManager.default.fileExists(atPath: makeLists.path) {
            if Utility.shell("which cmake") == nil {
                Utility.shell("brew install cmake")
            }
            let cmake = Utility.shell("which cmake", isOutput: true)!
            let thinDirPath = thinDir(platform: platform, arch: arch).path
            var arguments = [
                makeLists.path,
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
            arguments.append(contentsOf: self.arguments(platform: platform, arch: arch))
            try Utility.launch(path: cmake, arguments: arguments, currentDirectoryURL: buildURL, environment: environ)
        } else {
            let configure = directoryURL + "configure"
            if !FileManager.default.fileExists(atPath: configure.path) {
                var bootstrap = directoryURL + "bootstrap"
                if !FileManager.default.fileExists(atPath: bootstrap.path) {
                    bootstrap = directoryURL + ".bootstrap"
                }
                if FileManager.default.fileExists(atPath: bootstrap.path) {
                    try Utility.launch(executableURL: bootstrap, arguments: [], currentDirectoryURL: directoryURL, environment: environ)
                }
            }
            var arguments = [
                "--prefix=\(thinDir(platform: platform, arch: arch).path)",
            ]
            arguments.append(contentsOf: self.arguments(platform: platform, arch: arch))
            try Utility.launch(executableURL: configure, arguments: arguments, currentDirectoryURL: buildURL, environment: environ)
        }
    }

    open func environment(platform: PlatformType, arch: ArchType) -> [String: String] {
        let cFlags = cFlags(platform: platform, arch: arch).joined(separator: " ")
        let ldFlags = ldFlags(platform: platform, arch: arch).joined(separator: " ")
        
        // Use local pkgConfigPath method instead of PlatformType one
        let pkgConfigPathStr = pkgConfigPath(platform: platform, arch: arch)
        let pkgConfigPathDefault = Utility.shell("pkg-config --variable pc_path pkg-config", isOutput: true)!
        return [
            "LC_CTYPE": "C",
            "CC": "/usr/bin/clang",
            "CXX": "/usr/bin/clang++",
            // "SDKROOT": platform.sdk.lowercased(),
            "CURRENT_ARCH": arch.rawValue,
            "CFLAGS": cFlags,
            // makefile can't use CPPFLAGS
            "CPPFLAGS": cFlags,
            // 这个要加，不然cmake在编译maccatalyst 会有问题
            "CXXFLAGS": cFlags,
            "ASMFLAGS": cFlags,
            "LDFLAGS": ldFlags,
            "PKG_CONFIG_LIBDIR": pkgConfigPathStr + pkgConfigPathDefault,
            "PATH": BaseBuild.defaultPath,
        ]
    }
    
    // Moved from PlatformType and genericized
    public func pkgConfigPath(platform: PlatformType, arch: ArchType) -> String {
        var pkgConfigPath = ""
        let currentDir = URL.currentDirectory
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: currentDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            for folderUrl in contents {
                 let path = folderUrl + [platform.rawValue, "thin", arch.rawValue]
                 if fileManager.fileExists(atPath: path.path) {
                      pkgConfigPath += "\(path.path)/lib/pkgconfig:"
                 }
            }
        } catch {
            print("Error scanning for pkgconfig: \(error)")
        }
        
        return pkgConfigPath
    }

    open func cFlags(platform: PlatformType, arch: ArchType) -> [String] {
        var cFlags = platform.cFlags(arch: arch)
        let librarys = flagsDependencelibrarys()
        for library in librarys {
            let path = URL.currentDirectory + [library.rawValue, platform.rawValue, "thin", arch.rawValue]
            if FileManager.default.fileExists(atPath: path.path) {
                cFlags.append("-I\(path.path)/include")
            }
        }
        return cFlags
    }

    open func ldFlags(platform: PlatformType, arch: ArchType) -> [String] {
        var ldFlags = platform.ldFlags(arch: arch)
        let librarys = flagsDependencelibrarys()
        for library in librarys {
            let path = URL.currentDirectory + [library.rawValue, platform.rawValue, "thin", arch.rawValue]
            if FileManager.default.fileExists(atPath: path.path) {
                var libname = library.rawValue
                if libname.hasPrefix("lib") {
                    libname = String(libname.dropFirst(3))
                }
                ldFlags.append("-L\(path.path)/lib")
                ldFlags.append("-l\(libname)")
            }
        }
        return ldFlags
    }

    open func flagsDependencelibrarys() -> [any BuildLibrary] {
        []
    }


    open func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        return []
    }

    open func frameworks() throws -> [String] {
        [library.rawValue]
    }

    open func createXCFramework() throws {
        // clean all old xcframework
        try? Utility.removeFiles(extensions: [".xcframework"], currentDirectoryURL: self.xcframeworkDirectoryURL)

        var frameworks: [String] = []
        let libNames = try self.frameworks()
        for libName in libNames {
            if libName.hasPrefix("lib") {
                frameworks.append("Lib" + libName.dropFirst(3))
            } else {
                frameworks.append(libName)
            }
        }
        for framework in frameworks {
            var frameworkGenerated = [PlatformType: String]()
            let platforms = self.platforms()
            for platform in platforms {
                if let frameworkPath = try createFramework(framework: framework, platform: platform) {
                    frameworkGenerated[platform] = frameworkPath
                }
            }
            try buildXCFramework(name: framework, paths: Array(frameworkGenerated.values))

            // Generate xcframework for different platforms
            if self.options.enableSplitPlatform {
                for (group, platforms) in BaseBuild.splitPlatformGroups {
                    var frameworkPaths: [String] = []
                    for platform in platforms {
                        if let frameworkPath = frameworkGenerated[platform] {
                            frameworkPaths.append(frameworkPath)
                        }
                    }
                    try buildXCFramework(name: "\(framework)-\(group)", paths: frameworkPaths)
                }
            }
        }
    }

    private func buildXCFramework(name: String, paths: [String]) throws {
        if paths.isEmpty {
            return
        }

        var arguments = ["-create-xcframework"]
        for frameworkPath in paths {
            arguments.append("-framework")
            arguments.append(frameworkPath)
        }
        arguments.append("-output")
        let XCFrameworkFile = self.xcframeworkDirectoryURL + [name + ".xcframework"]
        arguments.append(XCFrameworkFile.path)
        if FileManager.default.fileExists(atPath: XCFrameworkFile.path) {
            try? FileManager.default.removeItem(at: XCFrameworkFile)
        }
        try Utility.launch(path: "/usr/bin/xcodebuild", arguments: arguments)
    }

    open func createFramework(framework: String, platform: PlatformType) throws -> String? {
        let platformDir = URL.currentDirectory + [library.rawValue, platform.rawValue]
        if !FileManager.default.fileExists(atPath: platformDir.path) {
            return nil
        }
        let frameworkDir = URL.currentDirectory + [library.rawValue, platform.rawValue, "\(framework).framework"]
        if !platforms().contains(platform) {
            if FileManager.default.fileExists(atPath: frameworkDir.path) {
                return frameworkDir.path
            } else {
                return nil
            }
        }
        try? FileManager.default.removeItem(at: frameworkDir)
        try FileManager.default.createDirectory(at: frameworkDir, withIntermediateDirectories: true, attributes: nil)
        var arguments = ["-create"]
        for arch in platform.architectures {
            let prefix = thinDir(platform: platform, arch: arch)
            if !FileManager.default.fileExists(atPath: prefix.path) {
                return nil
            }
            let libname = framework.hasPrefix("lib") || framework.hasPrefix("Lib") ? framework : "lib" + framework
            var libPath = prefix + ["lib", "\(libname).a"]
            if !FileManager.default.fileExists(atPath: libPath.path) {
                libPath = prefix + ["lib", "\(libname).dylib"]
            }
            arguments.append(libPath.path)
            var headerURL: URL = prefix + "include" + framework
            if !FileManager.default.fileExists(atPath: headerURL.path) {
                headerURL = prefix + "include"
            }
            try? FileManager.default.copyItem(at: headerURL, to: frameworkDir + "Headers")
        }
        arguments.append("-output")
        arguments.append((frameworkDir + framework).path)
        try Utility.launch(path: "/usr/bin/lipo", arguments: arguments)
        try FileManager.default.createDirectory(at: frameworkDir + "Modules", withIntermediateDirectories: true, attributes: nil)
        var modulemap = """
        framework module \(framework) [system] {
            umbrella "."
        
        """
        frameworkExcludeHeaders(framework).forEach { header in
            modulemap += """
                exclude header "\(header).h"

            """
        }
        modulemap += """
            export *
        }
        """
        FileManager.default.createFile(atPath: frameworkDir.path + "/Modules/module.modulemap", contents: modulemap.data(using: .utf8), attributes: nil)
        // Setting the minimum version to 100.0 is required for uploading a static framework to the App Store after Xcode 15.4
        // Fix: ITMS-90208: "Invalid Bundle. The bundle xxx.framework does not support the minimum OS Version specified in the Info.plist."
        // It was originally using `platform.minVersion`
        createPlist(path: frameworkDir.path + "/Info.plist", name: framework, minVersion: "100.0", platform: platform.sdk)
        try fixShallowBundles(framework: framework, platform: platform, frameworkDir: frameworkDir)
        return frameworkDir.path
    }

    // Fix shallow bundles for Xcode 26, only for macOS frameworks
    public func fixShallowBundles(framework: String, platform: PlatformType, frameworkDir: URL) throws {
        guard platform == .macos else { return }

        let infoPlistPath = frameworkDir + "Info.plist"
        let versionsPath = frameworkDir + "Versions"
        
        // Check if this is a shallow bundle that needs fixing
        var isDirectory: ObjCBool = false
        let frameworkExists = FileManager.default.fileExists(atPath: frameworkDir.path, isDirectory: &isDirectory)
        let hasInfoPlist = FileManager.default.fileExists(atPath: infoPlistPath.path)
        let hasVersions = FileManager.default.fileExists(atPath: versionsPath.path, isDirectory: &isDirectory) && isDirectory.boolValue
        
        if frameworkExists && hasInfoPlist && !hasVersions {
            print("Fixing \(framework).framework bundle structure...")
            
            // Create proper bundle structure
            let versionAResourcesPath = frameworkDir + ["Versions", "A", "Resources"]
            try FileManager.default.createDirectory(at: versionAResourcesPath, withIntermediateDirectories: true, attributes: nil)
            
            // Move Info.plist to proper location
            let newInfoPlistPath = versionAResourcesPath + "Info.plist"
            try FileManager.default.moveItem(at: infoPlistPath, to: newInfoPlistPath)
            
            // Move framework binary to proper location
            let binaryPath = frameworkDir + framework
            let newBinaryPath = frameworkDir + ["Versions", "A", framework]
            if FileManager.default.fileExists(atPath: binaryPath.path) {
                try FileManager.default.moveItem(at: binaryPath, to: newBinaryPath)
            }
            
            // Move LICENSE if exists
            let licensePath = frameworkDir + "LICENSE"
            if FileManager.default.fileExists(atPath: licensePath.path) {
                let newLicensePath = frameworkDir + ["Versions", "A", "LICENSE"]
                try FileManager.default.moveItem(at: licensePath, to: newLicensePath)
            }
            
            // Create symbolic links
            let currentLinkPath = frameworkDir + ["Versions", "Current"]
            try? FileManager.default.removeItem(at: currentLinkPath)
            try FileManager.default.createSymbolicLink(atPath: currentLinkPath.path, withDestinationPath: "A")
            
            let binaryLinkPath = frameworkDir + framework
            try? FileManager.default.removeItem(at: binaryLinkPath)
            try FileManager.default.createSymbolicLink(atPath: binaryLinkPath.path, withDestinationPath: "Versions/Current/\(framework)")
            
            let resourcesLinkPath = frameworkDir + "Resources"
            try? FileManager.default.removeItem(at: resourcesLinkPath)
            try FileManager.default.createSymbolicLink(atPath: resourcesLinkPath.path, withDestinationPath: "Versions/Current/Resources")
            
            print("\(framework).framework structure fixed")
        }
    }

    open func thinDir(library: any BuildLibrary, platform: PlatformType, arch: ArchType) -> URL {
        URL.currentDirectory + [library.rawValue, platform.rawValue, "thin", arch.rawValue]
    }

    open func thinDir(platform: PlatformType, arch: ArchType) -> URL {
        thinDir(library: library, platform: platform, arch: arch)
    }

    open func scratch(platform: PlatformType, arch: ArchType) -> URL {
        URL.currentDirectory + [library.rawValue, platform.rawValue, "scratch", arch.rawValue]
    }

    open func frameworkExcludeHeaders(_: String) -> [String] {
        []
    }

    private func createPlist(path: String, name: String, minVersion: String, platform: String) {
        let identifier = "com.mpvkit." + normalizeBundleIdentifier(name)
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>\(name)</string>
        <key>CFBundleIdentifier</key>
        <string>\(identifier)</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>\(name)</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>87.88.520</string>
        <key>CFBundleVersion</key>
        <string>87.88.520</string>
        <key>CFBundleSignature</key>
        <string>????</string>
        <key>MinimumOSVersion</key>
        <string>\(minVersion)</string>
        <key>CFBundleSupportedPlatforms</key>
        <array>
        <string>\(platform)</string>
        </array>
        <key>NSPrincipalClass</key>
        <string></string>
        </dict>
        </plist>
        """
        FileManager.default.createFile(atPath: path, contents: content.data(using: .utf8), attributes: nil)
    }

    // CFBundleIdentifier must contain only alphanumerics(a-z), dots(.), hyphens(-) 
    private func normalizeBundleIdentifier(_ identifier: String) -> String {
        return identifier.replacingOccurrences(of: "_", with: "-")
    }


    private func createMesonCrossFile(platform: PlatformType, arch: ArchType) -> URL {
        let url = scratch(platform: platform, arch: arch)
        let crossFile = url + "crossFile.meson"
        let prefix = thinDir(platform: platform, arch: arch)
        let cFlags = cFlags(platform: platform, arch: arch).map {
            "'" + $0 + "'"
        }.joined(separator: ", ")
        let ldFlags = ldFlags(platform: platform, arch: arch).map {
            "'" + $0 + "'"
        }.joined(separator: ", ")
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
        prefix = '\(prefix.path)'
        c_args = [\(cFlags)]
        cpp_args = [\(cFlags)]
        objc_args = [\(cFlags)]
        objcpp_args = [\(cFlags)]
        c_link_args = [\(ldFlags)]
        cpp_link_args = [\(ldFlags)]
        objc_link_args = [\(ldFlags)]
        objcpp_link_args = [\(ldFlags)]
        """
        FileManager.default.createFile(atPath: crossFile.path, contents: content.data(using: .utf8), attributes: nil)
        return crossFile
    }

    open func packageRelease() throws {
        let releaseDirPath = URL.currentDirectory + ["release"]
        if !FileManager.default.fileExists(atPath: releaseDirPath.path) {
            try? FileManager.default.createDirectory(at: releaseDirPath, withIntermediateDirectories: true, attributes: nil)
        }
        let releaseLibPath = releaseDirPath + [library.rawValue]
        try? FileManager.default.removeItem(at: releaseLibPath)

        // copy static libraries
        let platforms = self.platforms()
        for platform in platforms {
            for arch in architectures(platform) {
                 let thinLibPath = thinDir(platform: platform, arch: arch) + ["lib"]
                 if !FileManager.default.fileExists(atPath: thinLibPath.path) {
                     continue
                 }
                 let staticLibraries = try FileManager.default.contentsOfDirectory(atPath: thinLibPath.path).filter { $0.hasSuffix(".a") }

                 let releaseThinLibPath = releaseDirPath + [library.rawValue, "lib", platform.rawValue, "thin", arch.rawValue, "lib"]
                 try? FileManager.default.createDirectory(at: releaseThinLibPath, withIntermediateDirectories: true, attributes: nil)
                 for lib in staticLibraries {
                    let sourceURL = thinLibPath + [lib]
                    let destinationURL = releaseThinLibPath + [lib]
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                }
            }
        }

        // copy includes
        guard let firstPlatform = getFirstSuccessPlatform() else { return }
        let firstArch = architectures(firstPlatform).first!
        let includePath = thinDir(platform: firstPlatform, arch: firstArch) + ["include"]
        let destIncludePath = releaseDirPath + [library.rawValue, "include"]
        try FileManager.default.copyItem(at: includePath, to: destIncludePath)


        // copy pkg-config file example
        try packagePkgConfigRelease()

        // zip build artifacts when there are frameworks to generate
        if try self.frameworks().count > 0 {
            let sourceLib = releaseDirPath + [library.rawValue]
            let destZipLibPath = releaseDirPath + [library.rawValue + "-all.zip"]
            try? FileManager.default.removeItem(at: destZipLibPath)
            try Utility.launch(path: "/usr/bin/zip", arguments: ["-qr", destZipLibPath.path, "./"], currentDirectoryURL: sourceLib)
        }

        // zip xcframeworks
        var frameworks: [String] = []
        let libNames = try self.frameworks()
        for libName in libNames {
            if libName.hasPrefix("lib") {
                frameworks.append("Lib" + libName.dropFirst(3))
            } else {
                frameworks.append(libName)
            }
        }
        for framework in frameworks {
            // clean old zip files
            try? FileManager.default.removeItem(at: releaseDirPath + [framework + ".xcframework.zip"])
            try? FileManager.default.removeItem(at: releaseDirPath + [framework + ".xcframework.checksum.txt"])

            let XCFrameworkFile =  framework + ".xcframework"
            let zipFile = releaseDirPath + [framework + ".xcframework.zip"]
            let checksumFile = releaseDirPath + [framework + ".xcframework.checksum.txt"]
            try Utility.launch(path: "/usr/bin/zip", arguments: ["-qry", zipFile.path, XCFrameworkFile], currentDirectoryURL: self.xcframeworkDirectoryURL)
            Utility.shell("swift package compute-checksum \(zipFile.path) > \(checksumFile.path)")

            if self.options.enableSplitPlatform {
                for group in BaseBuild.splitPlatformGroups.keys {
                    let XCFrameworkName =  "\(framework)-\(group)"
                    
                    // clean old zip files
                    try? FileManager.default.removeItem(at: releaseDirPath + [XCFrameworkName + ".xcframework.zip"])
                    try? FileManager.default.removeItem(at: releaseDirPath + [XCFrameworkName + ".xcframework.checksum.txt"])
                    
                    let XCFrameworkFile =  XCFrameworkName + ".xcframework"
                    let XCFrameworkPath = self.xcframeworkDirectoryURL + ["\(framework)-\(group).xcframework"]
                    if FileManager.default.fileExists(atPath: XCFrameworkPath.path) {
                        let zipFile = releaseDirPath + [XCFrameworkName + ".xcframework.zip"]
                        let checksumFile = releaseDirPath + [XCFrameworkName + ".xcframework.checksum.txt"]
                        try Utility.launch(path: "/usr/bin/zip", arguments: ["-qry", zipFile.path, XCFrameworkFile], currentDirectoryURL: self.xcframeworkDirectoryURL)
                        Utility.shell("swift package compute-checksum \(zipFile.path) > \(checksumFile.path)")
                    }
                }
            }
        }
    }

    private func packagePkgConfigRelease() throws {
        let releaseDirPath = URL.currentDirectory + ["release"]
        // copy pkg-config file example
        let platforms = self.platforms()
        for platform in platforms {
            for arch in architectures(platform) {
                let thinLibPath = thinDir(platform: platform, arch: arch) + ["lib"]
                let pkgconfigPath = thinLibPath + ["pkgconfig"]
                if !FileManager.default.fileExists(atPath: pkgconfigPath.path) {
                    continue
                }
                let destPkgConfigDir = releaseDirPath + [library.rawValue, "pkgconfig-example", platform.rawValue]
                let destPkgConfigPath = destPkgConfigDir + arch.rawValue
                try? FileManager.default.createDirectory(at: destPkgConfigDir, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.copyItem(at: pkgconfigPath, to: destPkgConfigPath)

                let pkgconfigFiles = Utility.listAllFiles(in: destPkgConfigPath)
                for file in pkgconfigFiles {
                    if let data = FileManager.default.contents(atPath: file.path), var str = String(data: data, encoding: .utf8) {
                        str = str.replacingOccurrences(of: URL.currentDirectory.path, with: "/path/to/workdir")
                        try! str.write(toFile: file.path, atomically: true, encoding: .utf8)
                    }
                }
            }
        }
    }

    open func generatePackageManagerFile() throws {
        let releaseDirPath = URL.currentDirectory + ["release"]
        let template = URL.currentDirectory + ["../docs/Package.template.swift"]
        let packageFile = releaseDirPath + "Package.swift"

        if !FileManager.default.fileExists(atPath: packageFile.path) {
            try! FileManager.default.createDirectory(at: releaseDirPath, withIntermediateDirectories: true, attributes: nil)
            try! FileManager.default.copyItem(at: template, to: packageFile)
        }

        var dependencyTargetContent = ""
        if self is ZipBaseBuild {
            for target in library.targets {
                let tmpChecksum = FileManager.default.temporaryDirectory + "\(library.rawValue)_checksum.txt"
                if FileManager.default.fileExists(atPath: tmpChecksum.path) {
                    try? FileManager.default.removeItem(at: tmpChecksum)
                }
                try! Utility.launch(path: "wget", arguments: ["-q", "-O", tmpChecksum.path, target.checksum], currentDirectoryURL: FileManager.default.temporaryDirectory)
                let checksum = try String(contentsOf: tmpChecksum, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                dependencyTargetContent += """
                
                        .binaryTarget(
                            name: "\(target.name)",
                            url: "\(target.url)",
                            checksum: "\(checksum)"
                        ),
                """
                try? FileManager.default.removeItem(at: tmpChecksum)
            }
        } else {
            for target in library.targets {
                let checksumFile = releaseDirPath + [target.name + ".xcframework.checksum.txt"]
                let checksum = try String(contentsOf: checksumFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                dependencyTargetContent += """

                        .binaryTarget(
                            name: "\(target.name)",
                            url: "\(target.url)",
                            checksum: "\(checksum)"
                        ),
                """
            }
        }

        if dependencyTargetContent.isEmpty {
            return
        }

        if let data = FileManager.default.contents(atPath: packageFile.path), var str = String(data: data, encoding: .utf8) {
            let placeholderChars = "//AUTO_GENERATE_TARGETS_END//"
            str = str.replacingOccurrences(of: 
            """
                    \(placeholderChars)
            """, with: 
            """
            \(dependencyTargetContent)
                    \(placeholderChars)
            """)
            try! str.write(toFile: packageFile.path, atomically: true, encoding: .utf8)
        }
    }

    private func getFirstSuccessPlatform() -> PlatformType? {
        let platforms = self.platforms()
        for platform in platforms {
            let firstArch = architectures(platform).first!
            let thinPath = thinDir(platform: platform, arch: firstArch)
            if FileManager.default.fileExists(atPath: thinPath.path) {
                return platform
            }
        }

        return nil
    }
}
