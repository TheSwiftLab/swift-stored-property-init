import SwiftSyntax

extension AttributeListSyntax {
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
