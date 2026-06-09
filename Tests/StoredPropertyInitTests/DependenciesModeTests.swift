import XCTest

#if canImport(StoredPropertyInitMacros)
import SwiftSyntaxMacrosTestSupport

/// `mode: .dependencies`의 initializer 파라미터 선택 규칙을 검증하는 테스트입니다.
final class DependenciesModeTests: XCTestCase {
    /// 의존성 모드에서는 초기값이 없는 저장 `let` 프로퍼티를 initializer 파라미터에 포함합니다.
    func testDependenciesModeIncludesUninitializedLetProperties() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(.public, mode: .dependencies)
            public final class FetchTodosUseCaseImpl {
                private let repository: TodoRepository
                private let analytics: AnalyticsClient
            }
            """,
            expandedSource: """
            public final class FetchTodosUseCaseImpl {
                private let repository: TodoRepository
                private let analytics: AnalyticsClient

                public init(repository: TodoRepository, analytics: AnalyticsClient) {
                    self.repository = repository
                    self.analytics = analytics
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// 의존성 모드에서는 모든 `var` 프로퍼티를 initializer 파라미터에서 제외합니다.
    func testDependenciesModeExcludesVarProperties() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(mode: .dependencies)
            struct Feature {
                let repository: Repository
                var cache: [String: Todo]
                var isEnabled: Bool = true
            }
            """,
            expandedSource: """
            struct Feature {
                let repository: Repository
                var cache: [String: Todo]
                var isEnabled: Bool = true

                init(repository: Repository) {
                    self.repository = repository
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// `defaults: .parameters`를 명시해도 의존성 모드에서는 초기값이 있는 `let`을 제외합니다.
    func testDependenciesModeParametersExcludesInitializedLetProperties() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(mode: .dependencies, defaults: .parameters)
            struct Feature {
                let repository: Repository
                let logger: Logger = .live
            }
            """,
            expandedSource: """
            struct Feature {
                let repository: Repository
                let logger: Logger = .live

                init(repository: Repository) {
                    self.repository = repository
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// `@WrappedInit(type:)`로 포함된 property-wrapper 프로퍼티도 의존성 모드에서는 제외합니다.
    func testDependenciesModeExcludesWrappedInitProperties() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(mode: .dependencies)
            struct ToggleFeature {
                let repository: Repository
                @WrappedInit(type: Binding<Bool>.self)
                @Binding var isOn: Bool
            }
            """,
            expandedSource: """
            struct ToggleFeature {
                let repository: Repository
                @Binding var isOn: Bool

                init(repository: Repository) {
                    self.repository = repository
                }
            }
            """,
            macros: makeTestMacros()
        )
    }

    /// 의존성 모드에서 선택할 파라미터가 없더라도 저장 프로퍼티가 있으면 empty initializer를 생성합니다.
    func testDependenciesModeGeneratesEmptyInitializerWhenAllPropertiesAreOmitted() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(mode: .dependencies)
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

    /// 같은 파라미터 레이블과 타입을 가진 initializer가 이미 있으면 중복 생성하지 않습니다.
    func testDependenciesModeSkipsInitializerWhenMatchingInitializerExists() throws {
        assertMacroExpansion(
            """
            @StoredPropertyInit(mode: .dependencies)
            struct Feature {
                let repository: Repository

                init(repository: Repository) {
                    self.repository = repository
                }
            }
            """,
            expandedSource: """
            struct Feature {
                let repository: Repository

                init(repository: Repository) {
                    self.repository = repository
                }
            }
            """,
            macros: makeTestMacros()
        )
    }
}
#endif
