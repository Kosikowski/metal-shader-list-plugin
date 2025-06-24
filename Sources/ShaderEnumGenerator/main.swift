import Foundation
import ArgumentParser
import ShaderEnumGeneratorCore

struct ShaderEnumGenerator: ParsableCommand {
    @Argument(help: "Input Metal shader files.")
    var inputFiles: [String]
    
    @Option(name: .shortAndLong, help: "Output Swift file path.")
    var output: String
    
    static var configuration = CommandConfiguration(
        commandName: "ShaderEnumGenerator",
        abstract: "Generates a Swift enum source file from Metal shader function declarations."
    )
    
    func run() throws {
        var functionsByType: [ShaderGroup: Set<String>] = [:]
        for path in inputFiles {
            guard let content = try? String(contentsOfFile: path) else { continue }
            let functions = parseShaderFunctions(from: content)
            for (type, name) in functions where !name.isEmpty {
                let group = ShaderGroup.from(raw: type)
                functionsByType[group, default: []].insert(name)
            }
        }
        let swiftCode = generateShaderEnums(functionsByType: functionsByType)
        do {
            try swiftCode.write(toFile: output, atomically: true, encoding: .utf8)
        } catch {
            fputs("Failed to write output to \(output): \(error)\n", stderr)
            Foundation.exit(2)
        }
    }
}

ShaderEnumGenerator.main()
