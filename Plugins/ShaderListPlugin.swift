//
//  ShaderEnumGeneratorCoreTests.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 24/06/2025.
//

import PackagePlugin

@main
struct ShaderListPlugin: BuildToolPlugin {
    /// Entry point for creating build commands for targets in Swift packages.
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // This plugin only runs for package targets that can have source files.
        guard let sourceFiles = target.sourceModule?.sourceFiles else { return [] }

        // Filter all .metal files
        let metalFiles = sourceFiles.map(\.path).filter { $0.extension == "metal" }
        guard !metalFiles.isEmpty else { return [] }

        // Find the code generator tool to run (replace this with the actual one).
        let generatorTool = try context.tool(named: "ShaderEnumGenerator")

        // Define the single output file path
        let outputPath = context.pluginWorkDirectory.appending("ShaderEnums.generated.swift")

        // Create a single build command with all .metal files as input
        let arguments = metalFiles.map { "\($0)" } + ["-o", "\(outputPath)"]

        return [
            .buildCommand(
                displayName: "Generating ShaderEnums.generated.swift from Metal shaders",
                executable: generatorTool.path,
                arguments: arguments,
                inputFiles: metalFiles,
                outputFiles: [outputPath]
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ShaderListPlugin: XcodeBuildToolPlugin {
    // Entry point for creating build commands for targets in Xcode projects.
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // Filter all .metal files
        let metalFiles = target.inputFiles.map(\.path).filter { $0.extension == "metal" }
        guard !metalFiles.isEmpty else { return [] }

        // Find the code generator tool to run (replace this with the actual one).
        let generatorTool = try context.tool(named: "ShaderEnumGenerator")

        // Define the single output file path
        let outputPath = context.pluginWorkDirectory.appending("ShaderEnums.generated.swift")

        // Create a single build command with all .metal files as input
        let arguments = metalFiles.map { "\($0)" } + ["-o", "\(outputPath)"]

        return [
            .buildCommand(
                displayName: "Generating ShaderEnums.generated.swift from Metal shaders",
                executable: generatorTool.path,
                arguments: arguments,
                inputFiles: metalFiles,
                outputFiles: [outputPath]
            )
        ]
    }
}
#endif
