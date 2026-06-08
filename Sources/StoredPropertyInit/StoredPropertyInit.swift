/// 저장 프로퍼티 기반 initializer 생성을 위한 attached member macro입니다.
///
/// 현재 단계에서는 선언 적용 가능 여부와 저장 프로퍼티 수집 규칙을 검증하고,
/// 모드별 파라미터 선택 규칙에 따라 initializer를 생성합니다.
///
/// 적용 가능한 선언:
/// - `struct`
/// - 부모 클래스나 프로토콜을 명시하지 않은 `final class`
/// - `actor`
///
/// 지원하지 않는 선언에 적용하면 매크로 진단을 발생시킵니다.
///
/// - Parameters:
///   - access: 생성될 initializer의 접근 수준입니다.
///   - mode: initializer 생성 모드입니다.
///   - defaults: 기본값을 파라미터에 반영할지 지정합니다. `mode: .dependencies`에서는 초기값이 있는 프로퍼티를 제외합니다.
///   - firstLabel: 첫 번째 파라미터 레이블 정책입니다.
@attached(member, names: named(init))
public macro StoredPropertyInit(
    _ access: InitAccess = .internal,
    mode: InitMode = .storedProperties,
    defaults: InitDefaults = .omitted,
    firstLabel: InitFirstLabel = .named
) = #externalMacro(
    module: "StoredPropertyInitMacros",
    type: "StoredPropertyInitMacro"
)

/// property wrapper 사용 프로퍼티를 initializer 파라미터에 명시적으로 포함합니다.
///
/// `@StoredPropertyInit`은 property wrapper 사용 프로퍼티를 기본적으로 제외합니다.
/// 이 매크로를 함께 사용하면 전달한 wrapper 타입을 이후 생성될 initializer
/// 파라미터 타입으로 사용합니다.
///
/// - Parameter type: initializer 파라미터에 사용할 property wrapper 타입입니다.
@attached(peer)
public macro WrappedInit<Wrapper>(
    type: Wrapper.Type
) = #externalMacro(
    module: "StoredPropertyInitMacros",
    type: "WrappedInitMacro"
)

/// 생성될 initializer의 접근 제어 수준입니다.
public enum InitAccess {
    case `private`
    case `fileprivate`
    case `internal`
    case `package`
    case `public`
    case `open`
}

/// initializer 생성 방식을 나타냅니다.
public enum InitMode {
    /// 저장 프로퍼티를 기준으로 initializer를 생성합니다.
    case storedProperties

    /// 의존성 주입 규칙을 기준으로 initializer를 생성합니다.
    case dependencies
}

/// 기본값이 있는 프로퍼티를 initializer 파라미터에 어떻게 반영할지 나타냅니다.
public enum InitDefaults {
    /// 기본값이 있는 항목을 파라미터에서 생략합니다.
    case omitted

    /// 기본값이 있는 항목도 파라미터에 포함합니다.
    case parameters
}

/// 첫 번째 파라미터 레이블 정책을 나타냅니다.
public enum InitFirstLabel {
    /// 첫 번째 파라미터 레이블을 유지합니다.
    case named

    /// 첫 번째 파라미터 레이블을 생략합니다.
    case omitted
}
