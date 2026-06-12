import XCTest

#if canImport(StoredPropertyInitMacros)
import SwiftDiagnostics
import SwiftSyntaxMacrosTestSupport

/// `mode: .storedProperties`의 중복 initializer 감지 규칙을 검증하는 테스트입니다.
final class StoredPropertiesDedupeTests: XCTestCase {
    /// 같은 파라미터 레이블과 타입을 가진 initializer가 이미 있으면 중복 생성하지 않습니다.
    func testStoredPropertiesModeSkipsInitializerWhenMatchingInitializerExists() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Todo {
                let id: String
                var title: String

                init(id: String, title: String) {
                    self.id = id
                    self.title = title
                }
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String
                var title: String

                init(id: String, title: String) {
                    self.id = id
                    self.title = title
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: duplicateInitializerWarningMessage,
                    line: 1,
                    column: 1,
                    severity: .warning
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// 첫 번째 파라미터 레이블 생략 설정도 기존 initializer 시그니처와 비교합니다.
    func testStoredPropertiesModeSkipsInitializerWhenMatchingUnlabeledInitializerExists() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(firstLabel: .omitted)
            struct Todo {
                let id: String

                init(_ id: String) {
                    self.id = id
                }
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String

                init(_ id: String) {
                    self.id = id
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: duplicateInitializerWarningMessage,
                    line: 1,
                    column: 1,
                    severity: .warning
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// 첫 번째 label 생략 설정에서도 내부 파라미터 이름만 다르면 중복으로 간주합니다.
    func testStoredPropertiesModeSkipsUnlabeledInitializerWhenOnlyInternalParameterNameDiffers() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(firstLabel: .omitted)
            struct Todo {
                let id: String

                init(_ identifier: String) {
                    self.id = identifier
                }
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String

                init(_ identifier: String) {
                    self.id = identifier
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: duplicateInitializerWarningMessage,
                    line: 1,
                    column: 1,
                    severity: .warning
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// 내부 파라미터 이름만 달라도 Swift 호출 시그니처가 같으면 중복으로 간주합니다.
    func testStoredPropertiesModeSkipsInitializerWhenOnlyInternalParameterNameDiffers() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Todo {
                let id: String

                init(id identifier: String) {
                    self.id = identifier
                }
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String

                init(id identifier: String) {
                    self.id = identifier
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: duplicateInitializerWarningMessage,
                    line: 1,
                    column: 1,
                    severity: .warning
                )
            ],
            macros: makeTestMacros()
        )
    }

    /// 기존 async initializer만 있으면 sync initializer 생성을 허용합니다.
    func testStoredPropertiesModeAllowsInitializerWhenOnlyMatchingAsyncInitializerExists() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Todo {
                let id: String

                init(id: String) async {
                    self.id = id
                }
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String

                init(id: String) async {
                    self.id = id
                }

                init(id: String) {
                    self.id = id
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// 외부 파라미터 label이 다르면 기존 initializer가 있어도 요청된 initializer를 생성합니다.
    func testStoredPropertiesModeAllowsInitializerWhenExternalLabelDiffers() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Todo {
                let id: String

                init(_ id: String) {
                    self.id = id
                }
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String

                init(_ id: String) {
                    self.id = id
                }

                init(id: String) {
                    self.id = id
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// 파라미터 타입이 다르면 기존 initializer가 있어도 요청된 initializer를 생성합니다.
    func testStoredPropertiesModeAllowsInitializerWhenParameterTypeDiffers() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Todo {
                let id: String

                init(id: UUID) {
                    self.id = id.uuidString
                }
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String

                init(id: UUID) {
                    self.id = id.uuidString
                }

                init(id: String) {
                    self.id = id
                }
            }
            """,
            macros: makeTestMacros()
        )
    }
}

final class StoredPropertiesTypeSpellingTests: XCTestCase {
    /// 중복 감지는 타입 의미 해석 없이 type source 문자열이 같은 경우까지만 지원합니다.
    func testStoredPropertiesModeDocumentsSwiftQualifiedTypeSpellingLimitation() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Todo {
                let id: String

                init(id: Swift.String) {
                    self.id = id
                }
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String

                init(id: Swift.String) {
                    self.id = id
                }

                init(id: String) {
                    self.id = id
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// 중복 감지는 collection sugar와 generic spelling을 같은 타입으로 해석하지 않습니다.
    func testStoredPropertiesModeDocumentsCollectionTypeSpellingLimitation() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct TodoList {
                let ids: [String]

                init(ids: Array<String>) {
                    self.ids = ids
                }
            }
            """,
            expandedSource: """
            struct TodoList {
                let ids: [String]

                init(ids: Array<String>) {
                    self.ids = ids
                }

                init(ids: [String]) {
                    self.ids = ids
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// 중복 감지는 같은 선언 내부의 typealias와 원본 타입도 의미적으로 비교하지 않습니다.
    func testStoredPropertiesModeDocumentsLocalTypeAliasLimitation() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Todo {
                typealias ID = String

                let id: String

                init(id: ID) {
                    self.id = id
                }
            }
            """,
            expandedSource: """
            struct Todo {
                typealias ID = String

                let id: String

                init(id: ID) {
                    self.id = id
                }

                init(id: String) {
                    self.id = id
                }
            }
            """,
            macros: makeTestMacros()
        )
    }
}

final class StoredPropertiesDedupeShapeTests: XCTestCase {
    /// 파라미터 개수가 다르면 기존 initializer가 있어도 요청된 initializer를 생성합니다.
    func testStoredPropertiesModeAllowsInitializerWhenParameterCountDiffers() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit
            struct Todo {
                let id: String
                var title: String

                init(id: String, title: String, isPinned: Bool) {
                    self.id = id
                    self.title = isPinned ? "[Pinned] \\(title)" : title
                }
            }
            """,
            expandedSource: """
            struct Todo {
                let id: String
                var title: String

                init(id: String, title: String, isPinned: Bool) {
                    self.id = id
                    self.title = isPinned ? "[Pinned] \\(title)" : title
                }

                init(id: String, title: String) {
                    self.id = id
                    self.title = title
                }
            }
            """,
            macros: makeTestMacros()
        )
    }
}
#endif
