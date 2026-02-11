import Foundation

open class CombineBaseBuild : BaseBuild {

    open func combineFrameworkName() -> String {
        "\(library.rawValue)-combined.a"
    }

    open func combineFrameworks(platform: PlatformType, arch: ArchType) -> [String] {
        let thinLibPath = thinDir(platform: platform, arch: arch) + ["lib"]
        let staticLibraries = try? FileManager.default.contentsOfDirectory(atPath: thinLibPath.path).filter { $0.hasSuffix(".a") } 
        guard let staticLibraries = staticLibraries else {
            return []
        }
        // order by create date descending
        let sortedFrameworks = staticLibraries.sorted {
            let file1Path = thinLibPath + [$0]
            let file2Path = thinLibPath + [$1]
            let attr1 = try? FileManager.default.attributesOfItem(atPath: file1Path.path)
            let attr2 = try? FileManager.default.attributesOfItem(atPath: file2Path.path)
            let date1 = attr1?[FileAttributeKey.creationDate] as? Date ?? Date.distantPast
            let date2 = attr2?[FileAttributeKey.creationDate] as? Date ?? Date.distantPast
            return date1 < date2
        }
        return sortedFrameworks
    }

    open override func frameworks() throws -> [String] {
        ["\(library.rawValue)-combined"]
    }

    open override func build(platform: PlatformType, arch: ArchType) throws {
        try super.build(platform: platform, arch: arch)

        try combineStaticLibraries(platform: platform, arch: arch)
    }

    open func combineStaticLibraries(platform: PlatformType, arch: ArchType) throws {
        let frameworks = self.combineFrameworks(platform: platform, arch: arch)
        if frameworks.isEmpty {
            return
        }

        print("Create combine static libraries...")
        let thinLibPath = thinDir(platform: platform, arch: arch) + ["lib"]
        var combinedLibName = combineFrameworkName()
        if !combinedLibName.hasSuffix(".a") {
            combinedLibName += ".a"
        }
        var paths: [String] = []
        let prefix = thinDir(platform: platform, arch: arch)
        if !FileManager.default.fileExists(atPath: prefix.path) {
            throw NSError(domain: "no build for \(platform.rawValue) \(arch.rawValue)", code: 1)
        }
        for framework in frameworks {
                let libname = framework.hasPrefix("lib") || framework.hasPrefix("Lib") ? framework : "lib" + framework
                let libPath = prefix + ["lib", libname]
                if !FileManager.default.fileExists(atPath: libPath.path) {
                    throw NSError(domain: "no library \(libPath.path) for \(platform.rawValue) \(arch.rawValue)", code: 1)
                }
                paths.append(libPath.path)
        }

        let outputPath = prefix + ["lib", combinedLibName]
        var arguments = ["-static"]
        arguments.append(contentsOf: ["-o", outputPath.path])
        for frameworkPath in paths {
            arguments.append(frameworkPath)
        }
        if FileManager.default.fileExists(atPath: outputPath.path) {
            try? FileManager.default.removeItem(at: outputPath)
        }
        try Utility.launch(path: "/usr/bin/libtool", arguments: arguments)

        // move old static libraries to origin directory
        let backupDirectory = thinLibPath + ["bak"]
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true, attributes: nil)
        for framework in frameworks {
            let libname = framework.hasPrefix("lib") || framework.hasPrefix("Lib") ? framework : "lib" + framework
            let libPath = prefix + ["lib", libname]
            let backupLibPath = backupDirectory + [libname]
            try? FileManager.default.moveItem(at: libPath, to: backupLibPath)
        }

        // create combine pkgconfig
        let pkgconfigPath = thinLibPath + ["pkgconfig", "\(library.rawValue).pc"]
        if !FileManager.default.fileExists(atPath: pkgconfigPath.path) {
            throw NSError(domain: "no pkgconfig \(pkgconfigPath.path) for \(platform.rawValue) \(arch.rawValue)", code: 1)
        }

        var content = try String(contentsOf: pkgconfigPath)
        let combinedLibname = combinedLibName.hasPrefix("lib") ? String(combinedLibName.dropFirst(3).dropLast(2)) : String(combinedLibName.dropLast(2))
        content = content.replacingOccurrences(
            of: "-L\\$\\{libdir\\}((\\s+-l\\S+)+)",
            with: "-L${libdir} -l\(combinedLibname)",
            options: .regularExpression
        )

        // move old pkgconfig to origin directory
        let backupPkgconfigPath = backupDirectory + [pkgconfigPath.lastPathComponent]
        try? FileManager.default.moveItem(at: pkgconfigPath, to: backupPkgconfigPath)

        // replace with combined pkgconfig
        FileManager.default.createFile(atPath: pkgconfigPath.path, contents: content.data(using: .utf8), attributes: nil)
    }

}
