// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ShaderListPlugin",
    products: [
        // Products can be used to vend plugins, making them visible to other packages.
        .plugin(
            name: "ShaderListPlugin",
            targets: ["ShaderListPlugin"]
        ),
    ],
    targets: [
        .plugin(
            name: "ShaderListPlugin",
            capability: .buildTool()
        ),
        .target(
            name: "ShaderEnumGeneratorCore"
        ),
        .executableTarget(
            name: "ShaderEnumGenerator",
            dependencies: ["ShaderEnumGeneratorCore"]
        ),
        .testTarget(
            name: "ShaderEnumGeneratorTests",
            dependencies: ["ShaderEnumGeneratorCore", "ShaderEnumGenerator"]
        ),
    ]
)
