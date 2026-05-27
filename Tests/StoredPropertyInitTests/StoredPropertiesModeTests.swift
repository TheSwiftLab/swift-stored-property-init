import XCTest

#if canImport(StoredPropertyInitMacros)
import SwiftSyntaxMacrosTestSupport

/// `mode: .storedProperties`의 initializer 파라미터 선택 규칙을 검증하는 테스트입니다.
final class StoredPropertiesModeTests: XCTestCase {
    /// 기본 설정에서는 초기값이 없는 저장 프로퍼티만 initializer 파라미터에 포함합니다.
    func testStoredPropertiesModeOmitsInitializedPropertiesByDefault() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Todo {
                let id: String
                var title: String
                var tags: [String] = []
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String
                var title: String
                var tags: [String] = []

                init(id: String, title: String) {
                    self.id = id
                    self.title = title
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// `defaults: .omitted`를 명시해도 초기값이 있는 저장 프로퍼티는 제외합니다.
    func testStoredPropertiesModeOmittedExcludesInitializedProperties() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(defaults: .omitted)
            struct Todo {
                let id: String
                var title: String
                var tags: [String] = []
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String
                var title: String
                var tags: [String] = []

                init(id: String, title: String) {
                    self.id = id
                    self.title = title
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// `defaults: .parameters`에서는 초기값이 있는 저장 프로퍼티를 기본 인자와 함께 포함합니다.
    func testStoredPropertiesModeParametersIncludesInitializedPropertiesWithDefaultArguments() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(defaults: .parameters)
            struct TodoQuery {
                var keyword: String? = nil
                var pageSize: Int = 20
            }
            """,
            expandedSource: """
            struct TodoQuery {
                var keyword: String? = nil
                var pageSize: Int = 20

                init(keyword: String? = nil, pageSize: Int = 20) {
                    self.keyword = keyword
                    self.pageSize = pageSize
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// 선택된 파라미터와 assignment는 원본 선언 순서를 유지합니다.
    func testStoredPropertiesModePreservesDeclarationOrder() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(defaults: .parameters)
            struct Profile {
                var name: String
                var age: Int = 0
                let id: String
            }
            """,
            expandedSource: """
            struct Profile {
                var name: String
                var age: Int = 0
                let id: String

                init(name: String, age: Int = 0, id: String) {
                    self.name = name
                    self.age = age
                    self.id = id
                }
            }
            """,
            macros: makeTestMacros()
        )
    }
}
#endif
