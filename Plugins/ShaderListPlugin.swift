import PackagePlugin
import Foundation


@main
struct ShaderEnumsPlugin: BuildToolPlugin {
    
    private static func makeGenerateCommand(
        outputDir: Path,
        outputFile: Path,
        inputPaths: [Path],
        targetName: String,
        executable: Path,
        contextToolType: String
    ) throws -> Command? {
        do {
            try FileManager.default.createDirectory(atPath: outputDir.string, withIntermediateDirectories: true)
            Diagnostics.remark("[\(contextToolType)] Created output directory: \(outputDir.string)")
        } catch {
            Diagnostics.error("[\(contextToolType)] Failed to create temporary output directory \(outputDir.string): \(error)")
            throw error
        }
        
        Diagnostics.remark("[\(contextToolType)] Output file path: \(outputFile)")
        Diagnostics.remark("[\(contextToolType)] Collected .metal files: \(inputPaths.map { $0.string })")
        
        if inputPaths.isEmpty {
            Diagnostics.warning("[\(contextToolType)] No .metal files found in target \(targetName)")
            return nil
        }
        
        Diagnostics.remark("[\(contextToolType)] Generate command arguments: \(inputPaths.map { $0.string } + ["-o", outputFile.string])")
        
        let command = Command.buildCommand(
            displayName: "Generating Shader Enums for \(targetName)",
            executable: executable,
            arguments: inputPaths.map { $0.string } + ["-o", outputFile.string] + ["-m", targetName],
            inputFiles: inputPaths,
            outputFiles: [outputFile]
        )
        
        return command
    }

    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else {
            Diagnostics.error("Target \(target.name) is not a source module")
            return []
        }
        
        let outputDir = context.pluginWorkDirectory.appending("Generated")
        let outputFile = outputDir.appending("\(target.name)ShaderEnums.generated.swift")
        let inputPaths = target.sourceFiles(withSuffix: ".metal").map { $0.path }
        
        do {
            if let generateCommand = try Self.makeGenerateCommand(
                outputDir: outputDir,
                outputFile: outputFile,
                inputPaths: inputPaths,
                targetName: target.name,
                executable: try context.tool(named: "ShaderEnumGenerator").path,
                contextToolType: "swiftpm"
            ) {
                return [generateCommand]
            }
        } catch {
            throw error
        }
        
        return []
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ShaderEnumsPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let outputDir = context.pluginWorkDirectory.appending("Generated")
        let outputFile = outputDir.appending("\(target.displayName)ShaderEnums.generated.swift")
        let inputPaths = target.inputFiles
            .filter { $0.type == .source && $0.path.extension == "metal" }
            .map { $0.path }
        
        if let generateCommand = try ShaderEnumsPlugin.makeGenerateCommand(
                outputDir: outputDir,
                outputFile: outputFile,
                inputPaths: inputPaths,
                targetName: target.displayName,
                executable: try context.tool(named: "ShaderEnumGenerator").path,
                contextToolType: "xcode"
        ) {
            return [generateCommand]
        }
        
        return []
    }
}
#endif
