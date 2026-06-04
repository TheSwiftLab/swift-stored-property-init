import SwiftSyntax

extension AttributeSyntax {
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
