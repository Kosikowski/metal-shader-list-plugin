//
//  ShaderEnumGeneratorCore.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 24/06/2025.
//

// Shared core logic for parsing Metal shaders and generating Swift enums
import Foundation

let shaderGroupCommentPrefix = "MTLShaderGroup:"

// MARK: - Shader Group Validation

/// Validates that a shader group name only contains A-Z and a-z characters
/// - Parameter groupName: The shader group name to validate
/// - Throws: Error if invalid
private func validateShaderGroupName(_ groupName: String) throws {
    let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)

    // Check for empty names
    guard !trimmedName.isEmpty else {
        throw NSError(domain: "ShaderEnumGenerator", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Shader group name cannot be empty",
        ])
    }

    // Check that name only contains A-Z and a-z characters
    let validCharacters = CharacterSet.letters
    let invalidCharacters = trimmedName.unicodeScalars.filter { !validCharacters.contains($0) }

    if !invalidCharacters.isEmpty {
        let invalidChar = String(invalidCharacters.first!)
        throw NSError(domain: "ShaderEnumGenerator", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Invalid shader group name '\(trimmedName)': Contains invalid character '\(invalidChar)'. Only A-Z and a-z characters are allowed",
        ])
    }
}

/// Extracts and validates shader group names from Metal shader source code
/// - Parameter text: The Metal shader source code
/// - Throws: Error if validation fails
private func validateShaderGroupNames(in text: String) throws {
    let lines = text.components(separatedBy: .newlines)

    for (lineNumber, line) in lines.enumerated() {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Look for MTLShaderGroup comments
        if trimmedLine.hasPrefix("//MTLShaderGroup:") {
            let groupName = trimmedLine.replacingOccurrences(of: "//MTLShaderGroup:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                try validateShaderGroupName(groupName)
            } catch {
                throw NSError(domain: "ShaderEnumGenerator", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid shader group name at line \(lineNumber + 1): \(error.localizedDescription)",
                ])
            }
        }
    }
}

// MARK: - ShaderGroup

public enum ShaderGroup: Hashable, Equatable, CustomStringConvertible {
    case vertex
    case fragment
    case kernel
    case compute
    case unknown
    case custom(String)

    // MARK: Computed Properties

    public var description: String {
        switch self {
            case .vertex: return "MTLVertexShader"
            case .fragment: return "MTLFragmentShader"
            case .kernel,
                 .compute: return "MTLComputeShader"
            case .unknown: return "MTLUnknownShader"
            case let .custom(s): return s
        }
    }

    public var raw: String {
        switch self {
            case .vertex: return "vertex"
            case .fragment: return "fragment"
            case .kernel: return "kernel"
            case .compute: return "compute"
            case .unknown: return "unknown"
            case let .custom(s): return s
        }
    }

    // MARK: Static Functions

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
    // Validate shader group names first
    do {
        try validateShaderGroupNames(in: text)
    } catch {
        // Print error and exit with failure
        print("Error: \(error.localizedDescription)")
        exit(1)
    }

    let text = removingAllComments(from: text)
    var results: [(String, String)] = []
    let functionPattern = #"(?m)^\s*(vertex|fragment|kernel|compute)\s+[^()]+\s+(\w+)\s*\("#
    let commentPattern = "//" + shaderGroupCommentPrefix + #"\s*([A-Za-z_][A-Za-z0-9_]*)"#

    guard
        let functionRegex = try? NSRegularExpression(pattern: functionPattern, options: [.dotMatchesLineSeparators]),
        let commentRegex = try? NSRegularExpression(pattern: commentPattern, options: [])
    else {
        return results
    }

    // Split source text into lines for mapping line numbers
    let lines = text.components(separatedBy: .newlines)

    // Collect all comment matches with their line number and group string
    var commentPositions: [(line: Int, group: String)] = []
    for (idx, line) in lines.enumerated() {
        if
            let match = commentRegex.firstMatch(in: line, options: [], range: NSRange(line.startIndex ..< line.endIndex, in: line)),
            let groupRange = Range(match.range(at: 1), in: line)
        {
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
        while idx < text.endIndex, pos < position {
            if text[idx] == "\n" {
                count += 1
            }
            idx = text.index(after: idx)
            pos += 1
        }
        return count
    }

    // Find all function matches in the entire text
    let fullRange = NSRange(text.startIndex ..< text.endIndex, in: text)
    let matches = functionRegex.matches(in: text, options: [], range: fullRange)

    for match in matches {
        guard
            match.numberOfRanges >= 3,
            let typeRange = Range(match.range(at: 1), in: text),
            let nameRange = Range(match.range(at: 2), in: text)
        else {
            continue
        }
        let typeStr = String(text[typeRange])
        let funcName = String(text[nameRange])

        // Determine line number of function declaration start
        let matchLine = lineNumber(of: match.range.location, in: text)

        // Find the closest preceding comment group for this function, if any
        // Binary search or linear search since commentPositions is sorted
        var assignedGroup: String?
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
    let parentEnumName = "\(moduleName)MTLShaders"
    var swiftCode = "// Generated by ShaderEnumGenerator\n\nimport Metal\n\n"
    swiftCode += "public enum \(parentEnumName) {\n"
    for enumGroup in enumGroups {
        let functionNames = functionsByType[enumGroup]!.sorted()
        let nestedEnumName = enumGroup.description
        swiftCode += "    public enum \(nestedEnumName): String, CaseIterable {\n"
        for name in functionNames {
            swiftCode += "        case \(name) = \"\(name)\"\n"
        }
        swiftCode += "    }\n"
    }
    swiftCode += "}\n\n"
    // MTLLibrary extensions for every nested group
    for (index, enumGroup) in enumGroups.enumerated() {
        let nestedEnumName = enumGroup.description
        swiftCode += "extension MTLLibrary {\n"
        swiftCode += "    public func makeFunction(_ shader: \(parentEnumName).\(nestedEnumName)) -> MTLFunction? {\n"
        swiftCode += "        makeFunction(name: shader.rawValue)\n"
        swiftCode += "    }\n"
        swiftCode += "}\n"
        if index < enumGroups.count - 1 {
            swiftCode += "\n"
        }
    }
    return swiftCode
}

/// Removes all line (//, ///) and block (/* */) comments from the input string.
/// Preserves string literals and skips comments even if inside strings.
/// Returns the code with all comments removed, retaining newlines to preserve structure and not leaving trailing spaces or extra blank lines.
func removingAllComments(from text: String) -> String {
    var output = ""
    var i = text.startIndex
    let end = text.endIndex
    var inString = false
    var stringDelimiter: Character? = nil
    var inBlockComment = false
    var prevChar: Character? = nil
    let shaderGroupPrefix = "//" + shaderGroupCommentPrefix
    var lastNewlineIndex: String.Index? = text.startIndex
    var blockCommentIndent = ""

    while i < end {
        let c = text[i]
        let nextIndex = text.index(after: i)
        let nextChar = nextIndex < end ? text[nextIndex] : nil

        if inBlockComment {
            // Look for end of block comment
            if c == "*", nextChar == "/" {
                inBlockComment = false
                // Move i to after the comment
                i = text.index(i, offsetBy: 2, limitedBy: end) ?? end
                // Restore the space that was before the comment
                output.append(blockCommentIndent)
                // Check if there's a space after the block comment
                if i < end, text[i] == " " {
                    output.append(" ")
                }
                blockCommentIndent = ""
                continue
            }
            // Do not append newlines inside block comments
            i = text.index(after: i)
            continue
        }
        if inString {
            output.append(c)
            if c == stringDelimiter, prevChar != "\\" {
                inString = false
                stringDelimiter = nil
            }
            prevChar = c
            if c == "\n" {
                lastNewlineIndex = text.index(after: i)
            }
            i = text.index(after: i)
            continue
        }
        // Start of string literal
        if c == "\"" || c == "'" {
            inString = true
            stringDelimiter = c
            output.append(c)
            prevChar = c
            i = text.index(after: i)
            continue
        }
        // Start of block comment
        if c == "/", nextChar == "*" {
            inBlockComment = true
            // Check if there was a space before the block comment
            let hadSpaceBefore = !output.isEmpty && output.last! == " "
            i = text.index(i, offsetBy: 2, limitedBy: end) ?? end
            // Store whether we had a space before the comment
            blockCommentIndent = hadSpaceBefore ? " " : ""
            continue
        }
        // Start of line comment
        if c == "/", nextChar == "/" {
            // Check if this is a shader group comment
            let commentStartIndex = text.index(i, offsetBy: 2, limitedBy: end) ?? end
            // Find the end of the line
            var commentEndIndex = commentStartIndex
            while commentEndIndex < end, text[commentEndIndex] != "\n" {
                commentEndIndex = text.index(after: commentEndIndex)
            }
            let commentContent = text[commentStartIndex ..< commentEndIndex].trimmingCharacters(in: .whitespaces)
            if commentContent.hasPrefix(shaderGroupCommentPrefix) {
                // Keep the shader group comment as is (trimmed)
                output.append(shaderGroupPrefix)
                output.append(contentsOf: commentContent.dropFirst(shaderGroupCommentPrefix.count))
                if commentEndIndex < end, text[commentEndIndex] == "\n" {
                    output.append("\n")
                    lastNewlineIndex = text.index(after: commentEndIndex)
                    i = text.index(after: commentEndIndex)
                } else {
                    i = commentEndIndex
                }
                prevChar = nil
                continue
            } else {
                // Skip to the end of the line (remove the comment)
                // But if there is code after the comment, preserve indentation
                var afterComment = commentEndIndex
                while afterComment < end, text[afterComment].isWhitespace, text[afterComment] != "\n" {
                    afterComment = text.index(after: afterComment)
                }
                if afterComment < end, text[afterComment] != "\n" {
                    // There is code after the comment on the same line
                    let lineStart = lastNewlineIndex ?? text.startIndex
                    var indent = ""
                    var scan = lineStart
                    while scan < i, text[scan].isWhitespace, text[scan] != "\n" {
                        indent.append(text[scan])
                        scan = text.index(after: scan)
                    }
                    output.append(indent)
                }
                // Skip to the end of the line
                i = commentEndIndex
                if i < end, text[i] == "\n" {
                    output.append("\n")
                    lastNewlineIndex = text.index(after: i)
                    i = text.index(after: i)
                }
                prevChar = nil
                continue
            }
        }
        // Otherwise, regular code
        output.append(c)
        prevChar = c
        if c == "\n" {
            lastNewlineIndex = text.index(after: i)
        }
        i = text.index(after: i)
    }
    // Post-process: remove all leading/trailing whitespace and empty lines
    let lines = output.components(separatedBy: .newlines)
    let cleaned = lines.compactMap { line -> String? in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
    return cleaned.joined(separator: "\n")
}
