import PackagePlugin
import Foundation


@main
struct ShaderEnumsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else {
            Diagnostics.error("Target \(target.name) is not a source module")
            return []
        }

        // Use pluginWorkDirectory for temporary generation
        let outputDir = context.pluginWorkDirectory.appending("Generated")
        do {
            try FileManager.default.createDirectory(atPath: outputDir.string, withIntermediateDirectories: true)
            Diagnostics.remark("Created output directory: \(outputDir.string)")
        } catch {
            Diagnostics.error("Failed to create temporary output directory \(outputDir.string): \(error)")
            throw error
        }

        let tempOutputFile = outputDir.appending("ShaderEnums.generated.swift")
        Diagnostics.remark("Temporary output file path: \(tempOutputFile)")

        // Collect .metal files
        let inputPaths = target.sourceFiles(withSuffix: ".metal").map { $0.path }
        Diagnostics.remark("Collected .metal files: \(inputPaths.map { $0.string })")
        if inputPaths.isEmpty {
            Diagnostics.warning("No .metal files found in target \(target.name)")
            return []
        }

        Diagnostics.remark("Generate command arguments: \(inputPaths.map { $0.string } + ["-o", tempOutputFile.string])")
        // Command to generate the file in the temporary directory
        let generateCommand = Command.buildCommand(
            displayName: "Generating Shader Enums for \(target.name)",
            executable: try context.tool(named: "ShaderEnumGenerator").path,
            arguments: inputPaths.map { $0.string } + ["-o", tempOutputFile.string],
            inputFiles: inputPaths,
            outputFiles: [tempOutputFile]
        )
  
        return [generateCommand]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ShaderEnumsPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        
        // Use pluginWorkDirectory for temporary generation
        let outputDir = context.pluginWorkDirectory.appending("Generated")
        do {
            try FileManager.default.createDirectory(atPath: outputDir.string, withIntermediateDirectories: true)
            Diagnostics.remark("Created output directory: \(outputDir.string)")
        } catch {
            Diagnostics.error("Failed to create temporary output directory \(outputDir.string): \(error)")
            throw error
        }

        let tempOutputFile = outputDir.appending("ShaderEnums.generated.swift")
        Diagnostics.remark("Temporary output file path: \(tempOutputFile)")

        // Collect .metal files
        let inputPaths = target.inputFiles
            .filter { $0.type == .source && $0.path.extension == "metal" }
            .map { $0.path }
        Diagnostics.remark("Collected .metal files: \(inputPaths.map { $0.string })")

        if inputPaths.isEmpty {
            Diagnostics.warning("No .metal files found in target \(target.displayName)")
            return []
        }

        Diagnostics.remark("Generate command arguments: \(inputPaths.map { $0.string } + ["-o", tempOutputFile.string])")
        // Command to generate the file in the temporary directory
        let generateCommand = Command.buildCommand(
            displayName: "Generating Shader Enums for \(target.displayName)",
            executable: try context.tool(named: "ShaderEnumGenerator").path,
            arguments: inputPaths.map { $0.string } + ["-o", tempOutputFile.string],
            inputFiles: inputPaths,
            outputFiles: [tempOutputFile]
        )
        return [generateCommand]
    }
}
#endif






