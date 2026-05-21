import XCTest

#if canImport(StoredPropertyInitMacros)
import StoredPropertyInitMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

/// `@PropertyInit` 매크로의 선언 적용 가능 여부를 검증하는 테스트입니다.
final class PropertyInitDeclarationTests: XCTestCase {
    /// `struct` 선언에는 매크로를 적용할 수 있음을 검증합니다.
    func testStoredPropertyInitAllowsStruct() throws {
        assertMacroExpansion(
            """
            @PropertyInit
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
            @PropertyInit
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
            @PropertyInit
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
            @PropertyInit
            class ViewModel { }
            """,
            expandedSource: """
            class ViewModel { }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@PropertyInit requires classes to be final.",
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
            @PropertyInit
            enum FeatureFlag { }
            """,
            expandedSource: """
            enum FeatureFlag { }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@PropertyInit can only be applied to a struct, final class, or actor.",
                    line: 1,
                    column: 1
                )
            ],
            macros: makeTestMacros()
        )
    }
}

/// 매크로 expansion 테스트에서 사용할 매크로 이름 매핑을 생성합니다.
private func makeTestMacros() -> [String: Macro.Type] {
    [
        "PropertyInit": StoredPropertyInitMacro.self
    ]
}
#endif
