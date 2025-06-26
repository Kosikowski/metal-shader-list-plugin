# ShaderListPlugin

Generate Swift enums from your Metal shader functions — automatically!

## What does this plugin do?

ShaderListPlugin is a Swift Package Plugin that scans your target’s `.metal` shader source files, parses all top-level Metal shader functions, and generates type-safe Swift enums for you to access those shaders in your code. No more hardcoding shader function names as strings, or copy–pasting boilerplate! All shader functions are grouped by type (vertex, fragment, kernel, compute) or by custom group comments in your Metal source. Each enum also gets a convenience extension for `MTLLibrary`.

# How to Use

## With Swift Package Manager (SPM):

### Add ShaderListPlugin to your `Package.swift`:

```swift
.package(url: "https://github.com/your-org/ShaderListPlugin.git", from: "1.0.0")
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

### Place your `.metal` files in your target’s sources.

### Build your package. The plugin generates enums and extensions in `Generated/YourTargetShaderEnums.generated.swift` under the plugin work directory. Use them directly in your code:

```swift
let shader = MyTargetMTLShaders.MTLFragmentShader.yourShaderFunctionNameHereAsEnumForTypeSafety
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

## Open Source Contributions

Everyone is welcome to contribute to this project! Whether you find bugs, want to add features, or improve documentation, PRs and issues are encouraged. Please fork, propose changes, or start discussions.

MIT License © 2025 Mateusz Kosikowski, PhD
