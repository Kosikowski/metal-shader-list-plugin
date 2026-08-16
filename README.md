[![CI](https://github.com/Kosikowski/metal-shader-list-plugin/actions/workflows/ci.yml/badge.svg)](https://github.com/Kosikowski/metal-shader-list-plugin/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKosikowski%2Fmetal-shader-list-plugin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Kosikowski/metal-shader-list-plugin)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKosikowski%2Fmetal-shader-list-plugin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Kosikowski/metal-shader-list-plugin)

# ShaderListPlugin

Generate Swift enums from your Metal shader functions — automatically!

## What does this plugin do?

ShaderListPlugin is a Swift Package build tool plugin that scans your target's `.metal` source files, parses all top-level Metal shader functions, and generates type-safe Swift enums for accessing those shaders in your code. No more hardcoding shader function names as strings, or copy–pasting boilerplate!

Shader functions are grouped by their qualifier (`vertex`, `fragment`, `kernel`/`compute`) or by custom group comments in your Metal source. Each generated enum also gets a convenience `MTLLibrary` extension. Commented-out shader code is ignored entirely — both `//` line comments and `/* */` block comments.

## How to Use

### With Swift Package Manager

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/Kosikowski/metal-shader-list-plugin.git", from: "1.0.0")
```

Then attach the plugin to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [ /* ... */ ],
    plugins: [
        .plugin(name: "ShaderListPlugin", package: "metal-shader-list-plugin")
    ]
)
```

Place your `.metal` files in the target's sources and build. The plugin generates `Generated/YourTargetShaderEnums.generated.swift` in the plugin work directory and compiles it into your target automatically.

### With Xcode

The plugin also works in Xcode projects via the Xcode build tool plugin interface. After adding the package, attach the plugin to your target's *Build Phases → Run Build Tool Plug-ins*; it runs automatically on every build.

## Using the generated code

For a target named `YourTarget` containing:

```metal
vertex float4 basic_vertex(...) { ... }
fragment float4 basic_fragment(...) { ... }
```

the plugin generates:

```swift
public enum YourTargetMTLShaders {
    public enum MTLVertexShader: String, CaseIterable {
        case basic_vertex = "basic_vertex"
    }
    public enum MTLFragmentShader: String, CaseIterable {
        case basic_fragment = "basic_fragment"
    }
}

extension MTLLibrary {
    public func makeFunction(_ shader: YourTargetMTLShaders.MTLVertexShader) -> MTLFunction? { ... }
    public func makeFunction(_ shader: YourTargetMTLShaders.MTLFragmentShader) -> MTLFunction? { ... }
}
```

so shader lookup is type-safe at the call site:

```swift
let function = library.makeFunction(.basic_vertex)
```

Notes on the generated code:

- `kernel` and `compute` functions land in a single `MTLComputeShader` enum.
- Target names that are not valid Swift identifiers (hyphens, spaces, leading digits) are sanitized, e.g. `my-target` → `my_targetMTLShaders`.
- Shader function names that collide with Swift keywords (e.g. `defer`) are backtick-escaped as case names; their raw values keep the original spelling.

## Custom groups

Assign custom groups by preceding shader functions with a marker comment — with or without a space after `//`:

```metal
// MTLShaderGroup: SpecialEffects
fragment float4 sparkle_fragment() { ... }
```

A group comment applies to **all** shader functions that follow it, until the next group comment:

```metal
//MTLShaderGroup: Lighting
vertex float4 vertex_ambient() { ... }   // → Lighting
vertex float4 vertex_diffuse() { ... }   // → Lighting

//MTLShaderGroup: PostProcessing
fragment float4 blur() { ... }           // → PostProcessing
```

Markers inside commented-out code or string literals are ignored.

### Group name rules

Group names must:

- contain only **A–Z and a–z** characters (no digits, underscores, hyphens, spaces, or non-ASCII letters), and
- not be a **reserved Swift name** (`Self`, `Any`, `Type`, `Protocol`, `class`, `default`, …), since the group becomes a Swift enum name.

Invalid names fail the build with a diagnostic pointing at the offending source line:

```
Shaders.metal: Line 12: Invalid shader group name 'Lighting-3D': Contains invalid character '-'. Only A-Z and a-z characters are allowed
```

**Valid:** `Lighting`, `Rendering`, `PostProcessing`
**Invalid:** `Lighting-3D`, `Post_Processing`, `123Invalid`, `Self`

## Requirements

- Swift 5.9+ toolchain (SPM build tool plugin API)
- The generated code imports `Metal`, so it compiles for Apple platforms; the generator and parser themselves are tested on macOS, Linux, and Windows in CI

## Open Source Contributions

Everyone is welcome to contribute! Whether you find bugs, want to add features, or improve documentation, PRs and issues are encouraged. Please fork, propose changes, or start discussions.

MIT License © 2025 Mateusz Kosikowski, PhD
