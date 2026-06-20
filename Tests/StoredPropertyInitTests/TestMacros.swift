import XCTest

#if canImport(StoredPropertyInitMacros)
import StoredPropertyInitMacros
import SwiftSyntaxMacros

let duplicateInitializerWarningMessage =
    "StoredPropertyInit skipped generation because a matching initializer exists."

let explicitTypeAnnotationErrorMessage =
    "StoredPropertyInit requires an explicit type annotation for generated initializer parameters."

/// 매크로 expansion 테스트에서 사용할 매크로 이름 매핑을 생성합니다.
func makeTestMacros() -> [String: Macro.Type] {
    [
        "StoredPropertyInit": StoredPropertyInitMacro.self,
        "WrappedInit": WrappedInitMacro.self
    ]
}
#endif
