//
//  main.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 24/06/2025.
//

import ArgumentParser
import Foundation
import ShaderEnumGeneratorCore

struct ShaderEnumGenerator: ParsableCommand {
    // MARK: Static Properties

    static let configuration = CommandConfiguration(
        commandName: "ShaderEnumGenerator",
        abstract: "Generates a Swift enum source file from Metal shader function declarations."
    )

    // MARK: Properties

    @Argument(help: "Input Metal shader files.")
    var inputFiles: [String]

    @Option(name: .shortAndLong, help: "Output Swift file path.")
    var output: String

    @Option(name: .shortAndLong, help: "Swift module name.")
    var moduleName: String = "ShaderEnumGenerator"

    // MARK: Functions

    func run() throws {
        var functionsByType: [ShaderGroup: Set<String>] = [:]
        for path in inputFiles {
            let content: String
            do {
                content = try String(contentsOfFile: path, encoding: .utf8)
            } catch {
                fputs("Failed to read input file \(path): \(error.localizedDescription)\n", stderr)
                Foundation.exit(1)
            }
            let functions: [(String, String)]
            do {
                functions = try parseShaderFunctions(from: content)
            } catch {
                fputs("\(path): \(error.localizedDescription)\n", stderr)
                Foundation.exit(1)
            }
            for (type, name) in functions where !name.isEmpty {
                let group = ShaderGroup.from(rawValue: type)
                functionsByType[group, default: []].insert(name)
            }
        }
        let swiftCode = generateShaderEnums(functionsByType: functionsByType, moduleName: moduleName)
        do {
            try swiftCode.write(toFile: output, atomically: true, encoding: .utf8)
        } catch {
            fputs("Failed to write output to \(output): \(error)\n", stderr)
            Foundation.exit(2)
        }
    }
}

ShaderEnumGenerator.main()
