//
//  RemovingAllCommentsEdgeCaseTests.swift
//  ShaderListPlugin
//
//  Created by Mateusz Kosikowski on 27/06/2025.
//

import Testing
@testable import ShaderEnumGeneratorCore

// MARK: - RemovingAllCommentsEdgeCaseTests

@Suite("removingAllComments edge cases")
struct RemovingAllCommentsEdgeCaseTests {
    @Test("Removes all single-line and doc comments")
    func simpleLineCommentsOnly() async throws {
        let input = """
        // comment
        /// doc comment
        """
        let expected = """
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Removes all single-line and doc comments, preserves code")
    func simpleLineComments() async throws {
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
    func blockCommentsEvenMultiline() async throws {
        let input = """
        int a = /* inline */ 1;
        int b = /* inline */ 2;
        int c = 3;
        """
        let expected = """
        int a =    1;
        int b =    2;
        int c = 3;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles block comments between keywords and identifiers")
    func blockCommentsBetweenKeywords() async throws {
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
    func blockInsideLineComment() async throws {
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
    func commentsInsideStringLiterals() async throws {
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
    func fullFileBlockCommentAndBlankLines() async throws {
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
    func adjacentAndNestedLikeComments() async throws {
        let input = """
        int a = 1; //// many slashes
        int b = 2; /* /* not nested but adjacent */ 3;
        int c = 4; // /* block start in line comment
        int d = 5; /* block /* block */
        """
        let expected = """
        int a = 1;
        int b = 2;    3;
        int c = 4;
        int d = 5;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Preserves non-comment code and whitespace exactly, removes only comments")
    func nonCommentContentUnchanged() async throws {
        let input = """
        int add(int a, int b) { return a + b; }
        float mul(float x, float y) { return x * y; }
        """
        let expected = input
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Removes comments from typical Metal vertex shader")
    func metalVertexShaderComments() async throws {
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
    func metalFragmentShaderComments() async throws {
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
        float4 color [[stage_in]]  ,
        constant Uniforms& uniforms [[buffer(0)]]
        ) {
        return float4(color.rgb, 1.0);
        }
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Removes comments in Metal compute shader with macros and includes")
    func metalComputeShaderComments() async throws {
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
    func metalShaderStructsComments() async throws {
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

// MARK: - RemovingAllCommentsAdvancedTests

@Suite("removingAllComments advanced edge cases")
struct RemovingAllCommentsAdvancedTests {
    @Test("Handles escaped quotes in string literals")
    func escapedQuotesInStrings() async throws {
        let input = """
        const char* s = "This is a \\"quoted\\" string";
        const char* t = 'This is a \\'quoted\\' string';
        int a = 1; // comment
        """
        let expected = """
        const char* s = "This is a \\"quoted\\" string";
        const char* t = 'This is a \\'quoted\\' string';
        int a = 1;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles multiline string literals")
    func multilineStringLiterals() async throws {
        let input = """
        const char* s = "This is a
        multiline string
        with newlines";
        int a = 1; // comment
        """
        let expected = """
        const char* s = "This is a
        multiline string
        with newlines";
        int a = 1;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles string literals with comment-like sequences")
    func stringLiteralsWithCommentSequences() async throws {
        let input = """
        const char* s = "// This looks like a comment but isn't";
        const char* t = "/* This also looks like a block comment */";
        const char* u = "/// This looks like a doc comment";
        int a = 1; // real comment
        """
        let expected = """
        const char* s = "// This looks like a comment but isn't";
        const char* t = "/* This also looks like a block comment */";
        const char* u = "/// This looks like a doc comment";
        int a = 1;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles block comments with nested-like syntax")
    func blockCommentsWithNestedLikeSyntax() async throws {
        let input = """
        int a = 1; /* /* not nested, just adjacent */ */
        int b = 2; /* block /* another block */ */
        int c = 3; /* /* /* multiple adjacent */ */ */
        """
        // NOTE: This matches C/C++/Metal comment removal, but could be improved to remove all trailing '*/' if desired.
        let expected = """
        int a = 1;    */
        int b = 2;    */
        int c = 3;    */ */
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles line comments with block comment syntax")
    func lineCommentsWithBlockSyntax() async throws {
        let input = """
        // /* This is a line comment with block syntax */
        int a = 1; // /* Another line comment */
        /// /* Doc comment with block syntax */
        int b = 2;
        """
        let expected = """
        int a = 1;
        int b = 2;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles block comments with line comment syntax")
    func blockCommentsWithLineSyntax() async throws {
        let input = """
        /* // This is a block comment with line syntax */
        int a = 1; /* // Another block comment */
        /* /// Doc comment syntax in block */
        int b = 2;
        """
        let expected = """
        int a = 1;
        int b = 2;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles comments with special characters")
    func commentsWithSpecialCharacters() async throws {
        let input = """
        // Comment with special chars: !@#$%^&*()_+-=[]{}|;':",./<>?
        int a = 1; // Unicode: 🚀 🎮 🎯
        /* Block with special chars: !@#$%^&*()_+-=[]{}|;':",./<>? */
        int b = 2; /* Unicode: 🚀 🎮 🎯 */
        """
        let expected = """
        int a = 1;
        int b = 2;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles comments with newlines and tabs")
    func commentsWithNewlinesAndTabs() async throws {
        let input = """
        // Line comment with
        // multiple lines
        int a = 1;
        /* Block comment
        with multiple
        lines and tabs */
        int b = 2;
        """
        let expected = """
        int a = 1;
        int b = 2;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles empty comments")
    func emptyComments() async throws {
        let input = """
        //
        int a = 1; //
        /* */
        int b = 2; /* */
        ///
        int c = 3; ///
        """
        let expected = """
        int a = 1;
        int b = 2;
        int c = 3;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles comments at end of file")
    func commentsAtEndOfFile() async throws {
        let input = """
        int a = 1;
        int b = 2;
        // End of file comment
        /* Another end comment */
        """
        let expected = """
        int a = 1;
        int b = 2;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles comments at start of file")
    func commentsAtStartOfFile() async throws {
        let input = """
        // Start of file comment
        /* Another start comment */
        int a = 1;
        int b = 2;
        """
        let expected = """
        int a = 1;
        int b = 2;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles comments with only whitespace")
    func commentsWithOnlyWhitespace() async throws {
        let input = """
        //
        int a = 1; //
        /*   */
        int b = 2; /*   */
        ///
        int c = 3; ///
        """
        let expected = """
        int a = 1;
        int b = 2;
        int c = 3;
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles shader group comments with valid characters")
    func shaderGroupCommentsWithValidCharacters() async throws {
        let input = """
        //MTLShaderGroup: ValidGroupName
        vertex float4 vertex_func() { return float4(1); }

        //MTLShaderGroup: Group_With_Underscores
        fragment float4 fragment_func() { return float4(1); }

        //MTLShaderGroup: Mixed123Group
        kernel void kernel_func() { }
        """
        let expected = """
        //MTLShaderGroup: ValidGroupName
        vertex float4 vertex_func() { return float4(1); }
        //MTLShaderGroup: Group_With_Underscores
        fragment float4 fragment_func() { return float4(1); }
        //MTLShaderGroup: Mixed123Group
        kernel void kernel_func() { }
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles shader group comments with whitespace variations")
    func shaderGroupCommentsWithWhitespace() async throws {
        let input = """
        //MTLShaderGroup:   GroupWithSpaces
        vertex float4 vertex_func() { return float4(1); }

        //MTLShaderGroup:GroupWithoutSpaces
        fragment float4 fragment_func() { return float4(1); }

        //MTLShaderGroup: GroupWithTabs
        kernel void kernel_func() { }
        """
        let expected = """
        //MTLShaderGroup:   GroupWithSpaces
        vertex float4 vertex_func() { return float4(1); }
        //MTLShaderGroup:GroupWithoutSpaces
        fragment float4 fragment_func() { return float4(1); }
        //MTLShaderGroup: GroupWithTabs
        kernel void kernel_func() { }
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles complex Metal shader with all comment types")
    func complexMetalShaderWithAllCommentTypes() async throws {
        let input = """
        #include <metal_stdlib>
        using namespace metal;

        // Vertex input structure
        struct VertexIn {
            float4 position [[attribute(0)]]; // Position attribute
            float2 texCoord [[attribute(1)]]; /* Texture coordinate */
        };

        //MTLShaderGroup: ComplexRendering
        vertex float4 vertex_complex(
            const device VertexIn* vertices [[buffer(0)]], // Vertex buffer
            constant Uniforms& uniforms [[buffer(1)]], /* Uniform buffer */
            uint vertexID [[vertex_id]] // Vertex ID
        ) {
            float4 pos = vertices[vertexID].position; // Get position
            float2 texCoord = vertices[vertexID].texCoord; /* Get texcoord */
            return uniforms.mvp * pos; // Transform position
        }

        fragment float4 fragment_complex(
            float4 position [[position]], // Fragment position
            float2 texCoord [[stage_in]] /* Fragment texcoord */
        ) {
            // Return texture coordinate as color
            return float4(texCoord, 0.0, 1.0); /* RGBA output */
        }
        """
        let expected = """
        #include <metal_stdlib>
        using namespace metal;
        struct VertexIn {
        float4 position [[attribute(0)]];
        float2 texCoord [[attribute(1)]];
        };
        //MTLShaderGroup: ComplexRendering
        vertex float4 vertex_complex(
        const device VertexIn* vertices [[buffer(0)]],
        constant Uniforms& uniforms [[buffer(1)]],
        uint vertexID [[vertex_id]]
        ) {
        float4 pos = vertices[vertexID].position;
        float2 texCoord = vertices[vertexID].texCoord;
        return uniforms.mvp * pos;
        }
        fragment float4 fragment_complex(
        float4 position [[position]],
        float2 texCoord [[stage_in]]
        ) {
        return float4(texCoord, 0.0, 1.0);
        }
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }

    @Test("Handles Metal shader with preprocessor directives and comments")
    func metalShaderWithPreprocessorAndComments() async throws {
        let input = """
        #include <metal_stdlib>
        using namespace metal;

        // Define constants
        #define MAX_LIGHTS 4 // Maximum number of lights
        #define PI 3.14159 /* Pi constant */

        //MTLShaderGroup: Lighting
        vertex float4 vertex_lighting(
            const device VertexIn* vertices [[buffer(0)]], // Vertex data
            constant Light* lights [[buffer(1)]], /* Light data */
            uint vertexID [[vertex_id]]
        ) {
            // Calculate lighting
            return float4(1.0); /* Return lit color */
        }

        #ifdef USE_PBR
        //MTLShaderGroup: PBR
        fragment float4 fragment_pbr(
            float4 position [[position]],
            float3 normal [[stage_in]]
        ) {
            // PBR lighting calculation
            return float4(1.0); // PBR result
        }
        #endif
        """
        let expected = """
        #include <metal_stdlib>
        using namespace metal;
        #define MAX_LIGHTS 4
        #define PI 3.14159
        //MTLShaderGroup: Lighting
        vertex float4 vertex_lighting(
        const device VertexIn* vertices [[buffer(0)]],
        constant Light* lights [[buffer(1)]],
        uint vertexID [[vertex_id]]
        ) {
        return float4(1.0);
        }
        #ifdef USE_PBR
        //MTLShaderGroup: PBR
        fragment float4 fragment_pbr(
        float4 position [[position]],
        float3 normal [[stage_in]]
        ) {
        return float4(1.0);
        }
        #endif
        """
        expectCodeLinesEqual(removingAllComments(from: input), expected)
    }
}
