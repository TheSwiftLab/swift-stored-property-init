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

public enum InitAccess {
    case `private`
    case `fileprivate`
    case `internal`
    case `package`
    case `public`
    case `open`
}

public enum InitMode {
    case storedProperties
    case dependencies
}

public enum InitDefaults {
    case omitted
    case parameters
}

public enum InitFirstLabel {
    case named
    case omitted
}
