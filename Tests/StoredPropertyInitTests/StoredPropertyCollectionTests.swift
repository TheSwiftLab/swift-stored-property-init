import XCTest

#if canImport(StoredPropertyInitMacros)
import SwiftDiagnostics
import SwiftSyntaxMacrosTestSupport

/// `@StoredPropertyInit` 매크로의 저장 프로퍼티 수집 규칙을 검증하는 테스트입니다.
final class StoredPropertyCollectionTests: XCTestCase {
    /// 저장 프로퍼티 observer는 제외하지 않음을 검증합니다.
    func testStoredPropertyInitAllowsObservedStoredProperty() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct User {
                var name: String {
                    didSet { }
                }
            }
            """,
            expandedSource: """
            struct User {
                var name: String {
                    didSet { }
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// `static` 프로퍼티는 저장 프로퍼티 수집 대상에서 제외함을 검증합니다.
    func testStoredPropertyInitSkipsStaticProperty() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct User {
                static let id: String
            }
            """,
            expandedSource: """
            struct User {
                static let id: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "StoredPropertyInit skipped computed, static, lazy, or multi-binding property 'id'.",
                    line: 3,
                    column: 5,
                    severity: .note
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// `lazy` 프로퍼티는 저장 프로퍼티 수집 대상에서 제외함을 검증합니다.
    func testStoredPropertyInitSkipsLazyProperty() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct User {
                lazy var name: String = ""
            }
            """,
            expandedSource: """
            struct User {
                lazy var name: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "StoredPropertyInit skipped computed, static, lazy, or multi-binding property 'name'.",
                    line: 3,
                    column: 5,
                    severity: .note
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// computed property는 저장 프로퍼티 수집 대상에서 제외함을 검증합니다.
    func testStoredPropertyInitSkipsComputedProperty() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct User {
                var fullName: String {
                    "user"
                }
            }
            """,
            expandedSource: """
            struct User {
                var fullName: String {
                    "user"
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "StoredPropertyInit skipped computed, static, lazy, or multi-binding property 'fullName'.",
                    line: 3,
                    column: 5,
                    severity: .note
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// 프로퍼티 래퍼 사용 프로퍼티는 저장 프로퍼티 수집 대상에서 제외함을 검증합니다.
    func testStoredPropertyInitSkipsPropertyWrapperProperty() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct User {
                @State var name: String = ""
            }
            """,
            expandedSource: """
            struct User {
                @State var name: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "StoredPropertyInit skipped property wrapper property 'name'.",
                    line: 3,
                    column: 5,
                    severity: .note
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// 멀티 바인딩 선언은 저장 프로퍼티 수집 대상에서 제외함을 검증합니다.
    func testStoredPropertyInitSkipsMultiBindingDeclaration() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct User {
                let id: String, name: String
            }
            """,
            expandedSource: """
            struct User {
                let id: String, name: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "StoredPropertyInit skipped a computed, static, lazy, or multi-binding property.",
                    line: 3,
                    column: 5,
                    severity: .note
                )
            ],
            macros: makeTestMacros()
        )
    }
}
#endif
