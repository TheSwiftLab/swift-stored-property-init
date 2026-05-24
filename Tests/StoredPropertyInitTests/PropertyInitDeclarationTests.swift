import XCTest

#if canImport(StoredPropertyInitMacros)
import StoredPropertyInitMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

/// `@StoredPropertyInit` 매크로의 선언 적용 가능 여부를 검증하는 테스트입니다.
final class PropertyInitDeclarationTests: XCTestCase {
    /// `struct` 선언에는 매크로를 적용할 수 있음을 검증합니다.
    func testStoredPropertyInitAllowsStruct() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct User { }
            """,
            expandedSource: """
            struct User { }
            """,
            macros: makeTestMacros()
        )
    }

    /// `final class` 선언에는 매크로를 적용할 수 있음을 검증합니다.
    func testStoredPropertyInitAllowsFinalClass() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            final class Service { }
            """,
            expandedSource: """
            final class Service { }
            """,
            macros: makeTestMacros()
        )
    }

    /// `actor` 선언에는 매크로를 적용할 수 있음을 검증합니다.
    func testStoredPropertyInitAllowsActor() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            actor Store { }
            """,
            expandedSource: """
            actor Store { }
            """,
            macros: makeTestMacros()
        )
    }

    /// `final`이 아닌 `class` 선언은 지원하지 않음을 검증합니다.
    func testStoredPropertyInitRejectsNonFinalClass() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            class ViewModel { }
            """,
            expandedSource: """
            class ViewModel { }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StoredPropertyInit requires classes to be final.",
                    line: 1,
                    column: 1
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// 지원하지 않는 선언 종류에 매크로를 적용하면 에러가 발생함을 검증합니다.
    func testStoredPropertyInitRejectsUnsupportedDeclaration() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            enum FeatureFlag { }
            """,
            expandedSource: """
            enum FeatureFlag { }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@StoredPropertyInit can only be applied to a struct, final class, or actor.",
                    line: 1,
                    column: 1
                )
            ],
            macros: makeTestMacros()
        )
    }
}
#endif
