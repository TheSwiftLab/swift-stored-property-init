import SwiftDiagnostics

/// `@StoredPropertyInit` 매크로가 사용하는 진단 메시지 목록입니다.
enum StoredPropertyInitDiagnosticMessage: String, DiagnosticMessage {
    /// `class` 선언에는 `final`이 필요하다는 에러입니다.
    case requiresFinalClass = "@StoredPropertyInit requires classes to be final."

    /// 지원하지 않는 선언 종류에 적용되었음을 나타내는 에러입니다.
    case unsupportedDeclaration = "@StoredPropertyInit can only be applied to a struct, final class, or actor."

    /// 사용자에게 표시할 진단 메시지 본문입니다.
    var message: String {
        rawValue
    }

    /// 진단 메시지의 고유 식별자입니다.
    var diagnosticID: MessageID {
        MessageID(domain: "StoredPropertyInitMacro", id: "\(self)")
    }

    /// 현재 매크로 진단은 모두 에러로 처리합니다.
    var severity: DiagnosticSeverity {
        .error
    }
}
