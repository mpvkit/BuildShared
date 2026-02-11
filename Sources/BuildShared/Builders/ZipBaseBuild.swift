import Foundation

open class ZipBaseBuild : BaseBuild {

    open override func beforeBuild() throws {
        // unzip builded static library
        let outputFileName = "\(library.rawValue).zip"
        let outputFile = directoryURL + outputFileName
        // delete invalid downloaded files
        let attributes = try? FileManager.default.attributesOfItem(atPath: outputFile.path)
        if let fileSize = attributes?[FileAttributeKey.size] as? UInt64, fileSize <= 0 {
            try? FileManager.default.removeItem(atPath: directoryURL.path)
        }
        try! FileManager.default.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)

        if !FileManager.default.fileExists(atPath: outputFile.path) {
            try! Utility.launch(path: "wget", arguments: ["-O", outputFileName, library.url], currentDirectoryURL: directoryURL)
            try! Utility.launch(path: "/usr/bin/unzip", arguments: ["-o",outputFileName], currentDirectoryURL: directoryURL)
        }
    }

    open override func buildALL() throws {
        try beforeBuild()
        try? FileManager.default.removeItem(at: URL.currentDirectory + library.rawValue)
        try? FileManager.default.removeItem(at: directoryURL.appendingPathExtension("log"))
        try? FileManager.default.createDirectory(atPath: (URL.currentDirectory + library.rawValue).path, withIntermediateDirectories: true, attributes: nil)
        
        let platforms = self.platforms()
        for platform in platforms {
            for arch in architectures(platform) {
                // restore lib
                let srcThinLibPath = directoryURL + ["lib"] + [platform.rawValue, "thin", arch.rawValue, "lib"]
                // ignore if platform not support
                if !FileManager.default.fileExists(atPath: srcThinLibPath.path) {
                    continue
                }
                let destThinPath = thinDir(platform: platform, arch: arch)
                let destThinLibPath = destThinPath + ["lib"]
                try? FileManager.default.createDirectory(atPath: destThinPath.path, withIntermediateDirectories: true, attributes: nil)
                try? FileManager.default.copyItem(at: srcThinLibPath, to: destThinLibPath)

                // restore include
                let srcIncludePath = directoryURL + ["include"]
                let destIncludePath = destThinPath + ["include"]
                try? FileManager.default.copyItem(at: srcIncludePath, to: destIncludePath)

                // restore pkgconfig
                let srcPkgConfigPath = directoryURL + ["pkgconfig-example", platform.rawValue, arch.rawValue]
                let destPkgConfigPath = destThinPath + ["lib", "pkgconfig"]
                try? FileManager.default.copyItem(at: srcPkgConfigPath, to: destPkgConfigPath)
                Utility.listAllFiles(in: destPkgConfigPath).forEach { file in
                    if let data = FileManager.default.contents(atPath: file.path), var str = String(data: data, encoding: .utf8) {
                        str = str.replacingOccurrences(of: "/path/to/workdir", with: URL.currentDirectory.path)
                        try! str.write(toFile: file.path, atomically: true, encoding: .utf8)
                    }
                }
            }
        }

        try afterBuild()
    }

    open override func afterBuild() throws {
        try super.afterBuild()
    }
}
