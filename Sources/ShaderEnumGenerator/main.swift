//
//  ShaderEnumGeneratorCoreTests.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 24/06/2025.
//
import Foundation
import ShaderEnumGeneratorCore

struct GeneratorOptions {
    var inputFiles: [String] = []
    var outputFile: String?

    init(args: [String]) {
        var idx = 1 // Skip executable name
        while idx < args.count {
            if args[idx] == "-o", idx + 1 < args.count {
                outputFile = args[idx+1]
                idx += 2
            } else {
                inputFiles.append(args[idx])
                idx += 1
            }
        }
    }
}

let options = GeneratorOptions(args: CommandLine.arguments)

guard !options.inputFiles.isEmpty, let outputPath = options.outputFile else {
    fputs("Usage: ShaderEnumGenerator <input.metal>... -o <output.swift>\n", stderr)
    exit(1)
}

var functionsByType: [ShaderGroup: Set<String>] = [:]
for path in options.inputFiles {
    guard let content = try? String(contentsOfFile: path) else { continue }
    let functions = parseShaderFunctions(from: content)
    for (type, name) in functions where !name.isEmpty {
        let group = ShaderGroup.from(raw: type)
        functionsByType[group, default: []].insert(name)
    }
}

let swiftCode = generateShaderEnums(functionsByType: functionsByType)

do {
    try swiftCode.write(toFile: outputPath, atomically: true, encoding: .utf8)
} catch {
    fputs("Failed to write output to \(outputPath): \(error)\n", stderr)
    exit(2)
}
