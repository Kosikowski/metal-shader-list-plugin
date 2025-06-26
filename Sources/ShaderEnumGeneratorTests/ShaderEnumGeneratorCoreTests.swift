//
//  ShaderEnumGeneratorCoreTests.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 24/06/2025.
//


import Testing
@testable import ShaderEnumGeneratorCore

@Suite("ShaderEnumGeneratorCore - Metal parsing and code generation")
struct ShaderEnumGeneratorCoreTests {
    @Test("Parses vertex and fragment shaders and generates expected enums")
    func testParseAndGenerate() async throws {
        let metalSource = """
        vertex float4 vertex_passthrough(float4 in [[stage_in]]) { return in; }
        fragment float4 fragment_main() { return float4(1); }
        kernel void kernel_func() { }
        """
        let functions = parseShaderFunctions(from: metalSource)
        #expect(functions.count == 3)
        #expect(functions.contains(where: { $0.0 == "vertex" && $0.1 == "vertex_passthrough" }))
        #expect(functions.contains(where: { $0.0 == "fragment" && $0.1 == "fragment_main" }))
        #expect(functions.contains(where: { $0.0 == "kernel" && $0.1 == "kernel_func" }))
        var grouped: [ShaderGroup: Set<String>] = [:]
        for (enumName, name) in functions { grouped[ShaderGroup.from(rawValue: enumName), default: []].insert(name) }
        let code = generateShaderEnums(functionsByType: grouped)
        #expect(code.contains("public enum MTLVertexShader: String, CaseIterable"))
        #expect(code.contains("case vertex_passthrough = \"vertex_passthrough\""))
        #expect(code.contains("public enum MTLFragmentShader: String, CaseIterable"))
        #expect(code.contains("case fragment_main = \"fragment_main\""))
        #expect(code.contains("public enum MTLComputeShader: String, CaseIterable"))
        #expect(code.contains("case kernel_func = \"kernel_func\""))
    }

    @Test("Returns empty output if no shaders are found")
    func testNoShaders() async throws {
        let metalSource = "// No shader functions"
        let functions = parseShaderFunctions(from: metalSource)
        var grouped: [ShaderGroup: Set<String>] = [:]
        for (enumName, name) in functions { grouped[ShaderGroup.from(rawValue: enumName), default: []].insert(name) }
        let code = generateShaderEnums(functionsByType: grouped)
        #expect(code.starts(with: "// No shaders found."))
    }

    @Test("Parses shaders with extra whitespace and newlines")
    func testParseIrregularWhitespace() async throws {
        let metalSource = """
        vertex\nfloat4\nvertex_newline(float4 in [[stage_in]]) { return in; }
        fragment\tfloat4\tfragment_tabbed ( ) { return float4(1); }
        kernel    void    kernel_spaced   ( ) { }
        compute\n   void\n   compute_mixed ( ) { }
        """
        let functions = parseShaderFunctions(from: metalSource)
        #expect(functions.contains(where: { $0.0 == "vertex" && $0.1 == "vertex_newline" }))
        #expect(functions.contains(where: { $0.0 == "fragment" && $0.1 == "fragment_tabbed" }))
        #expect(functions.contains(where: { $0.0 == "kernel" && $0.1 == "kernel_spaced" }))
        #expect(functions.contains(where: { $0.0 == "compute" && $0.1 == "compute_mixed" }))
        
        #expect(functions.count == 4)
    }

    @Test("Ignores leading/trailing whitespace in function declaration")
    func testParseLeadingTrailingWhitespace() async throws {
        let metalSource = """
          kernel   void    spaced_func    ( ) { }
        """
        let functions = parseShaderFunctions(from: metalSource)
        #expect(functions.count == 1)
        #expect(functions[0].0 == "kernel")
        #expect(functions[0].1 == "spaced_func")
    }
    
    @Test("Parses custom group comment and generates correct enum")
    func testCustomGroupComment() async throws {
        let metalSource = """
        //MTLShaderGroup: FancyShaderGroup
        kernel void customFunc() { }
        //MTLShaderGroup: Another
        fragment float4 otherFunc() { return float4(1); }
        """
        let functions = parseShaderFunctions(from: metalSource)
        #expect(functions.count == 2)
        var grouped: [ShaderGroup: Set<String>] = [:]
        for (enumName, name) in functions { grouped[ShaderGroup.from(rawValue: enumName), default: []].insert(name) }
        let code = generateShaderEnums(functionsByType: grouped)
        #expect(code.contains("public enum FancyShaderGroup: String, CaseIterable"))
        #expect(code.contains("case customFunc = \"customFunc\""))
        #expect(code.contains("public enum Another: String, CaseIterable"))
        #expect(code.contains("case otherFunc = \"otherFunc\""))
    }
    
    @Test("Parses custom group comment and generates correct enum")
    func testCustomGroupCommentWithWhitespaces() async throws {
        let metalSource = """
        //MTLShaderGroup: FancyShaderGroup
        vertex\n    float4\n    vertex_newline(float4 in [[stage_in]]) { return in; }
        //MTLShaderGroup: Another
        fragment\tfloat4\tfragment_tabbed ( ) { return float4(1); }
        """
        let functions = parseShaderFunctions(from: metalSource)
        #expect(functions.count == 2)
        var grouped: [ShaderGroup: Set<String>] = [:]
        for (enumName, name) in functions { grouped[ShaderGroup.from(rawValue: enumName), default: []].insert(name) }
        let code = generateShaderEnums(functionsByType: grouped)
        #expect(code.contains("public enum FancyShaderGroup: String, CaseIterable"))
        #expect(code.contains("case vertex_newline = \"vertex_newline\""))
        #expect(code.contains("public enum Another: String, CaseIterable"))
        #expect(code.contains("case fragment_tabbed = \"fragment_tabbed\""))
    }
}

