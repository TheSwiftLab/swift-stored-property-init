import XCTest

#if canImport(StoredPropertyInitMacros)
import SwiftDiagnostics
import SwiftSyntaxMacrosTestSupport

/// `mode: .storedProperties`의 initializer 렌더링 규칙을 검증하는 테스트입니다.
final class StoredPropertiesRenderingTests: XCTestCase {
    /// 접근 제어자 설정은 생성 initializer에 반영됩니다.
    func testStoredPropertiesModeRendersPrivateInitializerAccess() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(.private)
            struct Credentials {
                let token: String
            }
            """,
            expandedSource: """
            struct Credentials {
                let token: String

                private init(token: String) {
                    self.token = token
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// 접근 제어자 설정이 있어도 파라미터 타입을 만들 수 없는 저장 프로퍼티는 진단합니다.
    func testStoredPropertiesModePrivateAccessRequiresExplicitTypeAnnotation() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(.private)
            struct Credentials {
                var token
            }
            """,
            expandedSource: """
            struct Credentials {
                var token
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: explicitTypeAnnotationErrorMessage,
                    line: 3,
                    column: 9
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// `firstLabel: .omitted`는 생성 initializer의 첫 번째 외부 label만 `_`로 렌더링합니다.
    func testStoredPropertiesModeOmitsOnlyFirstExternalLabelWhenRenderingInitializer() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(defaults: .parameters, firstLabel: .omitted)
            struct Box<Value> {
                let value: Value
                var isPinned: Bool = false
            }
            """,
            expandedSource: """
            struct Box<Value> {
                let value: Value
                var isPinned: Bool = false

                init(_ value: Value, isPinned: Bool = false) {
                    self.value = value
                    self.isPinned = isPinned
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// 첫 label 생략 설정이 있어도 파라미터 타입을 만들 수 없는 저장 프로퍼티는 진단합니다.
    func testStoredPropertiesModeOmittedFirstLabelRequiresExplicitTypeAnnotation() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(firstLabel: .omitted)
            struct Box {
                var value
            }
            """,
            expandedSource: """
            struct Box {
                var value
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: explicitTypeAnnotationErrorMessage,
                    line: 3,
                    column: 9
                )
            ],
            macros: makeTestMacros()
        )
    }
}
#endif
