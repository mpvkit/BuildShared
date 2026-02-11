import Foundation

/// Protocol defining a library that can be built
/// Libraries must be RawRepresentable with String raw values and CaseIterable
public protocol BuildLibrary: RawRepresentable, CaseIterable where RawValue == String {
    /// The URL of the library's source repository
    var url: String { get }
    
    /// The version/tag of the library to build
    var version: String { get }
    
    /// The package targets for this library
    var targets: [PackageTarget] { get }
}
