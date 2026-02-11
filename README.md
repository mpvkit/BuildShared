# BuildShared

A shared Swift Package for building libraries across multiple Apple platforms (iOS, macOS, tvOS, visionOS).

## Usage

1. Add `BuildShared` as a dependency in your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/mpvkit/BuildShared.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyLibraryBuild",
        dependencies: ["BuildShared"]),
]
```

2. Create a `main.swift` (or your build script entry point) and define your library by conforming to `BuildLibrary`.

```swift
import BuildShared

// 1. Define your library
enum MyLibrary: String, BuildLibrary {
    case myLib

    var version: String {
        switch self {
        case .myLib:
            return "v1.2.3"
        }
    }

    var url: String {
        switch self {
        case .myLib:
            return "https://github.com/example/mylib.git"
        }
    }

    var targets: [PackageTarget] {
        return []
    }
}

// 2. Define your build class inheriting from BaseBuild (Non-generic)
class MyBuild: BaseBuild {

    override func flagsDependencelibrarys() -> [any BuildLibrary] {
        // Return dependencies if any
        return []
    }

    // Override other methods to customize build process (configure, arguments, etc.)
}

// 3. Execute the build
do {
    let options = try BuildRunner.performCommand()

    let build = MyBuild(library: MyLibrary.myLib, options: options)
    try build.buildALL()
} catch {
    print("Build failed: \(error)")
    exit(1)
}
```

## Command Line Arguments

- `enable-debug`: Enable debug mode.
- `enable-gpl`: Enable GPL features.
- `enable-split-platform`: Generate split platform xcframeworks.
- `version=<version>`: Set release version.
- `platform=<platform>`: Specify target platforms (comma separated).
  - Values: `ios`, `macos`, `tvos`, `xros` (visionOS).

Example:

```bash
swift run MyLibraryBuild platform=ios,macos version=1.2.3
```
