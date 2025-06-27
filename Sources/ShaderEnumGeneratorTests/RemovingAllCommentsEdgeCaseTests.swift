//
//  RemovingAllCommentsEdgeCaseTests.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 27/06/2025.
//

@testable import ShaderEnumGeneratorCore
import Testing
@testable import ShaderEnumGeneratorCore

@Suite("removingAllComments edge cases")
struct RemovingAllCommentsEdgeCaseTests {
    @Test("Removes all single-line and doc comments")
    func testSimpleLineCommentsOnly() async throws {
        let input = """
        // comment
        /// doc comment
        """
        let expected = """
        
        
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }
    
    @Test("Removes all single-line and doc comments, preserves code")
    func testSimpleLineComments() async throws {
        let input = """
        // comment
        int a = 1; // end-of-line comment
        /// doc comment
        int b = 2;
        """
        let expected = """
        
        int a = 1; 
        
        int b = 2;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Removes block comments, even multiline")
    func testBlockComments() async throws {
        let input = """
        int a = /* inline */ 1;
        int b = /* multiline
        block comment */ 2;
        /* full line block comment */
        int c = 3;
        """
        let expected = """
        int a =  1;
        int b =  2;
        
        int c = 3;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles block comments between keywords and identifiers")
    func testBlockCommentsBetweenKeywords() async throws {
        let input = """
        int/*block*/a = 1;
        float/**/b = 2;
        """
        let expected = """
        inta = 1;
        floatb = 2;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Removes block comments inside single-line comments")
    func testBlockInsideLineComment() async throws {
        let input = """
        // real comment /* fake block */
        int a = 1; // normal
        """
        let expected = """
        
        int a = 1; 
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Does not remove comment-like content inside string literals")
    func testCommentsInsideStringLiterals() async throws {
        let input = """
        const char* s = "// not a comment";
        const char* t = "/* not a block */";
        int a = 1; // real comment
        """
        let expected = """
        const char* s = "// not a comment";
        const char* t = "/* not a block */";
        int a = 1; 
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles block comments spanning entire file and blank lines")
    func testFullFileBlockCommentAndBlankLines() async throws {
        let input = """
        /*
        Block comment at start
        still in comment
        */
        int a = 1;
        // another comment
        
        /* block on empty line */
        int b = 2;
        """
        let expected = """
        
        int a = 1;
        
        
        
        int b = 2;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles adjacent and nested-like comment syntax")
    func testAdjacentAndNestedLikeComments() async throws {
        let input = """
        int a = 1; //// many slashes
        int b = 2; /* /* not nested but adjacent */ 3;
        int c = 4; // /* block start in line comment
        int d = 5; /* block /* block */
        """
        let expected = """
        int a = 1; 
        int b = 2;  3;
        int c = 4; 
        int d = 5; 
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Preserves non-comment code and whitespace exactly, removes only comments")
    func testNonCommentContentUnchanged() async throws {
        let input = """
        int add(int a, int b) { return a + b; }
        float mul(float x, float y) { return x * y; }
        """
        let expected = input
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }
    
    @Test("Removes comments from typical Metal vertex shader")
    func testMetalVertexShaderComments() async throws {
        let input = """
        // Vertex shader
        vertex float4 vertex_main(
            const device VertexIn* vert [[buffer(0)]],
            constant Uniforms& uniforms [[buffer(1)]], // uniforms
            uint vid [[vertex_id]] /* vertex index */
        ) {
            float4 pos = vert[vid].position; // get position
            /*
            Multiline
            block comment in function
            */
            return uniforms.mvp * pos; // MVP transform
        }
        """
        let expected = """
        
        vertex float4 vertex_main(
            const device VertexIn* vert [[buffer(0)]],
            constant Uniforms& uniforms [[buffer(1)]], 
            uint vid [[vertex_id]] 
        ) {
            float4 pos = vert[vid].position; 
            
            return uniforms.mvp * pos; 
        }
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Removes block and line comments from fragment shader")
    func testMetalFragmentShaderComments() async throws {
        let input = """
        fragment float4 fragment_main(
            float4 color [[stage_in]] /* color in [[stage_in]] */, // color param
            constant Uniforms& uniforms [[buffer(0)]]
        ) {
            // return color with alpha
            return float4(color.rgb, 1.0); /* force alpha */
        }
        """
        let expected = """
        fragment float4 fragment_main(
            float4 color [[stage_in]] , 
            constant Uniforms& uniforms [[buffer(0)]]
        ) {
            
            return float4(color.rgb, 1.0); 
        }
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Removes comments in Metal compute shader with macros and includes")
    func testMetalComputeShaderComments() async throws {
        let input = """
        #include <metal_stdlib>
        using namespace metal;
        
        // Macro for threadgroup size
        #define GROUP_SIZE 16 // 16 threads per group
        /* Block comment before kernel */
        kernel void myComputeKernel(
            device float* output [[buffer(0)]],
            uint tid [[thread_position_in_grid]]
        ) {
            output[tid] = float(tid); // write thread index
        }
        """
        let expected = """
        #include <metal_stdlib>
        using namespace metal;
        
        
        #define GROUP_SIZE 16 
        
        kernel void myComputeKernel(
            device float* output [[buffer(0)]],
            uint tid [[thread_position_in_grid]]
        ) {
            output[tid] = float(tid); 
        }
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Removes doc and block comments from real-world shader structure")
    func testMetalShaderStructsComments() async throws {
        let input = """
        /// Vertex input for standard pipeline
        struct VertexIn {
            float4 position [[attribute(0)]]; // Pos
            float2 uv [[attribute(1)]]; /* texcoord */
        };
        
        // Uniforms for all shaders
        struct Uniforms {
            float4x4 mvp; // model-view-projection
        };
        """
        let expected = """
        
        struct VertexIn {
            float4 position [[attribute(0)]]; 
            float2 uv [[attribute(1)]]; 
        };
        
        
        struct Uniforms {
            float4x4 mvp; 
        };
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }
}
