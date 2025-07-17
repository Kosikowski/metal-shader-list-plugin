//
//  ShaderListPlugin.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 24/06/2025.
//

import Foundation
import PackagePlugin

// MARK: - PluginError

enum PluginError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidShaderSyntax(String)
    case fileReadError(String, Error)
    case invalidShaderGroupName(String, String) // group name, reason

    // MARK: Computed Properties

    var errorDescription: String? {
        switch self {
            case let .fileNotFound(path):
                return "Metal shader file not found: \(path)"
            case let .invalidShaderSyntax(path):
                return "Invalid syntax detected in shader file: \(path)"
            case let .fileReadError(path, error):
                return "Failed to read shader file \(path): \(error)"
            case let .invalidShaderGroupName(name, reason):
                return "Invalid shader group name '\(name)': \(reason)"
        }
    }
}

// MARK: - Shader Group Validation

extension ShaderEnumsPlugin {
    /// Validates that a shader group name only contains A-Z and a-z characters
    /// - Parameter groupName: The shader group name to validate
    /// - Throws: PluginError.invalidShaderGroupName if invalid
    private static func validateShaderGroupName(_ groupName: String) throws {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for empty names
        guard !trimmedName.isEmpty else {
            throw PluginError.invalidShaderGroupName(groupName, "Group name cannot be empty")
        }

        // Check that name only contains A-Z and a-z characters
        let validCharacters = CharacterSet.letters
        let invalidCharacters = trimmedName.unicodeScalars.filter { !validCharacters.contains($0) }

        if !invalidCharacters.isEmpty {
            let invalidChar = String(invalidCharacters.first!)
            throw PluginError.invalidShaderGroupName(groupName, "Contains invalid character '\(invalidChar)'. Only A-Z and a-z characters are allowed")
        }
    }

    /// Extracts and validates shader group names from a Metal shader file
    /// - Parameter filePath: Path to the Metal shader file
    /// - Throws: PluginError if validation fails
    private static func validateShaderGroupNames(in filePath: Path) throws {
        let content = try String(contentsOfFile: filePath.string)
        let lines = content.components(separatedBy: .newlines)

        for (lineNumber, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Look for MTLShaderGroup comments
            if trimmedLine.hasPrefix("//MTLShaderGroup:") {
                let groupName = trimmedLine.replacingOccurrences(of: "//MTLShaderGroup:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

                do {
                    try validateShaderGroupName(groupName)
                } catch {
                    Diagnostics.error("[Plugin] Invalid shader group name in \(filePath.lastComponent) at line \(lineNumber + 1): \(error.localizedDescription)")
                    throw error
                }
            }
        }
    }
}

// MARK: - ShaderEnumsPlugin

@main
struct ShaderEnumsPlugin: BuildToolPlugin {
    // MARK: Static Functions

    private static func makeGenerateCommand(
        outputDir: Path,
        outputFile: Path,
        inputPaths: [Path],
        targetName: String,
        executable: Path,
        contextToolType: String
    ) throws
        -> Command?
    {
        // Validate shader group names in all input files
        for inputPath in inputPaths {
            do {
                try validateShaderGroupNames(in: inputPath)
            } catch {
                Diagnostics.error("[\(contextToolType)] Shader group validation failed for \(inputPath.lastComponent): \(error.localizedDescription)")
                throw error
            }
        }

        do {
            try FileManager.default.createDirectory(atPath: outputDir.string, withIntermediateDirectories: true)
            Diagnostics.remark("[\(contextToolType)] Created output directory: \(outputDir.string)")
        } catch {
            Diagnostics.error("[\(contextToolType)] Failed to create temporary output directory \(outputDir.string): \(error)")
            throw error
        }

        Diagnostics.remark("[\(contextToolType)] Output file path: \(outputFile)")
        Diagnostics.remark("[\(contextToolType)] Collected .metal files: \(inputPaths.map(\.string))")

        if inputPaths.isEmpty {
            Diagnostics.warning("[\(contextToolType)] No .metal files found in target \(targetName)")
            return nil
        }

        Diagnostics.remark("[\(contextToolType)] Generate command arguments: \(inputPaths.map(\.string) + ["-o", outputFile.string])")

        let command = Command.buildCommand(
            displayName: "Generating Shader Enums for \(targetName)",
            executable: executable,
            arguments: inputPaths.map(\.string) + ["-o", outputFile.string, "-m", targetName],
            inputFiles: inputPaths,
            outputFiles: [outputFile]
        )

        return command
    }

    // MARK: Functions

    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else {
            Diagnostics.error("Target \(target.name) is not a source module")
            return []
        }

        let outputDir = context.pluginWorkDirectory.appending("Generated")
        let outputFile = outputDir.appending("\(target.name)ShaderEnums.generated.swift")
        let inputPaths = target.sourceFiles(withSuffix: ".metal").map(\.path)

        do {
            if
                let generateCommand = try Self.makeGenerateCommand(
                    outputDir: outputDir,
                    outputFile: outputFile,
                    inputPaths: inputPaths,
                    targetName: target.name,
                    executable: context.tool(named: "ShaderEnumGenerator").path,
                    contextToolType: "swiftpm"
                )
            {
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
                .map(\.path)

            if
                let generateCommand = try ShaderEnumsPlugin.makeGenerateCommand(
                    outputDir: outputDir,
                    outputFile: outputFile,
                    inputPaths: inputPaths,
                    targetName: target.displayName,
                    executable: context.tool(named: "ShaderEnumGenerator").path,
                    contextToolType: "xcode"
                )
            {
                return [generateCommand]
            }

            return []
        }
    }
#endif
