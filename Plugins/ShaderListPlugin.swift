import PackagePlugin
import Foundation

@main
struct ShaderEnumsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else {
            return []
        }

        let outputPath = context.package.directory
            .appending("Sources")
            .appending(target.name)
            .appending("ShaderEnums.generated.swift")

        let inputPaths = target.sourceFiles(withSuffix: ".metal").map { $0.path }
        if inputPaths.isEmpty {
            return []
        }

        return [
            .buildCommand(
                displayName: "Generating Shader Enums for \(target.name)",
                executable: try context.tool(named: "shader-enum-generator").path,
                arguments: inputPaths + ["-o", outputPath.string],
                inputFiles: inputPaths,
                outputFiles: [outputPath]
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ShaderEnumsPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let outputPath = context.xcodeProject.directory
            .appending("Sources")
            .appending(target.displayName)
            .appending("ShaderEnums.generated.swift")

        let inputPaths = target.inputFiles.filter { $0.type == .source && $0.path.extension == "metal" }.map { $0.path }
        if inputPaths.isEmpty {
            return []
        }

        return [
            .buildCommand(
                displayName: "Generating Shader Enums for \(target.displayName)",
                executable: try context.tool(named: "shader-enum-generator").path,
                arguments: inputPaths.map { $0.string } + ["-o", outputPath.string],
                inputFiles: inputPaths,
                outputFiles: [outputPath]
            )
        ]
    }
}
#endif

