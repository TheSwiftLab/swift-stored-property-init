import SwiftSyntax

extension VariableDeclSyntax {
    /// note 메시지에 사용할 저장 프로퍼티 이름입니다.
    var storedPropertyName: String? {
        guard bindings.count == 1 else {
            return nil
        }

        return bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }
}
