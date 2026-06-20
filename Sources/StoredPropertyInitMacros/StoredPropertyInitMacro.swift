import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@StoredPropertyInit`의 매크로 구현입니다.
///
/// 현재 구현 범위는 매크로 적용 대상 검증, initializer 파라미터 후보가 될
/// 저장 프로퍼티 수집, 그리고 모드별 파라미터 선택입니다.
public struct StoredPropertyInitMacro: MemberMacro {
    /// 매크로가 선언에 제공할 멤버를 확장합니다.
    ///
    /// 지원 선언에서 모드별 규칙에 따라 initializer 파라미터
    /// 후보가 있으면 initializer를 생성합니다. 지원하지 않는 선언이나 프로퍼티는 진단을 보고합니다.
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

            guard validateInitializedLetDefaultedParameters(
                storedProperties,
                configuration: configuration,
                in: context
            ) else {
                return []
            }

            let selectedProperties = selectStoredProperties(
                storedProperties,
                configuration: configuration
            )

            let shouldGenerateInitializer = !selectedProperties.isEmpty
                || !storedProperties.isEmpty

            guard shouldGenerateInitializer else {
                return []
            }

            guard validateSelectedStoredProperties(selectedProperties, in: context) else {
                return []
            }

            guard !hasConflictingInitializer(
                for: selectedProperties,
                configuration: configuration,
                in: declaration
            ) else {
                let diagnosticMessage = StoredPropertyInitDiagnosticMessage.duplicateInitializerSignature
                context.diagnose(Diagnostic(node: Syntax(node), message: diagnosticMessage))
                return []
            }

            guard validateOmittedDependencyProperties(
                storedProperties,
                selectedProperties: selectedProperties,
                configuration: configuration,
                in: context
            ) else {
                return []
            }

            return [renderInitializer(from: selectedProperties, configuration: configuration)]
        }

        context.diagnose(Diagnostic(node: Syntax(declaration), message: diagnosticMessage(for: declaration)))

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

        /// 선언부 기본값이 있는 non-wrapper `let` 저장 프로퍼티인지 나타냅니다.
        var isInitializedNonWrapperLet: Bool {
            isStoredAsLet && initializerClauseSyntax != nil && !isWrappedInitProperty
        }
    }

    /// initializer 중복 여부를 비교할 때 사용하는 시그니처입니다.
    struct InitializerSignature {
        let isAsync: Bool
        let parameters: [InitializerParameterSignature]

        /// Swift 호출 시그니처가 충돌하는지 비교합니다.
        func conflicts(with other: InitializerSignature) -> Bool {
            isAsync == other.isAsync
                && parameters.count == other.parameters.count
                && zip(parameters, other.parameters).allSatisfy { existing, generated in
                    existing.conflicts(with: generated)
                }
        }
    }

    /// initializer 중복 여부를 비교할 때 사용하는 파라미터 시그니처입니다.
    struct InitializerParameterSignature {
        let externalLabel: String
        let internalName: String
        let typeSource: String
        let isVariadic: Bool

        /// Swift 호출 시그니처가 충돌하는지 비교합니다.
        func conflicts(with other: InitializerParameterSignature) -> Bool {
            hasSameDeclaredShape(as: other) || hasSameCallShape(as: other)
        }

        /// 외부 label, 내부 이름, 타입까지 같은 선언 형태인지 비교합니다.
        func hasSameDeclaredShape(as other: InitializerParameterSignature) -> Bool {
            externalLabel == other.externalLabel
                && internalName == other.internalName
                && typeSource == other.typeSource
                && isVariadic == other.isVariadic
        }

        /// Swift overload 관점에서 같은 호출 형태인지 비교합니다.
        func hasSameCallShape(as other: InitializerParameterSignature) -> Bool {
            externalLabel == other.externalLabel
                && typeSource == other.typeSource
                && isVariadic == other.isVariadic
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
    enum InitAccess: String {
        case `private`
        case `fileprivate`
        case `internal`
        case `package`
        case `public`
        case `open`

        init?(optionName: String) {
            self.init(rawValue: optionName)
        }

        var sourcePrefix: String {
            switch self {
            case .internal:
                return ""
            case .open:
                return "public "
            case .private, .fileprivate, .package, .public:
                return "\(rawValue) "
            }
        }
    }

    /// initializer 생성 모드입니다.
    enum InitMode: String {
        case storedProperties
        case dependencies

        init?(optionName: String) {
            self.init(rawValue: optionName)
        }
    }

    /// 기본값이 있는 프로퍼티 처리 정책입니다.
    enum InitDefaults: String {
        case omitted
        case parameters

        init?(optionName: String) {
            self.init(rawValue: optionName)
        }
    }

    /// 첫 번째 파라미터 외부 레이블 정책입니다.
    enum InitFirstLabel: String {
        case named
        case omitted

        init?(optionName: String) {
            self.init(rawValue: optionName)
        }
    }

    /// 주어진 선언이 `@StoredPropertyInit`의 지원 대상인지 판별합니다.
    ///
    /// - Parameter declaration: 매크로가 적용된 선언입니다.
    /// - Returns: `struct`, inheritance clause가 없는 `final class`, `actor`면 `true`, 아니면 `false`입니다.
    static func isSupportedDeclaration(_ declaration: some DeclGroupSyntax) -> Bool {
        if declaration.is(StructDeclSyntax.self) || declaration.is(ActorDeclSyntax.self) {
            return true
        }

        guard let classDeclaration = declaration.as(ClassDeclSyntax.self) else {
            return false
        }

        return classDeclaration.modifiers.contains(where: \.isFinalModifier)
            && classDeclaration.inheritanceClause == nil
    }

    /// 지원되지 않는 선언에 대해 표시할 진단 메시지를 선택합니다.
    ///
    /// - Parameter declaration: 진단 대상 선언입니다.
    /// - Returns: 선언 종류에 맞는 매크로 진단 메시지입니다.
    static func diagnosticMessage(
        for declaration: some DeclGroupSyntax
    ) -> StoredPropertyInitDiagnosticMessage {
        guard let classDeclaration = declaration.as(ClassDeclSyntax.self) else {
            return .unsupportedDeclaration
        }

        guard classDeclaration.modifiers.contains(where: \.isFinalModifier) else {
            return .requiresFinalClass
        }

        return .unsupportedClassInheritanceClause
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
    /// - Parameters:
    ///   - storedProperties: 수집된 저장 프로퍼티 목록입니다.
    ///   - configuration: 매크로 attribute 설정입니다.
    /// - Returns: initializer 파라미터로 렌더링할 프로퍼티 목록입니다.
    static func selectStoredProperties(
        _ storedProperties: [StoredProperty],
        configuration: MacroConfiguration
    ) -> [StoredProperty] {
        switch configuration.mode {
        case .storedProperties:
            return storedProperties.filter { property in
                if property.isInitializedNonWrapperLet {
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
        case .dependencies:
            return storedProperties.filter { property in
                property.isStoredAsLet
                    && property.initializerClauseSyntax == nil
                    && !property.isWrappedInitProperty
            }
        }
    }

    /// `defaults: .parameters` 계약상 포함해야 하지만 Swift가 대입을 허용하지 않는
    /// initialized `let` 프로퍼티를 진단합니다.
    static func validateInitializedLetDefaultedParameters(
        _ storedProperties: [StoredProperty],
        configuration: MacroConfiguration,
        in context: some MacroExpansionContext
    ) -> Bool {
        guard configuration.mode == .storedProperties, configuration.defaults == .parameters else {
            return true
        }

        var isValid = true

        for property in storedProperties where property.isInitializedNonWrapperLet {
            let diagnosticMessage = StoredPropertyInitDiagnosticMessage
                .initializedLetDefaultedParameter(name: property.name.text)
            context.diagnose(Diagnostic(node: Syntax(property.name), message: diagnosticMessage))
            isValid = false
        }

        return isValid
    }

    /// 의존성 모드에서 initializer 본문이 초기화하지 않는 프로퍼티가 선언부에서 초기화 가능한지 검증합니다.
    static func validateOmittedDependencyProperties(
        _ storedProperties: [StoredProperty],
        selectedProperties: [StoredProperty],
        configuration: MacroConfiguration,
        in context: some MacroExpansionContext
    ) -> Bool {
        guard configuration.mode == .dependencies else {
            return true
        }

        let selectedNames = Set(selectedProperties.map { $0.name.text })
        var isValid = true

        for property in storedProperties
            where !selectedNames.contains(property.name.text) && property.initializerClauseSyntax == nil {
            let diagnosticMessage = StoredPropertyInitDiagnosticMessage
                .uninitializedOmittedDependencyProperty(name: property.name.text)
            context.diagnose(Diagnostic(node: Syntax(property.name), message: diagnosticMessage))
            isValid = false
        }

        return isValid
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

    /// 같은 호출 시그니처를 가진 initializer가 이미 선언되어 있는지 확인합니다.
    static func hasConflictingInitializer(
        for storedProperties: [StoredProperty],
        configuration: MacroConfiguration,
        in declaration: some DeclGroupSyntax
    ) -> Bool {
        let generatedSignature = generatedInitializerSignature(
            for: storedProperties,
            configuration: configuration
        )

        return declaration.memberBlock.members.contains { member in
            guard let initializer = member.decl.as(InitializerDeclSyntax.self) else {
                return false
            }

            return initializerSignature(from: initializer).conflicts(with: generatedSignature)
        }
    }

    /// 기존 initializer 선언의 파라미터 시그니처를 반환합니다.
    static func initializerSignature(
        from initializer: InitializerDeclSyntax
    ) -> InitializerSignature {
        let parameters = initializer.signature.parameterClause.parameters.map { parameter in
            InitializerParameterSignature(
                externalLabel: parameter.firstName.text,
                internalName: parameter.secondName?.text ?? parameter.firstName.text,
                typeSource: parameter.type.trimmedDescription,
                isVariadic: parameter.ellipsis != nil
            )
        }

        return InitializerSignature(
            isAsync: initializer.signature.effectSpecifiers?.asyncSpecifier != nil,
            parameters: parameters
        )
    }

    /// 생성할 initializer의 파라미터 시그니처를 반환합니다.
    static func generatedInitializerSignature(
        for storedProperties: [StoredProperty],
        configuration: MacroConfiguration
    ) -> InitializerSignature {
        let parameters = storedProperties.enumerated().map { index, property in
            let externalLabel = index == 0 && configuration.firstLabel == .omitted
                ? "_"
                : property.name.text

            return InitializerParameterSignature(
                externalLabel: externalLabel,
                internalName: property.name.text,
                typeSource: parameterTypeSource(for: property),
                isVariadic: false
            )
        }

        return InitializerSignature(isAsync: false, parameters: parameters)
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
        guard !storedProperties.isEmpty else {
            return DeclSyntax(
                stringLiteral: """
                \(configuration.access.sourcePrefix)init() {
                }
                """
            )
        }

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
