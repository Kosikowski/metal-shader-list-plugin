//
//  ShaderEnumGeneratorCore.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 24/06/2025.
//

// Shared core logic for parsing Metal shaders and generating Swift enums
import Foundation

let shaderGroupCommentPrefix = "MTLShaderGroup:"
let shaderGroupCommentMarker = "//" + shaderGroupCommentPrefix

// MARK: - Shader Group Validation

/// Validates that a shader group name only contains A-Z and a-z characters
/// - Parameter groupName: The shader group name to validate
/// - Throws: Error if invalid
public func validateShaderGroupName(_ groupName: String) throws {
    let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedName.isEmpty else {
        throw NSError(domain: "ShaderEnumGenerator", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Shader group name cannot be empty",
        ])
    }

    if let invalidCharacter = trimmedName.first(where: { !($0.isASCII && $0.isLetter) }) {
        throw NSError(domain: "ShaderEnumGenerator", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Invalid shader group name '\(trimmedName)': Contains invalid character '\(invalidCharacter)'. Only A-Z and a-z characters are allowed",
        ])
    }
}

/// Extracts and validates shader group names from Metal shader source code.
/// Comments are stripped first, so markers inside commented-out code are ignored,
/// and any spelling `removingAllComments` normalizes (e.g. `// MTLShaderGroup:`) is validated.
/// - Parameter text: The Metal shader source code
/// - Throws: Error if validation fails
public func validateShaderGroupNames(in text: String) throws {
    for line in removingAllComments(from: text).components(separatedBy: .newlines) {
        guard let markerRange = line.range(of: shaderGroupCommentMarker) else { continue }
        let groupName = line[markerRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try validateShaderGroupName(groupName)
        } catch {
            var message = error.localizedDescription
            if let lineNumber = lineNumber(ofGroupComment: groupName, in: text) {
                message = "Invalid shader group name at line \(lineNumber): \(message)"
            }
            throw NSError(domain: "ShaderEnumGenerator", code: 3, userInfo: [
                NSLocalizedDescriptionKey: message,
            ])
        }
    }
}

/// Best-effort lookup of the 1-based line carrying the given group name in the original
/// source, so errors can point at the file as written rather than the comment-stripped text.
private func lineNumber(ofGroupComment groupName: String, in source: String) -> Int? {
    for (index, line) in source.components(separatedBy: .newlines).enumerated() {
        guard let markerRange = line.range(of: shaderGroupCommentPrefix) else { continue }
        if line[markerRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines) == groupName {
            return index + 1
        }
    }
    return nil
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
/// - Throws: An error describing the first invalid shader group name, if any.
public func parseShaderFunctions(from text: String) throws -> [(String, String)] {
    try validateShaderGroupNames(in: text)

    let text = removingAllComments(from: text)
    var results: [(String, String)] = []
    let functionPattern = #"(?m)^\s*(vertex|fragment|kernel|compute)\s+[^()]+\s+(\w+)\s*\("#
    let commentPattern = shaderGroupCommentMarker + #"\s*([A-Za-z]+)"#

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

    // Line start offsets in UTF-16 units, the same measure NSRegularExpression ranges use
    var lineStartOffsets: [Int] = []
    var offset = 0
    for line in lines {
        lineStartOffsets.append(offset)
        offset += line.utf16.count + 1
    }

    // Index of the line containing the given match location (last line start <= location)
    func lineIndex(ofUTF16Offset location: Int) -> Int {
        var low = 0
        var high = lineStartOffsets.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStartOffsets[mid] <= location {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
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
        let matchLine = lineIndex(ofUTF16Offset: match.range.location)

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
/// Groups whose enum names coincide (e.g. `.kernel` and `.compute`, or a custom group named
/// after a built-in one) are merged into a single enum so the output always compiles.
/// - Parameters:
///   - functionsByType: A dictionary mapping ShaderGroup to a set of function names.
///   - moduleName: A string prefix for the parent enum name; sanitized into a valid Swift identifier.
/// - Returns: A string containing the generated Swift code for shader enums.
public func generateShaderEnums(functionsByType: [ShaderGroup: Set<String>], moduleName: String) -> String {
    var functionsByEnumName: [String: Set<String>] = [:]
    for (group, names) in functionsByType {
        functionsByEnumName[sanitizedIdentifier(group.description), default: []].formUnion(names)
    }
    let enumNames = functionsByEnumName.keys.sorted()
    guard !enumNames.isEmpty else {
        return "// No shaders found.\n"
    }
    let parentEnumName = sanitizedIdentifier(moduleName) + "MTLShaders"
    var swiftCode = "// Generated by ShaderEnumGenerator\n\nimport Metal\n\n"
    swiftCode += "public enum \(parentEnumName) {\n"
    for enumName in enumNames {
        let functionNames = functionsByEnumName[enumName]!.sorted()
        swiftCode += "    public enum \(enumName): String, CaseIterable {\n"
        for name in functionNames {
            swiftCode += "        case \(escapedIdentifier(name)) = \"\(name)\"\n"
        }
        swiftCode += "    }\n"
    }
    swiftCode += "}\n\n"
    // MTLLibrary extensions for every nested group
    for (index, enumName) in enumNames.enumerated() {
        swiftCode += "extension MTLLibrary {\n"
        swiftCode += "    public func makeFunction(_ shader: \(parentEnumName).\(enumName)) -> MTLFunction? {\n"
        swiftCode += "        makeFunction(name: shader.rawValue)\n"
        swiftCode += "    }\n"
        swiftCode += "}\n"
        if index < enumNames.count - 1 {
            swiftCode += "\n"
        }
    }
    return swiftCode
}

/// Swift keywords that need backticks when used as an enum case name in generated code.
private let swiftKeywords: Set<String> = [
    "Any", "Self", "as", "associatedtype", "break", "case", "catch", "class", "continue",
    "default", "defer", "deinit", "do", "else", "enum", "extension", "fallthrough", "false",
    "fileprivate", "for", "func", "guard", "if", "import", "in", "init", "inout", "internal",
    "is", "let", "nil", "operator", "precedencegroup", "private", "protocol", "public",
    "repeat", "rethrows", "return", "self", "static", "struct", "subscript", "super",
    "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while",
]

private func escapedIdentifier(_ name: String) -> String {
    swiftKeywords.contains(name) ? "`\(name)`" : name
}

/// Maps an arbitrary target/module name onto a valid Swift identifier:
/// invalid characters become underscores and a leading digit gets an underscore prefix.
func sanitizedIdentifier(_ name: String) -> String {
    let mapped = name.map { character -> Character in
        (character.isASCII && (character.isLetter || character.isNumber)) || character == "_" ? character : "_"
    }
    var identifier = String(mapped)
    if identifier.isEmpty {
        identifier = "_"
    }
    if identifier.first!.isNumber {
        identifier = "_" + identifier
    }
    return identifier
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
                output.append(shaderGroupCommentMarker)
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
