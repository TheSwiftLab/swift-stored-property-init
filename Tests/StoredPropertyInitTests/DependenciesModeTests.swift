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
}
#endif
