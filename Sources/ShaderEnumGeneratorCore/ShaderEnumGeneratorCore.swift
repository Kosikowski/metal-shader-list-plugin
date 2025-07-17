//
//  ShaderEnumGeneratorCore.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 24/06/2025.
//

// Shared core logic for parsing Metal shaders and generating Swift enums
import Foundation

let shaderGroupCommentPrefix = "MTLShaderGroup:"

public enum ShaderGroup: Hashable, Equatable, CustomStringConvertible {
    case vertex, fragment, kernel, compute, unknown
    case custom(String)

    public var description: String {
        switch self {
        case .vertex: return "MTLVertexShader"
        case .fragment: return "MTLFragmentShader"
        case .kernel, .compute: return "MTLComputeShader"
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
    let text = removingAllComments(from: text)
    var results: [(String, String)] = []
    let functionPattern = #"(?m)^\s*(vertex|fragment|kernel|compute)\s+[^()]+\s+(\w+)\s*\("#
    let commentPattern = "//" + shaderGroupCommentPrefix + #"\s*([A-Za-z_][A-Za-z0-9_]*)"#

    guard let functionRegex = try? NSRegularExpression(pattern: functionPattern, options: [.dotMatchesLineSeparators]),
          let commentRegex = try? NSRegularExpression(pattern: commentPattern, options: [])
    else {
        return results
    }

    // Split source text into lines for mapping line numbers
    let lines = text.components(separatedBy: .newlines)

    // Collect all comment matches with their line number and group string
    var commentPositions: [(line: Int, group: String)] = []
    for (idx, line) in lines.enumerated() {
        if let match = commentRegex.firstMatch(in: line, options: [], range: NSRange(line.startIndex ..< line.endIndex, in: line)),
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
    let fullRange = NSRange(text.startIndex ..< text.endIndex, in: text)
    let matches = functionRegex.matches(in: text, options: [], range: fullRange)

    for match in matches {
        guard match.numberOfRanges >= 3,
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
/// Returns the code with all comments removed, retaining newlines to preserve structure.
func removingAllComments(from text: String) -> String {
    var output = "" // The output string, accumulating non-comment/non-skipped characters
    var i = text.startIndex
    let end = text.endIndex
    // State variables:
    var inString = false // True if inside a string literal (single or double quotes)
    var stringDelimiter: Character? = nil // Tracks which quote opened the string
    var inLineComment = false // True if inside a line comment (//)
    var inBlockComment = false // True if inside a block comment (/* */)
    var prevChar: Character? = nil // Tracks previous character (for escaped strings)

    // Helper: Check if a line comment starts at the first non-whitespace character and is NOT a shader group comment
    func isRemovableFullLineComment(at idx: String.Index) -> Bool {
        // Find the start of the line
        var lineStart = idx
        while lineStart > text.startIndex && text[text.index(before: lineStart)] != "\n" {
            lineStart = text.index(before: lineStart)
        }
        // Skip whitespace
        var scan = lineStart
        while scan < end, text[scan].isWhitespace, text[scan] != "\n" {
            scan = text.index(after: scan)
        }
        // Check for // or ///
        if scan < end && text[scan] == "/" {
            let next = text.index(after: scan)
            if next < end && text[next] == "/" {
                // Check if this is a shader group comment
                let afterSlashes = text.index(next, offsetBy: 1, limitedBy: end) ?? end
                let groupPrefix = "MTLShaderGroup:"
                if afterSlashes < end {
                    let remaining = text[afterSlashes..<end]
                    if remaining.trimmingCharacters(in: .whitespaces).hasPrefix(groupPrefix) {
                        return false // It's a shader group comment, do not remove
                    }
                }
                // It's a removable full-line comment
                return scan == idx
            }
        }
        return false
    }

    // Iterate through the entire string character by character
    while i < end {
        let c = text[i] // Current character
        let nextIndex = text.index(after: i)
        let nextChar = nextIndex < end ? text[nextIndex] : nil // Next character, if available

        if inLineComment {
            // If we're inside a line comment, only end it when we see a newline
            if c == "\n" {
                inLineComment = false // Exiting line comment
                output.append(c) // Preserve the newline
            }
            i = text.index(after: i)
            continue // Skip all other characters in the comment
        } else if inBlockComment {
            // If inside a block comment, look specifically for the closing '*/'
            if c == "*" && nextChar == "/" {
                inBlockComment = false // Exiting block comment
                // Skip all consecutive '*/' sequences
                var idx = text.index(i, offsetBy: 2, limitedBy: end) ?? end
                while idx < end {
                    let nextStar = idx < end ? text[idx] : nil
                    let nextSlash = (idx < end && text.index(after: idx) < end) ? text[text.index(after: idx)] : nil
                    if nextStar == "*" && nextSlash == "/" {
                        idx = text.index(idx, offsetBy: 2, limitedBy: end) ?? end
                    } else {
                        break
                    }
                }
                i = idx
                prevChar = nil
                continue
            }
            // Otherwise, skip this character
            i = text.index(after: i)
            continue
        } else if inString {
            // If in a string literal, always append the character
            output.append(c)
            // Only exit string if the delimiter (single/double quote) is found and not escaped
            if c == stringDelimiter && prevChar != "\\" {
                inString = false
                stringDelimiter = nil
            }
            prevChar = c
            i = text.index(after: i)
            continue
        } else {
            // Not in comment or string: check for new string, comment, or regular code

            // Start of a string literal (single or double quote)
            if (c == "\"" || c == "'") {
                inString = true
                stringDelimiter = c
                output.append(c)
                prevChar = c
                i = text.index(after: i)
                continue
            }
            // Start of a line comment ('//'), but not inside a string or block comment
            if c == "/" && nextChar == "/" {
                // Check if this is a removable full-line comment (not a shader group comment)
                if isRemovableFullLineComment(at: i) {
                    // Skip to the next newline (remove the whole line)
                    var skipIdx = i
                    while skipIdx < end && text[skipIdx] != "\n" {
                        skipIdx = text.index(after: skipIdx)
                    }
                    // If we stopped at a newline, skip it too
                    if skipIdx < end && text[skipIdx] == "\n" {
                        skipIdx = text.index(after: skipIdx)
                    }
                    i = skipIdx
                    prevChar = nil
                    continue
                }
                // Check if this comment is a shader group comment
                // Look ahead to see if after "//" is "MTLShaderGroup:" or " MTLShaderGroup:"
                let commentStartIndex = text.index(i, offsetBy: 2, limitedBy: end) ?? end
                // Extract substring from commentStartIndex to next newline or end of text
                var commentEndIndex = commentStartIndex
                while commentEndIndex < end && text[commentEndIndex] != "\n" {
                    commentEndIndex = text.index(after: commentEndIndex)
                }
                let commentContent = text[commentStartIndex..<commentEndIndex]
                let commentString = commentContent.trimmingCharacters(in: .whitespaces)
                if commentString.hasPrefix(shaderGroupCommentPrefix) {
                    // Append entire comment line including "//"
                    output.append("//")
                    output.append(contentsOf: commentString)
                    // Append newline if present
                    if commentEndIndex < end && text[commentEndIndex] == "\n" {
                        output.append("\n")
                        i = text.index(after: commentEndIndex)
                    } else {
                        i = commentEndIndex
                    }
                    prevChar = nil
                    continue
                } else {
                    // Normal line comment - skip it
                    inLineComment = true
                    // Skip both '/' characters (don't append either)
                    i = text.index(i, offsetBy: 2, limitedBy: end) ?? end
                    prevChar = c
                    continue
                }
            }
            // Start of a block comment ('/* ... */')
            if c == "/" && nextChar == "*" {
                inBlockComment = true
                // Skip both '/' and '*' characters
                i = text.index(i, offsetBy: 2, limitedBy: end) ?? end
                prevChar = c
                continue
            }
            // Otherwise, it's regular code: append the character
            output.append(c)
            prevChar = c
            i = text.index(after: i)
        }
    }
    // When finished, 'output' contains all code with comments removed
    // Remove all empty lines (lines containing only whitespace)
    let lines = output.components(separatedBy: .newlines)
    let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    return nonEmptyLines.joined(separator: "\n")
}

