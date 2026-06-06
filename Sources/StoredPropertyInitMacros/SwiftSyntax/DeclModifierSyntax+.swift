import SwiftSyntax

extension DeclModifierSyntax {
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
