import SwiftDiagnostics

/// `@StoredPropertyInit` 매크로가 사용하는 진단 메시지 목록입니다.
enum StoredPropertyInitDiagnosticMessage: DiagnosticMessage {
    /// `class` 선언에는 `final`이 필요하다는 에러입니다.
    case requiresFinalClass

    /// 지원하지 않는 선언 종류에 적용되었음을 나타내는 에러입니다.
    case unsupportedDeclaration

    /// 프로퍼티 래퍼 사용 프로퍼티를 건너뛴다는 note입니다.
    case skippedPropertyWrapper(name: String)

    /// 지원하지 않는 저장 프로퍼티 형태를 건너뛴다는 note입니다.
    case skippedStoredProperty(name: String?)

    /// 사용자에게 표시할 진단 메시지 본문입니다.
    var message: String {
        switch self {
        case .requiresFinalClass:
            return "@StoredPropertyInit requires classes to be final."
        case .unsupportedDeclaration:
            return "@StoredPropertyInit can only be applied to a struct, final class, or actor."
        case let .skippedPropertyWrapper(name):
            return "StoredPropertyInit skipped property wrapper property '\(name)'."
        case let .skippedStoredProperty(name):
            guard let name else {
                return "StoredPropertyInit skipped a computed, static, lazy, or multi-binding property."
            }

            return "StoredPropertyInit skipped computed, static, lazy, or multi-binding property '\(name)'."
        }
    }

    /// 진단 메시지의 고유 식별자입니다.
    var diagnosticID: MessageID {
        MessageID(domain: "StoredPropertyInitMacro", id: id)
    }

    /// 진단 메시지의 고정 식별자입니다.
    var id: String {
        switch self {
        case .requiresFinalClass:
            "requiresFinalClass"
        case .unsupportedDeclaration:
            "unsupportedDeclaration"
        case .skippedPropertyWrapper:
            "skippedPropertyWrapper"
        case .skippedStoredProperty:
            "skippedStoredProperty"
        }
    }

    /// 진단의 심각도입니다.
    var severity: DiagnosticSeverity {
        switch self {
        case .requiresFinalClass, .unsupportedDeclaration:
            .error
        case .skippedPropertyWrapper, .skippedStoredProperty:
            .note
        }
    }
}
