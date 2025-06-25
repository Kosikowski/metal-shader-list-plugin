import PackagePlugin
import Foundation


@main
struct ShaderEnumsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else {
            Diagnostics.error("Target \(target.name) is not a source module")
            return []
        }
//        Diagnostics.error("Mateusz Kosikowski")
        // Define the final output path in Sources/<target.name>/
        let finalOutputPath = context.package.directory
            .appending("Sources")
            .appending(target.name)
            .appending("ShaderEnums.generated.swift")
        Diagnostics.remark("Final output path: \(finalOutputPath)")

        // Use pluginWorkDirectory for temporary generation
        let tempOutputDir = context.pluginWorkDirectory.appending("Generated")
        do {
            try FileManager.default.createDirectory(atPath: tempOutputDir.string, withIntermediateDirectories: true)
            Diagnostics.remark("Created temporary output directory: \(tempOutputDir.string)")
        } catch {
            Diagnostics.error("Failed to create temporary output directory \(tempOutputDir.string): \(error)")
            throw error
        }

        let tempOutputFile = tempOutputDir.appending("ShaderEnums.generated.swift")
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
        

        Diagnostics.remark("Copy command arguments: [\(tempOutputFile.string), \(finalOutputPath.string)]")
        // Command to copy the generated file to Sources/<target.name>/
        let copyCommand = Command.buildCommand(
            displayName: "Copying ShaderEnums.generated.swift to Sources/\(target.name)",
            executable: Path("/bin/cp"),
            arguments: [tempOutputFile.string, finalOutputPath.string],
            inputFiles: [tempOutputFile],
            outputFiles: [finalOutputPath]
        )
        

        Diagnostics.remark("Copying generated file to: \(finalOutputPath.string)")
        return [generateCommand, copyCommand]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ShaderEnumsPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // Define the final output path in Sources/<target.displayName>/
//        Diagnostics.error("Mateusz Kosikowski")
        
        let finalOutputPath = context.xcodeProject.directory
            .appending("Sources")
            .appending(target.displayName)
            .appending("ShaderEnums.swift")
        Diagnostics.remark("Final output path: \(finalOutputPath)")

        // Early exit if the file already exists (avoid duplicate plugin execution)
        if FileManager.default.fileExists(atPath: finalOutputPath.string) {
            Diagnostics.remark("Generated file already exists at \(finalOutputPath.string), skipping duplicate generation.")
            return []
        }

        // Use pluginWorkDirectory for temporary generation
        let tempOutputDir = context.pluginWorkDirectory.appending("Generated")
        do {
            try FileManager.default.createDirectory(atPath: tempOutputDir.string, withIntermediateDirectories: true)
            Diagnostics.remark("Created temporary output directory: \(tempOutputDir.string)")
        } catch {
            Diagnostics.error("Failed to create temporary output directory \(tempOutputDir.string): \(error)")
            throw error
        }

        let tempOutputFile = tempOutputDir.appending("ShaderEnums.generated.swift")
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
//        Diagnostics.error("Metal files found !!!")

        Diagnostics.remark("Generate command arguments: \(inputPaths.map { $0.string } + ["-o", tempOutputFile.string])")
        // Command to generate the file in the temporary directory
        let generateCommand = Command.buildCommand(
            displayName: "Generating Shader Enums for \(target.displayName)",
            executable: try context.tool(named: "ShaderEnumGenerator").path,
            arguments: inputPaths.map { $0.string } + ["-o", tempOutputFile.string],
            inputFiles: inputPaths,
            outputFiles: [tempOutputFile]
        )
        

        Diagnostics.remark("Copy command arguments: [\(tempOutputFile.string), \(finalOutputPath.string)]")
        // Command to copy the generated file to Sources/<target.displayName>/
        let copyCommand = Command.buildCommand(
            displayName: "Copying ShaderEnums.generated.swift to Sources/\(target.displayName)",
            executable: Path("/bin/cp"),
            arguments: [tempOutputFile.string, finalOutputPath.string],
            inputFiles: [tempOutputFile],
            outputFiles: [finalOutputPath]
        )
        

        Diagnostics.remark("Copying generated file to: \(finalOutputPath.string)")
        return [generateCommand, copyCommand]
    }
}
#endif






