import Foundation

/// Represents Apple platforms supported for building
public enum PlatformType: String, CaseIterable {
    case xros, xrsimulator, maccatalyst, macos, isimulator, tvsimulator, tvos, ios
    
    /// Minimum OS version required for this platform
    public var minVersion: String {
        switch self {
        case .ios, .isimulator:
            return "14.0"
        case .tvos, .tvsimulator:
            return "14.0"
        case .macos:
            return "11.0"
        case .maccatalyst:
            return ""
        case .xros, .xrsimulator:
            return "1.0"
        }
    }
    
    /// Short name for the platform
    public var name: String {
        switch self {
        case .ios, .tvos, .macos:
            return rawValue
        case .tvsimulator:
            return "tvossim"
        case .isimulator:
            return "iossim"
        case .maccatalyst:
            return "maccat"
        case .xros:
            return "visionos"
        case .xrsimulator:
            return "visionossim"
        }
    }
    
    /// Framework name used in XCFramework bundles
    public var frameworkName: String {
        switch self {
        case .ios:
            return "ios-arm64"
        case .maccatalyst:
            return "ios-arm64_x86_64-maccatalyst"
        case .isimulator:
            return "ios-arm64_x86_64-simulator"
        case .macos:
            return "macos-arm64_x86_64"
        case .tvos:
            // Keep consistent with Xcode: https://github.com/KhronosGroup/MoltenVK/issues/431#issuecomment-771137085
            return "tvos-arm64_arm64e"
        case .tvsimulator:
            return "tvos-arm64_x86_64-simulator"
        case .xros:
            return "xros-arm64"
        case .xrsimulator:
            return "xros-arm64_x86_64-simulator"
        }
    }
    
    /// Architectures supported for this platform
    /// Note: xcodebuild default ARCHS only builds arm64e for tvos
    public var architectures: [ArchType] {
        switch self {
        case .ios, .xros:
            return [.arm64]
        case .tvos:
            return [.arm64, .arm64e]
        case .xrsimulator:
            return [.arm64]
        case .isimulator, .tvsimulator:
            return [.arm64, .x86_64]
        case .macos:
            // Note: macOS cannot use arm64 first, otherwise release builds will fail
            #if arch(x86_64)
            return [.x86_64, .arm64]
            #else
            return [.arm64, .x86_64]
            #endif
        case .maccatalyst:
            return [.arm64, .x86_64]
        }
    }
    
    /// Deployment target string for LLVM/clang
    public func deploymentTarget(_ arch: ArchType) -> String {
        switch self {
        case .ios, .tvos, .macos, .xros:
            return "\(arch.targetCpu)-apple-\(rawValue)\(minVersion)"
        case .maccatalyst:
            return "\(arch.targetCpu)-apple-ios-macabi"
        case .isimulator:
            return PlatformType.ios.deploymentTarget(arch) + "-simulator"
        case .tvsimulator:
            return PlatformType.tvos.deploymentTarget(arch) + "-simulator"
        case .xrsimulator:
            return PlatformType.xros.deploymentTarget(arch) + "-simulator"
        }
    }
    
    /// OS version minimum flags for compiler
    private var osVersionMin: String {
        switch self {
        case .ios, .tvos:
            return "-m\(rawValue)-version-min=\(minVersion)"
        case .macos:
            return "-mmacosx-version-min=\(minVersion)"
        case .isimulator:
            return "-mios-simulator-version-min=\(minVersion)"
        case .tvsimulator:
            return "-mtvos-simulator-version-min=\(minVersion)"
        case .maccatalyst, .xros, .xrsimulator:
            return ""
        }
    }
    
    /// SDK name for xcrun
    public var sdk: String {
        switch self {
        case .ios:
            return "iPhoneOS"
        case .isimulator:
            return "iPhoneSimulator"
        case .tvos:
            return "AppleTVOS"
        case .tvsimulator:
            return "AppleTVSimulator"
        case .macos:
            return "MacOSX"
        case .maccatalyst:
            return "MacOSX"
        case .xros:
            return "XROS"
        case .xrsimulator:
            return "XRSimulator"
        }
    }
    
    /// SDK root path
    public var isysroot: String {
        xcrunFind(tool: "--show-sdk-path")
    }
    
    /// Meson build system subsystem name
    public var mesonSubSystem: String {
        switch self {
        case .isimulator:
            return "ios-simulator"
        case .tvsimulator:
            return "tvos-simulator"
        case .xrsimulator:
            return "xros-simulator"
        default:
            return rawValue
        }
    }
    
    /// CMake system name
    public var cmakeSystemName: String {
        switch self {
        case .ios, .isimulator:
            return "iOS"
        case .tvos, .tvsimulator:
            return "tvOS"
        case .macos, .maccatalyst:
            return "Darwin"
        case .xros, .xrsimulator:
            return "visionOS"
        }
    }
    
    /// Host triplet for configure scripts
    public func host(arch: ArchType) -> String {
        switch self {
        case .ios, .isimulator, .maccatalyst:
            return "\(arch == .x86_64 ? "x86_64" : "arm64")-ios-darwin"
        case .tvos, .tvsimulator:
            return "\(arch == .x86_64 ? "x86_64" : "arm64")-tvos-darwin"
        case .xros, .xrsimulator:
            return "\(arch == .x86_64 ? "x86_64" : "arm64")-xros-darwin"
        case .macos:
            return "\(arch == .x86_64 ? "x86_64" : "arm64")-apple-darwin"
        }
    }
    
    /// Linker flags for this platform and architecture
    public func ldFlags(arch: ArchType) -> [String] {
        // ldFlags key parameters must match cFlags, otherwise linking will fail
        var flags = ["-lc++", "-arch", arch.rawValue, "-isysroot", isysroot, "-target", deploymentTarget(arch), osVersionMin]
        // Mac Catalyst needs UIKit framework
        if self == .maccatalyst {
            flags += ["-iframework", "\(isysroot)/System/iOSSupport/System/Library/Frameworks"]
        }
        return flags
    }
    
    /// Compiler flags for this platform and architecture
    public func cFlags(arch: ArchType) -> [String] {
        var cflags = ["-arch", arch.rawValue, "-isysroot", isysroot, "-target", deploymentTarget(arch), osVersionMin]
        if self == .tvos || self == .tvsimulator {
            cflags.append("-DHAVE_FORK=0")
        }
        return cflags
    }
    
    /// Find tool path using xcrun
    public func xcrunFind(tool: String) -> String {
        try! Utility.launch(path: "/usr/bin/xcrun", arguments: ["--sdk", sdk.lowercased(), "--find", tool], isOutput: true)
    }
}
