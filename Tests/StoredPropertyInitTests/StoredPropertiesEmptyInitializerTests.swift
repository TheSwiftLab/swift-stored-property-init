import XCTest

#if canImport(StoredPropertyInitMacros)
import SwiftSyntaxMacrosTestSupport

/// `mode: .storedProperties`에서 empty initializer 생성을 검증하는 테스트입니다.
final class StoredPropertiesEmptyInitializerTests: XCTestCase {
    /// 저장 프로퍼티 후보가 있지만 선택된 파라미터가 없으면 empty initializer를 생성합니다.
    func testStoredPropertiesModeGeneratesEmptyInitializerWhenAllPropertiesAreOmitted() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Options {
                var page = 1
            }
            """,
            expandedSource: """
            struct Options {
                var page = 1

                init() {
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// 명시적 저장 프로퍼티 모드에서도 선택된 파라미터가 없으면 empty initializer를 생성합니다.
    func testExplicitStoredPropertiesModeGeneratesEmptyInitializerWhenAllPropertiesAreOmitted() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(mode: .storedProperties)
            struct ViewState {
                var title: String = ""
            }
            """,
            expandedSource: """
            struct ViewState {
                var title: String = ""

                init() {
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// `defaults: .parameters`에서 initialized `let` 때문에 선택된 파라미터가 없으면 empty initializer를 생성하지 않습니다.
    func testStoredPropertiesModeParametersDoesNotGenerateEmptyInitializerForInitializedLetProperty() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(defaults: .parameters)
            struct Draft {
                let id: String = "draft"
            }
            """,
            expandedSource: """
            struct Draft {
                let id: String = "draft"
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "StoredPropertyInit cannot use initialized let property 'id' with defaults: .parameters.",
                    line: 3,
                    column: 9
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// 같은 empty initializer가 이미 있으면 중복 생성하지 않습니다.
    func testStoredPropertiesModeSkipsEmptyInitializerWhenMatchingInitializerExists() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Options {
                var page = 1

                init() {
                }
            }
            """,
            expandedSource: """
            struct Options {
                var page = 1

                init() {
                }
            }
            """,
            macros: makeTestMacros()
        )
    }
}
#endif
