import Foundation

/// Utility functions for shell command execution and file operations
public enum Utility {
    /// Execute a shell command
    /// - Parameters:
    ///   - command: The command to execute
    ///   - isOutput: Whether to capture and return output
    ///   - currentDirectoryURL: Working directory for the command
    ///   - environment: Environment variables
    /// - Returns: Command output if isOutput is true, nil on failure
    @discardableResult
    public static func shell(_ command: String, isOutput: Bool = false, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) -> String? {
        do {
            return try launch(executableURL: URL(fileURLWithPath: "/bin/bash"), arguments: ["-c", command], isOutput: isOutput, currentDirectoryURL: currentDirectoryURL, environment: environment)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    /// Launch an executable by path
    /// - Parameters:
    ///   - path: Path to executable (will search PATH if not absolute)
    ///   - arguments: Command arguments
    ///   - isOutput: Whether to capture output
    ///   - currentDirectoryURL: Working directory
    ///   - environment: Environment variables
    /// - Returns: Command output
    @discardableResult
    public static func launch(path: String, arguments: [String], isOutput: Bool = false, isPrint: Bool = true, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) throws -> String {
        if !path.hasPrefix("/") {
            let execPath = Utility.shell("which \(path)", isOutput: true)!
            if execPath.isEmpty {
                throw NSError(domain: "[\(path)] not found", code: 1)
            }
            return try launch(executableURL: URL(fileURLWithPath: execPath), arguments: arguments, isOutput: isOutput, isPrint: isPrint, currentDirectoryURL: currentDirectoryURL, environment: environment)
        } else {
            return try launch(executableURL: URL(fileURLWithPath: path), arguments: arguments, isOutput: isOutput, isPrint: isPrint, currentDirectoryURL: currentDirectoryURL, environment: environment)
        }
    }
    
    /// Launch an executable by URL
    /// - Parameters:
    ///   - executableURL: URL to executable
    ///   - arguments: Command arguments
    ///   - isOutput: Whether to capture output
    ///   - currentDirectoryURL: Working directory
    ///   - environment: Environment variables
    /// - Returns: Command output
    @discardableResult
    public static func launch(executableURL: URL, arguments: [String], isOutput: Bool = false, isPrint: Bool = true, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) throws -> String {
        let task = Process()
        var environment = environment
        // for homebrew 1.12
        if ProcessInfo.processInfo.environment.keys.contains("HOME") {
            environment["HOME"] = ProcessInfo.processInfo.environment["HOME"]
        }
        if !environment.keys.contains("PATH") {
            environment["PATH"] = BaseBuild.defaultPath
        }
        task.environment = environment

        var outputFileHandle: FileHandle?
        var logURL: URL?
        var outputBuffer = Data()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        if let curURL = currentDirectoryURL {
            // output to file
            logURL = curURL.appendingPathExtension("log")
            if !FileManager.default.fileExists(atPath: logURL!.path) {
                FileManager.default.createFile(atPath: logURL!.path, contents: nil)
            }

            outputFileHandle = try FileHandle(forWritingTo: logURL!)
            outputFileHandle?.seekToEndOfFile()
        }
        outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData

            if !data.isEmpty {
                outputBuffer.append(data)
                if let outputString = String(data: data, encoding: .utf8) {
                    if isPrint {
                        print(outputString.trimmingCharacters(in: .newlines))
                    }

                    // Write to file simultaneously.
                    outputFileHandle?.write(data)
                }
            } else {
                // Close the read capability processing program and clean up resources.
                fileHandle.readabilityHandler = nil
                fileHandle.closeFile()
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData

            if !data.isEmpty {
                if let outputString = String(data: data, encoding: .utf8) {
                    print(outputString.trimmingCharacters(in: .newlines))

                    // Write to file simultaneously.
                    outputFileHandle?.write(data)
                }
            } else {
                // Close the read capability processing program and clean up resources.
                fileHandle.readabilityHandler = nil
                fileHandle.closeFile()
            }
        }
    
        task.arguments = arguments
        var log = executableURL.path + " " + arguments.joined(separator: " ") + " environment: " + environment.description
        if let currentDirectoryURL {
            log += " url: \(currentDirectoryURL)"
        }
        print(log)
        outputFileHandle?.write("\(log)\n".data(using: .utf8)!)
        task.currentDirectoryURL = currentDirectoryURL
        task.executableURL = executableURL
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            if isOutput {
                let result = String(data: outputBuffer, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
                return result
            } else {
                return ""
            }
        } else {
            if let logURL = logURL {
                // print log when run in GitHub Action
                if ProcessInfo.processInfo.environment.keys.contains("GITHUB_ACTION") {
                    // if build FFmpeg failed, print the ffbuild/config.log content
                    if logURL.path.contains("FFmpeg") {
                        let ffbuildLogURL = logURL
                            .deletingPathExtension()
                            .appendingPathComponent("ffbuild/config.log")
                        if FileManager.default.fileExists(atPath: ffbuildLogURL.path) {
                            if let content = String(data: try Data(contentsOf: ffbuildLogURL), encoding: .utf8) {
                                print("############# \(ffbuildLogURL) CONTENT BEGIN #############")
                                print(content)
                                print("#############  \(ffbuildLogURL) CONTENT END #############")
                            }
                        }
                    }

                    if let content = String(data: try Data(contentsOf: logURL), encoding: .utf8) {
                        print("############# \(logURL) CONTENT BEGIN #############")
                        print(content)
                        print("#############  \(logURL) CONTENT END #############")
                        if #available(macOS 13.0, *) {
                            let regErrLogPath = try Regex("A full log can be found at\\s+?(/.*\\.txt)")
                            if let firstMatch = content.firstMatch(of: regErrLogPath) {
                                let errPath = "\(firstMatch[1].value ?? "")"
                                if !errPath.isEmpty {
                                    print("############# \(errPath) CONTENT BEGIN #############")
                                    let content = Utility.shell("cat \(errPath)", isOutput: true)
                                    print(content ?? "")
                                    print("#############  \(errPath) CONTENT END #############")
                                }
                            }
                        }
                    }
                    
                }
                print("please view log file for detail: \(logURL)\n")
            }
            throw NSError(domain: "\(executableURL.lastPathComponent) execute failed", code: Int(task.terminationStatus))
        }
    }

    /// Recursively list all files in a directory
    @discardableResult
    public static func listAllFiles(in directory: URL) -> [URL] {
        var allFiles: [URL] = []
        let enumerator = FileManager.default.enumerator(atPath: directory.path)

        while let file = enumerator?.nextObject() as? String {
            let filePath = directory + [file]
            var isDirectory: ObjCBool = false

            if FileManager.default.fileExists(atPath: filePath.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // 如果是目录，则递归遍历该目录
                    _ = listAllFiles(in: filePath)
                } else {
                    allFiles.append(filePath)
                }
            }
        }

        return allFiles
    }

    /// Remove files with specified extensions from a directory
    public static func removeFiles(extensions: [String], currentDirectoryURL: URL) throws {
        for ext in extensions {
            let directoryContents = try FileManager.default.contentsOfDirectory(atPath: currentDirectoryURL.path)
            for item in directoryContents {
                if item.hasSuffix(ext) {
                    try FileManager.default.removeItem(at: currentDirectoryURL.appendingPathComponent(item))
                }
            }
        }
    }
}
