//
//  ShaderEnumGeneratorCoreTests.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 24/06/2025.
//

// Shared core logic for parsing Metal shaders and generating Swift enums
import Foundation

public enum ShaderGroup: Hashable, Equatable, CustomStringConvertible {
    case vertex, fragment, kernel, compute, unknown
    case custom(String)

    public var description: String {
        switch self {
        case .vertex: return "MTLVertexShader"
        case .fragment: return "MTLFragmentShader"
        case .kernel, .compute: return "MTLComputeShader"
        case .unknown: return "MTLUnknownShader"
        case .custom(let s): return s
        }
    }
    
    public var raw: String {
        switch self {
        case .vertex: return "vertex"
        case .fragment: return "fragment"
        case .kernel: return "kernel"
        case .compute: return "compute"
        case .unknown: return "unknown"
        case .custom(let s): return s
        }
    }
    
    public static func from(rawValue: String) -> ShaderGroup {
        switch rawValue.lowercased() {
        case "vertex": return .vertex
        case "fragment": return .fragment
        case "kernel": return .kernel
        case "compute": return .compute
        default: return .custom(rawValue)
        }
    }
}

/// Parses Metal shader source code for top-level function declarations and groups them by shader type or custom group comments in source.
/// The parser scans the entire input at once, supporting multi-line function signatures via dotMatchesLineSeparators option.
/// Custom groups are assigned based on the nearest preceding comment of form `//MTLShaderGroup: GroupName` (if any),
/// otherwise the function type (vertex|fragment|kernel|compute) is used as the group.
/// Returns array of tuples: (group name string, function name string).
public func parseShaderFunctions(from text: String) -> [(String, String)] {
    var results: [(String, String)] = []
    let functionPattern = #"\b(vertex|fragment|kernel|compute)\s+\w+\s+(\w+)\s*\("#
    let commentPattern = #"//MTLShaderGroup:\s*([A-Za-z_][A-Za-z0-9_]*)"#
    
    guard let functionRegex = try? NSRegularExpression(pattern: functionPattern, options: [.dotMatchesLineSeparators]),
          let commentRegex = try? NSRegularExpression(pattern: commentPattern, options: []) else {
        return results
    }
    
    // Split source text into lines for mapping line numbers
    let lines = text.components(separatedBy: .newlines)
    
    // Collect all comment matches with their line number and group string
    var commentPositions: [(line: Int, group: String)] = []
    for (idx, line) in lines.enumerated() {
        if let match = commentRegex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..<line.endIndex, in: line)),
           let groupRange = Range(match.range(at: 1), in: line) {
            let groupStr = String(line[groupRange])
            commentPositions.append((line: idx, group: groupStr))
        }
    }
    
    // Helper: Given a function match's start position, find its line number in text
    func lineNumber(of position: Int, in text: String) -> Int {
        // Count number of newlines before the position
        var count = 0
        var idx = text.startIndex
        var pos = 0
        while idx < text.endIndex && pos < position {
            if text[idx] == "\n" {
                count += 1
            }
            idx = text.index(after: idx)
            pos += 1
        }
        return count
    }
    
    // Find all function matches in the entire text
    let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
    let matches = functionRegex.matches(in: text, options: [], range: fullRange)
    
    for match in matches {
        guard match.numberOfRanges >= 3,
              let typeRange = Range(match.range(at: 1), in: text),
              let nameRange = Range(match.range(at: 2), in: text) else {
            continue
        }
        let typeStr = String(text[typeRange])
        let funcName = String(text[nameRange])
        
        // Determine line number of function declaration start
        let matchLine = lineNumber(of: match.range.location, in: text)
        
        // Find the closest preceding comment group for this function, if any
        // Binary search or linear search since commentPositions is sorted
        var assignedGroup: String? = nil
        for comment in commentPositions.reversed() {
            if comment.line <= matchLine {
                assignedGroup = comment.group
                break
            }
        }
        let group = assignedGroup ?? typeStr
        results.append((group, funcName))
    }
    
    return results
}

/// Generates Swift enum source code for the discovered shader functions grouped by custom or default enum names.
/// - Parameters:
///   - functionsByType: A dictionary mapping ShaderGroup to a set of function names.
///   - moduleName: A string prefix to prepend to each generated enum name.
/// - Returns: A string containing the generated Swift code for shader enums.
public func generateShaderEnums(functionsByType: [ShaderGroup: Set<String>], moduleName: String) -> String {
    let enumGroups = functionsByType.keys.sorted { $0.description < $1.description }
    guard !enumGroups.isEmpty else {
        return "// No shaders found.\n"
    }
    var swiftCode = "// Generated by ShaderEnumGenerator\n\nimport Metal\n\n"
    for enumGroup in enumGroups {
        let functionNames = functionsByType[enumGroup]!.sorted()
        let enumName = "\(moduleName)_\(enumGroup.description)"
        swiftCode += "public enum \(enumName): String, CaseIterable {\n"
        for name in functionNames {
            swiftCode += "    case \(name) = \"\(name)\"\n"
        }
        swiftCode += "}\n\n"
    }
    
    for enumGroup in enumGroups {
        let enumName = "\(moduleName)_\(enumGroup.description)"
        swiftCode += "extension MTLLibrary {\n"
        swiftCode += "    public func makeFunction(_ shader: \(enumName)) -> MTLFunction? {\n"
        swiftCode += "        makeFunction(name: shader.rawValue)\n"
        swiftCode += "    }\n"
        swiftCode += "}\n\n"
    }
    
    return swiftCode
}
