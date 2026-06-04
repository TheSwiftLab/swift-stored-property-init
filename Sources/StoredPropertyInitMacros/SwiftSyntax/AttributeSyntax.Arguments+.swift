import SwiftSyntax

extension AttributeSyntax.Arguments? {
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
