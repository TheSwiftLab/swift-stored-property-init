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
