import XCTest

#if canImport(StoredPropertyInitMacros)
import StoredPropertyInitMacros
import SwiftSyntaxMacros

let duplicateInitializerWarningMessage =
    "StoredPropertyInit skipped generation because a matching initializer exists."

/// 매크로 expansion 테스트에서 사용할 매크로 이름 매핑을 생성합니다.
func makeTestMacros() -> [String: Macro.Type] {
    [
        "StoredPropertyInit": StoredPropertyInitMacro.self,
        "WrappedInit": WrappedInitMacro.self
    ]
}
#endif
