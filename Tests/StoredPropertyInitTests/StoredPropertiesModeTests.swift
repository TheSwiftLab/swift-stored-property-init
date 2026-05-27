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

    /// `mode: .storedProperties`와 `defaults: .omitted`를 함께 명시하면 기본값이 있는 프로퍼티를 제외합니다.
    func testExplicitStoredPropertiesModeOmittedExcludesInitializedProperties() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(mode: .storedProperties, defaults: .omitted)
            struct Article {
                let id: String
                var title: String
                var isPinned: Bool = false
                var commentCount: Int = 0
            }
            """,
            expandedSource: """
            struct Article {
                let id: String
                var title: String
                var isPinned: Bool = false
                var commentCount: Int = 0

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

    /// `let` 저장 프로퍼티가 선언부 기본값을 가지면 initializer에서 다시 대입할 수 없으므로 제외합니다.
    func testStoredPropertiesModeParametersExcludesInitializedLetProperties() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(defaults: .parameters)
            struct Draft {
                let id: String = "draft"
                var title: String
                var isPinned: Bool = false
            }
            """,
            expandedSource: """
            struct Draft {
                let id: String = "draft"
                var title: String
                var isPinned: Bool = false

                init(title: String, isPinned: Bool = false) {
                    self.title = title
                    self.isPinned = isPinned
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// `mode: .storedProperties`와 `defaults: .parameters`를 함께 명시하면 기본값을 기본 인자로 보존합니다.
    func testExplicitStoredPropertiesModeParametersIncludesInitializedPropertiesWithDefaultArguments() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(mode: .storedProperties, defaults: .parameters)
            struct SearchOptions {
                var query: String
                var page: Int = 1
                var includeArchived: Bool = false
            }
            """,
            expandedSource: """
            struct SearchOptions {
                var query: String
                var page: Int = 1
                var includeArchived: Bool = false

                init(query: String, page: Int = 1, includeArchived: Bool = false) {
                    self.query = query
                    self.page = page
                    self.includeArchived = includeArchived
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
