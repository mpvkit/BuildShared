# AGENTS.md

This file provides guidelines for AI coding agents working on the BuildShared repository.

## Project Overview

BuildShared is a Swift Package that provides shared build infrastructure for compiling C/C++ libraries into XCFrameworks for multiple Apple platforms (iOS, macOS, tvOS, visionOS).

## Build Commands

Since this is a library package consumed by other projects, there are no direct build/test commands in this repo. Testing is done by:

```bash
# Build the package (validation only)
swift build

# Generate Xcode project for inspection
swift package generate-xcodeproj
```

## File Structure

```
Sources/BuildShared/
├── BuildShared.swift              # Module entry with global exports
├── Protocols/
│   └── BuildLibrary.swift         # BuildLibrary protocol definition
├── Models/
│   ├── PlatformType.swift         # Platform enums (iOS, macOS, etc.)
│   ├── ArchType.swift             # Architecture enums (arm64, x86_64, arm64e)
│   └── PackageTarget.swift        # Binary target definition
├── Options/
│   ├── ArgumentOptions.swift      # Public options class (API compatible)
│   └── BuildOptions.swift         # Internal options struct
├── Builders/
│   ├── BaseBuild.swift            # Main build orchestration (~730 lines)
│   ├── CombineBaseBuild.swift     # Combines multiple static libraries
│   └── ZipBaseBuild.swift         # Works with pre-built zip archives
├── Errors/
│   └── BuildError.swift           # Swift error types with NSError compatibility
└── Utilities/
    ├── Utility.swift              # Shell execution and process management
    └── URL+Extensions.swift       # URL path manipulation helpers
```

## Code Style Guidelines

### Swift Language
- **Version**: Swift 5.8+
- **Platforms**: macOS 11.0+, iOS 14.0+, tvOS 14.0+

### Formatting
- Use 4 spaces for indentation
- Opening braces on the same line: `func foo() {`
- Max line length: ~120 characters
- No trailing whitespace

### Imports
- Always use `import Foundation` at the top
- No unused imports
- Group imports: Foundation first, then others

### Naming Conventions
- **Types**: PascalCase (`BaseBuild`, `PlatformType`, `ArgumentOptions`)
- **Functions/Methods**: camelCase (`buildALL()`, `beforeBuild()`)
- **Variables/Properties**: camelCase (`directoryURL`, `enableDebug`)
- **Constants**: camelCase for instance, PascalCase for enum cases
- **Enum cases**: camelCase (e.g., `case arm64, x86_64, arm64e`)
- **Protocols**: PascalCase with descriptive names (`BuildLibrary`)

### Types
- Use explicit types for public APIs
- Prefer `any` for existential types (e.g., `any BuildLibrary`)
- Use `RawRepresentable` enums for string-backed types
- Use `CaseIterable` for enums that need iteration

### Classes and Structs
- Use `open` for classes intended to be subclassed (`BaseBuild`, `CombineBaseBuild`)
- Use `public` for general APIs
- Mark override methods with `override` keyword
- Include explicit access modifiers on all declarations

### Error Handling
- New code uses `BuildError` enum with proper error descriptions
- Legacy compatibility: `BuildError.nsError` provides NSError conversion
- Original code uses `try!` in many places for simplicity
- Use `throws` for methods that can fail and need to propagate errors

### Comments
- Use `//` for single-line comments
- Include Chinese comments where they add clarity (follow existing patterns)
- Comment complex build logic and platform-specific workarounds

### Architecture Patterns

**Build Classes Hierarchy:**
```
BaseBuild (open class, ~730 lines)
├── CombineBaseBuild (open class)    - Merges static libraries into one
└── ZipBaseBuild (open class)        - Downloads pre-built libraries
```

**Key Protocols:**
- `BuildLibrary`: Defines library metadata (url, version, targets)

**Key Enums:**
- `PlatformType`: iOS, macOS, tvOS, visionOS variants (with simulators)
- `ArchType`: arm64, x86_64, arm64e

### Environment Setup
```swift
let options = try BuildRunner.performCommand()
let builder = MyBuild(library: library, options: options)
try builder.buildALL()
```

### Shell Command Execution
- Use `Utility.launch()` for command execution
- Use `Utility.shell()` for simple command execution
- Always pass environment variables explicitly
- Use `currentDirectoryURL` for working directory context
- Check for tool availability with `Utility.shell("which <tool>")`

### Platform-Specific Code
- Platform logic lives in `PlatformType` enum methods
- Architecture logic lives in `ArchType` enum
- Use conditional compilation sparingly (`#if arch(x86_64)`)
- Document workarounds with comments explaining the issue

### String Handling
- Use triple quotes `"""` for multi-line strings
- Use string interpolation: `\(variable)`
- Use raw values for enum string representations

### Git Workflow
- This is a library used by other projects
- Changes should be backward compatible
- No tests in this repo - tested by consuming projects

### Common Tasks

**Adding a new platform:**
1. Add case to `PlatformType` enum in Models/PlatformType.swift
2. Implement `minVersion`, `name`, `frameworkName`, `architectures`
3. Add `mesonSubSystem`, `cmakeSystemName`, `host()` implementations
4. Update `sdk` property
5. Add platform-specific flags in `cFlags()`/`ldFlags()` if needed

**Modifying build behavior:**
- Extend `BaseBuild` class for new build systems
- Override methods in subclasses to customize behavior
- Key override points:
  - `beforeBuild()`: Setup (clone, patches)
  - `build(platform:arch:)`: Actual compilation
  - `configure(buildURL:environ:platform:arch:)`: Build system configuration
  - `arguments(platform:arch:)`: Additional build arguments
  - `flagsDependencelibrarys()`: Dependency libraries

**Adding error types:**
- Add case to `BuildError` enum in Errors/BuildError.swift
- Implement `errorDescription` for user-friendly messages
- Add corresponding code in `nsError` property for NSError compatibility

### External Dependencies
- Requires Homebrew tools: autoconf, automake, libtool, pkg-config, wget, cmake, meson, ninja
- Uses system tools: git, xcodebuild, lipo, zip, clang

### Notes
- This package is designed for macOS build hosts only
- Requires Xcode with SDKs for target platforms
- Build output goes to `./dist/` directory in consuming projects
- Original single-file design (base.swift) has been refactored into modular structure
- All public APIs remain compatible with previous versions

### Refactoring History
- **2025-02-10**: Migrated from single 1485-line base.swift to modular structure
  - Split into 14 separate files organized by concern
  - Maintained 100% API backward compatibility
  - Added BuildError enum for better error handling (internally)
  - Added BuildOptions struct for type-safe options (internally)
  - No breaking changes to public interface
