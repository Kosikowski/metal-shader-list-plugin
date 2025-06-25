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
//        .executable(
//                name: "ShaderEnumGenerator",
//                targets: ["ShaderEnumGenerator"]
//            ),
    ], dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .plugin(
            name: "ShaderListPlugin",
            capability: .buildTool(),
                dependencies: ["ShaderEnumGenerator"]
            ),
        .target(
            name: "ShaderEnumGeneratorCore"
        ),
        .executableTarget(
            name: "ShaderEnumGenerator",
            dependencies: [
                "ShaderEnumGeneratorCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
//            path: "ShaderEnumGenerator"
        ),
        .testTarget(
            name: "ShaderEnumGeneratorTests",
            dependencies: ["ShaderEnumGeneratorCore", "ShaderEnumGenerator"]
        ),
    ]
)
