import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@StoredPropertyInit`의 매크로 구현입니다.
///
/// 현재 구현 범위는 매크로 적용 대상 검증, initializer 파라미터 후보가 될
/// 저장 프로퍼티 수집, 그리고 `mode: .storedProperties`의 파라미터 선택입니다.
public struct StoredPropertyInitMacro: MemberMacro {
    /// 매크로가 선언에 제공할 멤버를 확장합니다.
    ///
    /// 지원 선언에서 `mode: .storedProperties` 규칙에 따라 선택된 프로퍼티가 있으면
    /// initializer를 생성합니다. 지원하지 않는 선언이나 프로퍼티는 진단을 보고합니다.
    ///
    /// - Parameters:
    ///   - node: 선언에 붙은 매크로 attribute 구문입니다.
    ///   - declaration: 매크로가 적용된 원본 선언입니다.
    ///   - protocols: 확장 과정에서 함께 고려할 프로토콜 목록입니다.
    ///   - context: 진단 보고와 코드 생성을 수행하는 매크로 확장 컨텍스트입니다.
    /// - Returns: 선언에 추가할 initializer 멤버 목록입니다.
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if isSupportedDeclaration(declaration) {
            let configuration = MacroConfiguration(from: node)

            guard validateConfiguration(configuration, from: node, in: context) else {
                return []
            }

            let storedProperties = collectStoredProperties(from: declaration, in: context)
            let selectedProperties = selectStoredProperties(
                storedProperties,
                configuration: configuration
            )

            guard !selectedProperties.isEmpty else {
                return []
            }

            guard validateSelectedStoredProperties(selectedProperties, in: context) else {
                return []
            }

            return [
                renderInitializer(
                    from: selectedProperties,
                    configuration: configuration
                )
            ]
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

        /// `@WrappedInit(type:)`로 포함된 property-wrapper 프로퍼티인지 나타냅니다.
        var isWrappedInitProperty: Bool {
            wrappedInitTypeExpression != nil
        }
    }

    /// `@StoredPropertyInit` attribute 인자로부터 읽은 설정입니다.
    struct MacroConfiguration {
        var access: InitAccess = .internal
        var mode: InitMode = .storedProperties
        var defaults: InitDefaults = .omitted
        var firstLabel: InitFirstLabel = .named

        init(from attribute: AttributeSyntax) {
            guard case let .argumentList(arguments) = attribute.arguments else {
                return
            }

            for argument in arguments {
                let optionName = argument.expression.optionName

                switch argument.label?.text {
                case nil:
                    access = InitAccess(optionName: optionName) ?? access
                case "mode":
                    mode = InitMode(optionName: optionName) ?? mode
                case "defaults":
                    defaults = InitDefaults(optionName: optionName) ?? defaults
                case "firstLabel":
                    firstLabel = InitFirstLabel(optionName: optionName) ?? firstLabel
                default:
                    continue
                }
            }
        }
    }

    /// initializer 접근 제어 설정입니다.
    enum InitAccess {
        case `private`
        case `fileprivate`
        case `internal`
        case `package`
        case `public`
        case `open`

        init?(optionName: String) {
            switch optionName {
            case "private":
                self = .private
            case "fileprivate":
                self = .fileprivate
            case "internal":
                self = .internal
            case "package":
                self = .package
            case "public":
                self = .public
            case "open":
                self = .open
            default:
                return nil
            }
        }

        var sourcePrefix: String {
            switch self {
            case .private:
                return "private "
            case .fileprivate:
                return "fileprivate "
            case .internal:
                return ""
            case .package:
                return "package "
            case .public:
                return "public "
            case .open:
                return "public "
            }
        }
    }

    /// initializer 생성 모드입니다.
    enum InitMode {
        case storedProperties
        case dependencies

        init?(optionName: String) {
            switch optionName {
            case "storedProperties":
                self = .storedProperties
            case "dependencies":
                self = .dependencies
            default:
                return nil
            }
        }
    }

    /// 기본값이 있는 프로퍼티 처리 정책입니다.
    enum InitDefaults {
        case omitted
        case parameters

        init?(optionName: String) {
            switch optionName {
            case "omitted":
                self = .omitted
            case "parameters":
                self = .parameters
            default:
                return nil
            }
        }
    }

    /// 첫 번째 파라미터 외부 레이블 정책입니다.
    enum InitFirstLabel {
        case named
        case omitted

        init?(optionName: String) {
            switch optionName {
            case "named":
                self = .named
            case "omitted":
                self = .omitted
            default:
                return nil
            }
        }
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

    /// 매크로 설정이 실제 initializer 생성에 사용할 수 있는 값인지 검증합니다.
    ///
    /// - Parameters:
    ///   - configuration: 매크로 attribute 설정입니다.
    ///   - attribute: 진단 위치로 사용할 매크로 attribute 구문입니다.
    ///   - context: 진단을 보고할 확장 컨텍스트입니다.
    /// - Returns: 설정이 유효하면 `true`, 아니면 `false`입니다.
    static func validateConfiguration(
        _ configuration: MacroConfiguration,
        from attribute: AttributeSyntax,
        in context: some MacroExpansionContext
    ) -> Bool {
        guard case .open = configuration.access else {
            return true
        }

        let diagnosticMessage = StoredPropertyInitDiagnosticMessage.unsupportedOpenAccess
        context.diagnose(Diagnostic(node: Syntax(attribute), message: diagnosticMessage))

        return false
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

    /// `mode`와 `defaults` 설정에 따라 initializer 파라미터가 될 프로퍼티를 선택합니다.
    ///
    /// 이번 단계에서는 `mode: .storedProperties` 규칙만 구현합니다.
    ///
    /// - Parameters:
    ///   - storedProperties: 수집된 저장 프로퍼티 목록입니다.
    ///   - configuration: 매크로 attribute 설정입니다.
    /// - Returns: initializer 파라미터로 렌더링할 프로퍼티 목록입니다.
    static func selectStoredProperties(
        _ storedProperties: [StoredProperty],
        configuration: MacroConfiguration
    ) -> [StoredProperty] {
        guard configuration.mode == .storedProperties else {
            return []
        }

        return storedProperties.filter { property in
            if property.isStoredAsLet, property.initializerClauseSyntax != nil, !property.isWrappedInitProperty {
                return false
            }

            guard !property.isWrappedInitProperty else {
                return true
            }

            guard property.initializerClauseSyntax != nil else {
                return true
            }

            return configuration.defaults == .parameters
        }
    }

    /// 선택된 프로퍼티들이 initializer 파라미터로 렌더링 가능한지 검증합니다.
    ///
    /// - Parameters:
    ///   - storedProperties: initializer 파라미터로 선택된 프로퍼티 목록입니다.
    ///   - context: 진단을 보고할 확장 컨텍스트입니다.
    /// - Returns: 모든 프로퍼티가 렌더링 가능하면 `true`, 아니면 `false`입니다.
    static func validateSelectedStoredProperties(
        _ storedProperties: [StoredProperty],
        in context: some MacroExpansionContext
    ) -> Bool {
        var isValid = true

        for property in storedProperties where !property.isWrappedInitProperty && property.typeSyntax == nil {
            let diagnosticMessage = StoredPropertyInitDiagnosticMessage.requiresExplicitTypeAnnotation
            context.diagnose(Diagnostic(node: Syntax(property.name), message: diagnosticMessage))
            isValid = false
        }

        return isValid
    }

    /// 선택된 저장 프로퍼티 목록을 initializer 선언으로 렌더링합니다.
    ///
    /// - Parameters:
    ///   - storedProperties: initializer 파라미터와 body assignment로 사용할 프로퍼티 목록입니다.
    ///   - configuration: 매크로 attribute 설정입니다.
    /// - Returns: 생성된 initializer 선언입니다.
    static func renderInitializer(
        from storedProperties: [StoredProperty],
        configuration: MacroConfiguration
    ) -> DeclSyntax {
        let parameters = storedProperties.enumerated()
            .map { index, property in
                renderParameter(
                    for: property,
                    at: index,
                    configuration: configuration
                )
            }
            .joined(separator: ", ")

        let assignments = storedProperties
            .map(renderAssignment)
            .map { "    \($0)" }
            .joined(separator: "\n")

        return DeclSyntax(
            stringLiteral: """
            \(configuration.access.sourcePrefix)init(\(parameters)) {
            \(assignments)
            }
            """
        )
    }

    /// 저장 프로퍼티 하나를 initializer 파라미터 문자열로 렌더링합니다.
    static func renderParameter(
        for property: StoredProperty,
        at index: Int,
        configuration: MacroConfiguration
    ) -> String {
        let name = property.name.text
        let labelPrefix = index == 0 && configuration.firstLabel == .omitted ? "_ " : ""
        let type = parameterTypeSource(for: property)
        let defaultArgument = defaultArgumentSource(
            for: property,
            configuration: configuration
        )

        return "\(labelPrefix)\(name): \(type)\(defaultArgument)"
    }

    /// 저장 프로퍼티 하나의 initializer 파라미터 타입 문자열을 반환합니다.
    static func parameterTypeSource(for property: StoredProperty) -> String {
        if let wrappedInitTypeExpression = property.wrappedInitTypeExpression {
            return wrappedInitTypeExpression.typeExpressionSource
        }

        return property.typeSyntax?.trimmedDescription ?? ""
    }

    /// 저장 프로퍼티 기본값을 initializer 기본 인자 문자열로 렌더링합니다.
    static func defaultArgumentSource(
        for property: StoredProperty,
        configuration: MacroConfiguration
    ) -> String {
        guard
            configuration.defaults == .parameters,
            !property.isWrappedInitProperty,
            let initializerClauseSyntax = property.initializerClauseSyntax
        else {
            return ""
        }

        return " = \(initializerClauseSyntax.value.trimmedDescription)"
    }

    /// 저장 프로퍼티 하나를 initializer body assignment 문자열로 렌더링합니다.
    static func renderAssignment(for property: StoredProperty) -> String {
        let name = property.name.text

        if property.isWrappedInitProperty {
            return "self._\(name) = \(name)"
        }

        return "self.\(name) = \(name)"
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
            diagnoseSkippedPropertyPattern(variableDeclaration, in: context)
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

    /// 이름으로 사용할 수 없는 패턴을 note로 보고합니다.
    ///
    /// - Parameters:
    ///   - variableDeclaration: 제외할 프로퍼티 선언입니다.
    ///   - context: 진단을 보고할 확장 컨텍스트입니다.
    static func diagnoseSkippedPropertyPattern(
        _ variableDeclaration: VariableDeclSyntax,
        in context: some MacroExpansionContext
    ) {
        let diagnosticMessage = StoredPropertyInitDiagnosticMessage.skippedNonIdentifierPattern

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

private extension ExprSyntax {
    /// `.public`, `InitDefaults.parameters` 같은 옵션 표현식의 마지막 이름입니다.
    var optionName: String {
        trimmedDescription
            .split(separator: ".")
            .last
            .map(String.init) ?? trimmedDescription
    }

    /// `@WrappedInit(type:)`의 `Wrapper.self` 표현식에서 타입 부분만 분리한 문자열입니다.
    var typeExpressionSource: String {
        let source = trimmedDescription

        guard source.hasSuffix(".self") else {
            return source
        }

        return String(source.dropLast(".self".count))
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
