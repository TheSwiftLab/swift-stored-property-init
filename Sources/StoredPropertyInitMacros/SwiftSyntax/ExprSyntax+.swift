import SwiftSyntax

extension ExprSyntax {
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
