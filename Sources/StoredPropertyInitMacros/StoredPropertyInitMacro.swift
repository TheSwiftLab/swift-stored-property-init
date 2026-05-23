import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// `@StoredPropertyInit`의 매크로 구현입니다.
///
/// 현재 구현 범위는 매크로 적용 대상 검증과 initializer 파라미터 후보가 될
/// 저장 프로퍼티 수집입니다.
public struct StoredPropertyInitMacro: MemberMacro {
    /// 매크로가 선언에 제공할 멤버를 확장합니다.
    ///
    /// 현재 단계에서는 initializer를 실제로 생성하지 않으므로 항상 빈 배열을 반환합니다.
    /// 대신 선언 대상과 저장 프로퍼티 수집 규칙을 검사하고, 필요하면 진단을 추가합니다.
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
            _ = collectStoredProperties(from: declaration, in: context)
            return []
        }

        let diagnosticMessage = diagnosticMessage(for: declaration)
        context.diagnose(Diagnostic(node: Syntax(declaration), message: diagnosticMessage))

        return []
    }
}

private extension StoredPropertyInitMacro {
    /// initializer 파라미터 후보가 될 저장 프로퍼티 정보입니다.
    struct StoredProperty {
        /// 프로퍼티 이름 토큰입니다.
        let name: TokenSyntax

        /// 프로퍼티 타입 구문입니다.
        let typeSyntax: TypeSyntax?

        /// 프로퍼티 기본값 구문입니다.
        let initializerClauseSyntax: InitializerClauseSyntax?

        /// 저장 프로퍼티가 `let`인지 나타냅니다.
        let isStoredAsLet: Bool

        /// `@WrappedInit(type:)`에 전달된 wrapper 타입 표현식입니다.
        let wrappedInitTypeExpression: ExprSyntax?
    }

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

    /// 선언 내부의 저장 프로퍼티를 소스 순서대로 수집합니다.
    ///
    /// 지원하지 않는 형태의 프로퍼티는 note를 남기고 제외합니다.
    ///
    /// - Parameters:
    ///   - declaration: 매크로가 적용된 선언입니다.
    ///   - context: 진단을 보고할 확장 컨텍스트입니다.
    /// - Returns: 이후 initializer 생성에 사용할 저장 프로퍼티 목록입니다.
    static func collectStoredProperties(
        from declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) -> [StoredProperty] {
        declaration.memberBlock.members.compactMap { member in
            guard let variableDeclaration = member.decl.as(VariableDeclSyntax.self) else {
                return nil
            }

            return makeStoredProperty(from: variableDeclaration, in: context)
        }
    }

    /// 단일 `VariableDeclSyntax`에서 저장 프로퍼티 하나를 추출합니다.
    ///
    /// 지원하지 않는 선언은 note를 보고하고 `nil`을 반환합니다.
    ///
    /// - Parameters:
    ///   - variableDeclaration: 분석할 프로퍼티 선언입니다.
    ///   - context: 진단을 보고할 확장 컨텍스트입니다.
    /// - Returns: 추출된 저장 프로퍼티 정보입니다.
    static func makeStoredProperty(
        from variableDeclaration: VariableDeclSyntax,
        in context: some MacroExpansionContext
    ) -> StoredProperty? {
        guard variableDeclaration.bindings.count == 1 else {
            diagnoseSkippedStoredProperty(variableDeclaration, in: context)
            return nil
        }

        guard !variableDeclaration.modifiers.contains(where: \.isStaticModifier) else {
            diagnoseSkippedStoredProperty(variableDeclaration, in: context)
            return nil
        }

        guard !variableDeclaration.modifiers.contains(where: \.isLazyModifier) else {
            diagnoseSkippedStoredProperty(variableDeclaration, in: context)
            return nil
        }

        let containsWrappedInitAttribute = variableDeclaration.attributes.containsWrappedInitAttribute
        let containsPropertyWrapperAttribute = variableDeclaration.attributes.containsPropertyWrapperAttribute

        guard !containsPropertyWrapperAttribute || containsWrappedInitAttribute else {
            diagnoseSkippedPropertyWrapper(variableDeclaration, in: context)
            return nil
        }

        let wrappedInitTypeExpression = variableDeclaration.attributes.wrappedInitTypeExpression
        guard let binding = variableDeclaration.bindings.first else {
            diagnoseSkippedStoredProperty(variableDeclaration, in: context)
            return nil
        }

        guard !binding.isComputedProperty else {
            diagnoseSkippedStoredProperty(variableDeclaration, in: context)
            return nil
        }

        guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            diagnoseSkippedStoredProperty(variableDeclaration, in: context)
            return nil
        }

        return StoredProperty(
            name: identifierPattern.identifier,
            typeSyntax: binding.typeAnnotation?.type,
            initializerClauseSyntax: binding.initializer,
            isStoredAsLet: variableDeclaration.bindingSpecifier.tokenKind == .keyword(.let),
            wrappedInitTypeExpression: wrappedInitTypeExpression
        )
    }

    /// 지원하지 않는 저장 프로퍼티 형태를 note로 보고합니다.
    ///
    /// - Parameters:
    ///   - variableDeclaration: 제외할 프로퍼티 선언입니다.
    ///   - context: 진단을 보고할 확장 컨텍스트입니다.
    static func diagnoseSkippedStoredProperty(
        _ variableDeclaration: VariableDeclSyntax,
        in context: some MacroExpansionContext
    ) {
        let propertyName = variableDeclaration.storedPropertyName
        let diagnosticMessage = StoredPropertyInitDiagnosticMessage.skippedStoredProperty(
            name: propertyName
        )

        context.diagnose(Diagnostic(node: Syntax(variableDeclaration), message: diagnosticMessage))
    }

    /// 프로퍼티 래퍼 사용 프로퍼티 제외를 note로 보고합니다.
    ///
    /// - Parameters:
    ///   - variableDeclaration: 제외할 프로퍼티 선언입니다.
    ///   - context: 진단을 보고할 확장 컨텍스트입니다.
    static func diagnoseSkippedPropertyWrapper(
        _ variableDeclaration: VariableDeclSyntax,
        in context: some MacroExpansionContext
    ) {
        let propertyName = variableDeclaration.storedPropertyName ?? "<unknown>"
        let diagnosticMessage = StoredPropertyInitDiagnosticMessage.skippedPropertyWrapper(
            name: propertyName
        )

        context.diagnose(Diagnostic(node: Syntax(variableDeclaration), message: diagnosticMessage))
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

    /// 현재 modifier가 `static`인지 나타냅니다.
    var isStaticModifier: Bool {
        name.tokenKind == .keyword(.static)
    }

    /// 현재 modifier가 `lazy`인지 나타냅니다.
    var isLazyModifier: Bool {
        name.tokenKind == .keyword(.lazy)
    }
}

private extension AttributeListSyntax {
    /// 프로퍼티 래퍼로 취급할 attribute가 포함되어 있는지 나타냅니다.
    var containsPropertyWrapperAttribute: Bool {
        contains { element in
            guard let attribute = element.as(AttributeSyntax.self) else {
                return false
            }

            guard !attribute.isWrappedInitAttribute else {
                return false
            }

            return attribute.arguments.isPropertyWrapperCompatible
        }
    }

    /// `@WrappedInit(type:)` marker가 포함되어 있는지 나타냅니다.
    var containsWrappedInitAttribute: Bool {
        contains { element in
            element.as(AttributeSyntax.self)?.isWrappedInitAttribute == true
        }
    }

    /// `@WrappedInit(type:)`에 전달된 wrapper 타입 표현식입니다.
    var wrappedInitTypeExpression: ExprSyntax? {
        compactMap { element in
            element.as(AttributeSyntax.self)
        }
        .first(where: \.isWrappedInitAttribute)?
        .wrappedInitTypeExpression
    }
}

private extension AttributeSyntax {
    /// 현재 attribute가 `@WrappedInit`인지 나타냅니다.
    var isWrappedInitAttribute: Bool {
        simpleName == "WrappedInit"
    }

    /// module qualifier를 제외한 attribute 이름입니다.
    var simpleName: String {
        String(attributeName.description.split(separator: ".").last ?? "")
    }

    /// `@WrappedInit(type:)`에 전달된 wrapper 타입 표현식입니다.
    var wrappedInitTypeExpression: ExprSyntax? {
        guard case let .argumentList(arguments) = arguments else {
            return nil
        }

        return arguments.first { argument in
            argument.label?.text == "type"
        }?.expression
    }
}

private extension AttributeSyntax.Arguments? {
    /// 현재 arguments 형태가 property wrapper attribute와 호환되는지 나타냅니다.
    var isPropertyWrapperCompatible: Bool {
        switch self {
        case nil, .argumentList:
            return true
        default:
            return false
        }
    }
}

private extension PatternBindingSyntax {
    /// 현재 binding이 computed property인지 나타냅니다.
    ///
    /// `willSet` / `didSet`만 있는 observed stored property는 제외하지 않습니다.
    var isComputedProperty: Bool {
        guard let accessorBlock else {
            return false
        }

        switch accessorBlock.accessors {
        case .getter:
            return true
        case let .accessors(accessors):
            return accessors.contains { accessor in
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.get), .keyword(.set), .keyword(._read), .keyword(._modify):
                    return true
                default:
                    return false
                }
            }
        }
    }
}

private extension VariableDeclSyntax {
    /// note 메시지에 사용할 저장 프로퍼티 이름입니다.
    var storedPropertyName: String? {
        guard bindings.count == 1 else {
            return nil
        }

        return bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
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
        StoredPropertyInitMacro.self,
        WrappedInitMacro.self
    ]
}
