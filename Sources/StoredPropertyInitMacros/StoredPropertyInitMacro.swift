import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// `@StoredPropertyInit`의 매크로 구현입니다.
///
/// 현재 구현 범위는 매크로를 적용할 수 있는 선언 대상을 검증하는 것까지입니다.
public struct StoredPropertyInitMacro: MemberMacro {
    /// 매크로가 선언에 제공할 멤버를 확장합니다.
    ///
    /// 현재 단계에서는 initializer를 실제로 생성하지 않으므로 항상 빈 배열을 반환합니다.
    /// 대신 선언 대상이 유효한지 검사하고, 유효하지 않으면 진단을 추가합니다.
    ///
    /// - Parameters:
    ///   - node: 선언에 붙은 매크로 attribute 구문입니다.
    ///   - declaration: 매크로가 적용된 원본 선언입니다.
    ///   - protocols: 확장 과정에서 함께 고려할 프로토콜 목록입니다.
    ///   - context: 진단 보고와 코드 생성을 수행하는 매크로 확장 컨텍스트입니다.
    /// - Returns: 선언에 추가할 멤버 목록입니다. 현재 구현에서는 항상 빈 배열입니다.
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if isSupportedDeclaration(declaration) {
            return []
        }

        let diagnosticMessage = diagnosticMessage(for: declaration)
        context.diagnose(Diagnostic(node: Syntax(declaration), message: diagnosticMessage))

        return []
    }
}

private extension StoredPropertyInitMacro {
    /// 주어진 선언이 `@StoredPropertyInit`의 지원 대상인지 판별합니다.
    ///
    /// - Parameter declaration: 매크로가 적용된 선언입니다.
    /// - Returns: `struct`, `final class`, `actor`면 `true`, 아니면 `false`입니다.
    static func isSupportedDeclaration(_ declaration: some DeclGroupSyntax) -> Bool {
        if declaration.is(StructDeclSyntax.self) || declaration.is(ActorDeclSyntax.self) {
            return true
        }

        guard let classDeclaration = declaration.as(ClassDeclSyntax.self) else {
            return false
        }

        return classDeclaration.modifiers.contains(where: \.isFinalModifier)
    }

    /// 지원되지 않는 선언에 대해 표시할 진단 메시지를 선택합니다.
    ///
    /// - Parameter declaration: 진단 대상 선언입니다.
    /// - Returns: 선언 종류에 맞는 매크로 진단 메시지입니다.
    static func diagnosticMessage(
        for declaration: some DeclGroupSyntax
    ) -> StoredPropertyInitDiagnosticMessage {
        guard declaration.is(ClassDeclSyntax.self) else {
            return .unsupportedDeclaration
        }

        return .requiresFinalClass
    }
}

private extension DeclModifierSyntax {
    /// 현재 modifier가 `final`인지 나타냅니다.
    ///
    /// 이 값은 `class` 선언이 `@StoredPropertyInit`의 지원 대상인지
    /// 판별할 때 사용합니다.
    var isFinalModifier: Bool {
        name.tokenKind == .keyword(.final)
    }
}

/// 매크로 구현 타입을 컴파일러에 등록하는 플러그인 진입점입니다.
@main
struct StoredPropertyInitPlugin: CompilerPlugin {
    /// 이 플러그인이 제공하는 매크로 타입 목록입니다.
    ///
    /// 컴파일러는 이 배열을 통해 현재 플러그인이 어떤 매크로 구현을
    /// 노출하는지 식별합니다.
    let providingMacros: [Macro.Type] = [
        StoredPropertyInitMacro.self
    ]
}
