import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

public struct StoredPropertyInitMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

@main
struct StoredPropertyInitPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StoredPropertyInitMacro.self
    ]
}
