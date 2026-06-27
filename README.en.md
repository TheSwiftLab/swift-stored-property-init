# swift-stored-property-init

[한국어](README.md) | [English](README.en.md)

`StoredPropertyInit` is a Swift 6 macro that generates initializers from stored properties for models, DTOs, actors, and dependency-driven `final class` types.

Swift's built-in memberwise initializer is mainly useful inside `struct` declarations.

It has limits when you need explicit access control, `actor` or `final class` support, or property-wrapper initialization.

`StoredPropertyInit` generates initializers from stored properties while letting you explicitly control access level, generation mode, default-value handling, and property-wrapper inclusion.

## Installation

This package has not published a release tag yet.

Until the first release, add the development branch to your Swift package dependencies.

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/TheSwiftLab/swift-stored-property-init.git",
        branch: "develop"
    )
]
```

Then add `StoredPropertyInit` to the target that uses the macro:

```swift
.target(
    name: "AppFeature",
    dependencies: [
        .product(name: "StoredPropertyInit", package: "swift-stored-property-init")
    ]
)
```

After the first release tag is published, prefer a version requirement such as `from: "0.1.0"` instead of a branch requirement.

## Why StoredPropertyInit

Use `@StoredPropertyInit` when initializer generation should follow the same rule everywhere:

- public model or DTO initializers
- actor initializers
- dependency initializers for `final class` types
- default-value preservation through initializer default arguments
- explicit property-wrapper initialization through backing storage

The generated initializer body only assigns values to properties.

It does not generate any other behavior such as validation, logging, or additional setup.

## Public Model Initializer

```swift
import StoredPropertyInit

@StoredPropertyInit(.public)
public struct Point {
    public let x: Double
    public let y: Double
    public var label: String = ""
}
```

Generated initializer

```swift
public init(x: Double, y: Double) {
    self.x = x
    self.y = y
}
```

By default, `mode: .storedProperties` includes stored properties without initial values and omits stored properties that already have initial values.

## Dependency Initializer For Final Classes

```swift
import Observation
import StoredPropertyInit

@Observable
@StoredPropertyInit(.public, mode: .dependencies)
public final class Library {
    private let store: LibraryStore
    public private(set) var books: [Book] = []
}
```

Generated initializer

```swift
public init(store: LibraryStore) {
    self.store = store
}
```

`mode: .dependencies` includes every stored `let` property without an initial value.

It excludes `var` properties, property-wrapper properties, and properties with initial values.

## Default Value Policy

`defaults: .omitted` is the default policy. It omits non-wrapper stored properties that already have initial values.

```swift
@StoredPropertyInit(defaults: .omitted)
struct Size {
    let width: Double
    let height: Double
    var scale: Double = 1
}
```

Generated initializer

```swift
init(width: Double, height: Double) {
    self.width = width
    self.height = height
}
```

`defaults: .parameters` includes initialized non-wrapper `var` properties as parameters with default arguments copied from the property initializer.

```swift
@StoredPropertyInit(.public, defaults: .parameters)
public struct Rectangle {
    public var width: Double = 100
    public var height: Double = 100
}
```

Generated initializer

```swift
public init(width: Double = 100, height: Double = 100) {
    self.width = width
    self.height = height
}
```

An initialized non-wrapper `let` property cannot be included with `defaults: .parameters`.

Swift does not allow assigning to that property again inside the generated initializer.

## Property Wrapper Initialization

Property-wrapper properties are excluded by default.

In SwiftUI, a parent `View` usually owns state with `@State`, and a child `View` receives that state with `@Binding`.

```swift
import StoredPropertyInit
import SwiftUI

struct ContentView: View {
    @State private var isOn = false

    var body: some View {
        ToggleRow(isOn: $isOn)
    }
}

@StoredPropertyInit(.public)
public struct ToggleRow: View {
    @WrappedInit(type: Binding<Bool>.self)
    @Binding private var isOn: Bool

    public var body: some View {
        Toggle("Enabled", isOn: $isOn)
    }
}
```

Generated initializer

```swift
public init(isOn: Binding<Bool>) {
    self._isOn = isOn
}
```

Use `@WrappedInit(type:)` to explicitly include a property-wrapper property in `mode: .storedProperties`.

`@WrappedInit(type:)` removes `.self` from the supplied `type:` expression, renders that value as the initializer parameter type, and assigns the parameter through backing storage.

In this example, `ContentView` passes `$isOn` to the generated `public init(isOn:)`. `Binding<Bool>.self` produces a `Binding<Bool>` parameter, and the initializer assigns it with `self._isOn = isOn`.

## First Parameter Label

Use `firstLabel: .omitted` to omit only the first external parameter label.

```swift
@StoredPropertyInit(defaults: .parameters, firstLabel: .omitted)
struct Pair<Value> {
    let first: Value
    var second: Value? = nil
}
```

Generated initializer

```swift
init(_ first: Value, second: Value? = nil) {
    self.first = first
    self.second = second
}
```

## Supported Declarations

`@StoredPropertyInit` supports:

- `struct`
- `actor`
- `final class` without an inheritance clause

Supported initializer access levels:

- `private`
- `fileprivate`
- `internal`
- `package`
- `public`

`InitAccess.open` exists in the public API, but Swift initializers cannot be `open`. Use `.public` instead.

## Limitations

- Non-final classes are not supported.
- `final class` declarations with an inheritance clause or protocol conformance are not supported.
- `enum`, `protocol`, `extension`, and other declaration kinds are not supported.
- `static`, computed, `lazy`, multi-binding, and non-identifier-pattern properties are skipped.
- Property-wrapper properties are skipped unless they are annotated with `@WrappedInit(type:)`.
- Selected non-wrapper properties must have explicit type annotations.
- `mode: .dependencies` must include every stored `let` property without an initial value. If another uninitialized stored property would be omitted and make the generated initializer invalid, the macro reports an error.
- The macro does not generate throwing, failable, required, convenience, Codable, or inheritance-aware initializers.
- The macro does not provide property-level customization except `@WrappedInit(type:)`.

## Duplicate Initializer Detection Scope

`StoredPropertyInit` suppresses generation when an existing sync initializer has the same call shape as the initializer the macro would generate. Call-shape comparison uses the external label, internal name, type source text, variadic marker, and sync/async status.

Existing async initializers are not treated as duplicates of the generated sync initializer.

The macro does not resolve semantic type equivalence. For example, `String` and `Swift.String`, `[String]` and `Array<String>`, and `typealias ID = String` versus `String` are treated as different type spellings. In those cases, Swift may still report a duplicate initializer after macro expansion.

## Error Messages

Representative messages the macro can report:

- Error: `@StoredPropertyInit requires classes to be final.`
- Error: `@StoredPropertyInit does not support final classes with inheritance clauses.`
- Error: `@StoredPropertyInit can only be applied to a struct, final class, or actor.`
- Error: `StoredPropertyInit requires an explicit type annotation for generated initializer parameters.`
- Error: `StoredPropertyInit cannot use initialized let property 'id' with defaults: .parameters.`
- Error: `StoredPropertyInit cannot omit uninitialized property 'cache' in mode: .dependencies.`
- Error: `StoredPropertyInit cannot generate an open initializer. Use public access instead.`
- Warning: `StoredPropertyInit skipped generation because a matching initializer exists.`
- Note: `StoredPropertyInit skipped attribute-decorated property 'name'.`
- Note: `StoredPropertyInit skipped computed, static, lazy, or multi-binding property 'name'.`
- Note: `StoredPropertyInit skipped a property because its pattern is not a simple identifier.`

## License

`swift-stored-property-init` is available under the MIT license.

Copyright (c) 2026 TheSwiftLab
