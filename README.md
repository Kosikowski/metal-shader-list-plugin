[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKosikowski%2Fmetal-shader-list-plugin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Kosikowski/metal-shader-list-plugin)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKosikowski%2Fmetal-shader-list-plugin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Kosikowski/metal-shader-list-plugin)

# ShaderListPlugin

Generate Swift enums from your Metal shader functions — automatically!

## What does this plugin do?

ShaderListPlugin is a Swift Package Plugin that scans your target's `.metal` shader source files, parses all top-level Metal shader functions, and generates type-safe Swift enums for you to access those shaders in your code. No more hardcoding shader function names as strings, or copy–pasting boilerplate! All shader functions are grouped by type (vertex, fragment, kernel, compute) or by custom group comments in your Metal source. Each enum also gets a convenience extension for `MTLLibrary`.

# How to Use

## With Swift Package Manager (SPM):

### Add ShaderListPlugin to your `Package.swift`:

```swift
.package(url: "https://github.com/Kosikowski/metal-shader-list-plugin.git", from: "1.0.0")
```

### Add the plugin to your project and target:

```swift
.target(
    name: "YourTarget",
    dependencies: [ /* ... */ ],
    plugins: [
        .plugin(name: "ShaderListPlugin")
    ]
)
```

Place your `.metal` files in your target's sources.

Build your package. The plugin generates enums and extensions in `Generated/YourTargetShaderEnums.generated.swift` under the plugin work directory. Use them directly in your code:

```swift
let shader = YourTargetMTLShaders.MTLFragmentShader.yourShaderFunctionNameHereAsEnumForTypeSafety
let function = library.makeFunction(shader)
```
or simply:
```swift
let function = library.makeFunction(.yourShaderFunctionNameHereAsEnumForTypeSafety)
```

## With Xcode:

 - The plugin also works in Xcode via the Xcode Project Plugin interface. After adding the package and plugin, it runs automatically whenever you build your project.

## Customizing Groups

You can assign custom groups to your shader functions by preceding them with special comments in your Metal source:

```metal
// MTLShaderGroup: SpecialEffects
fragment float4 sparkle_fragment() { ... }
```

### Shader Group Name Validation

Shader group names must contain only **A-Z and a-z characters**. Invalid characters (including hyphens, underscores, numbers, spaces, and special symbols) will cause the build to fail with a clear error message.

**Valid examples:**
```metal
// MTLShaderGroup: Lighting
// MTLShaderGroup: Rendering
// MTLShaderGroup: PostProcessing
```

**Invalid examples (will cause build errors):**
```metal
// MTLShaderGroup: Lighting-3D     // ❌ Contains hyphen
// MTLShaderGroup: Post_Processing  // ❌ Contains underscore
// MTLShaderGroup: 123Invalid       // ❌ Starts with number
```

## Open Source Contributions

Everyone is welcome to contribute to this project! Whether you find bugs, want to add features, or improve documentation, PRs and issues are encouraged. Please fork, propose changes, or start discussions.

MIT License © 2025 Mateusz Kosikowski, PhD
