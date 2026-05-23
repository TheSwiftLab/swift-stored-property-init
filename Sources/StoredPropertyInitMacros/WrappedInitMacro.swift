import SwiftSyntax
import SwiftSyntaxMacros

/// `@WrappedInit(type:)`의 매크로 구현입니다.
///
/// 이 매크로는 `@StoredPropertyInit`이 property wrapper 사용 프로퍼티를
/// 수집할 때 읽는 marker 역할만 수행합니다.
public struct WrappedInitMacro: PeerMacro {
    /// `@WrappedInit(type:)` 자체는 별도 선언을 생성하지 않습니다.
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}
