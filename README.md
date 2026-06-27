# swift-stored-property-init

StoredPropertyInit is a Swift 6 macro that generates initializers from stored properties for models, DTOs, actors, and dependency-driven final classes.

Swift already provides a memberwise initializer for many structs. `StoredPropertyInit` is for cases where the generated initializer needs to be explicit, access-controlled, available on supported non-struct declarations, or shaped by a small set of repeatable rules.

## Installation

This package has not published a release tag yet. Until the first release, add the development branch to your Swift package dependencies:

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

The generated initializer body contains only direct assignments. It does not add validation, logging, setup calls, subscriptions, tasks, or dependency-container registration.

## Public Model Initializer

```swift
import StoredPropertyInit

@StoredPropertyInit(.public)
public struct Todo {
    public let id: String
    public var title: String
    public var tags: [String] = []
}
```

Generated initializer:

```swift
public init(id: String, title: String) {
    self.id = id
    self.title = title
}
```

By default, `mode: .storedProperties` includes stored properties without initial values and omits stored properties that already have initial values.

## Dependency Initializer For Final Classes

```swift
import StoredPropertyInit

@StoredPropertyInit(.public, mode: .dependencies)
public final class FetchTodosUseCaseImpl {
    private let repository: TodoRepository
    private let analytics: AnalyticsClient
    private var cache: [String: Todo] = [:]
}
```

Generated initializer:

```swift
public init(repository: TodoRepository, analytics: AnalyticsClient) {
    self.repository = repository
    self.analytics = analytics
}
```

`mode: .dependencies` includes every stored `let` property without an initial value. It excludes `var` properties, property-wrapper properties, and properties with initial values.

## Default Value Policy

`defaults: .omitted` is the default policy. It omits non-wrapper stored properties that already have initial values.

```swift
@StoredPropertyInit(defaults: .omitted)
struct Article {
    let id: String
    var title: String
    var isPinned: Bool = false
}
```

Generated initializer:

```swift
init(id: String, title: String) {
    self.id = id
    self.title = title
}
```

`defaults: .parameters` includes initialized non-wrapper `var` properties as parameters with default arguments copied from the property initializer.

```swift
@StoredPropertyInit(defaults: .parameters)
struct TodoQuery {
    var keyword: String? = nil
    var pageSize: Int = 20
}
```

Generated initializer:

```swift
init(keyword: String? = nil, pageSize: Int = 20) {
    self.keyword = keyword
    self.pageSize = pageSize
}
```

An initialized non-wrapper `let` property cannot be included with `defaults: .parameters`, because Swift does not allow assigning to that property again in the generated initializer.

## Property Wrapper Initialization

Property-wrapper properties are excluded by default.

```swift
@StoredPropertyInit
struct User {
    @State var name: String = ""
}
```

Use `@WrappedInit(type:)` to explicitly include a property-wrapper property in `mode: .storedProperties`.

```swift
import StoredPropertyInit
import SwiftUI

@StoredPropertyInit
struct ToggleRow {
    @WrappedInit(type: Binding<Bool>.self)
    @Binding var isOn: Bool
}
```

Generated initializer:

```swift
init(isOn: Binding<Bool>) {
    self._isOn = isOn
}
```

`@WrappedInit(type:)` renders the supplied `type:` expression as the initializer parameter type after removing `.self`, then assigns that parameter through backing storage. In the example, `Binding<Bool>.self` produces `Binding<Bool>` and the initializer assigns it with `self._isOn = isOn`.

## First Parameter Label

Use `firstLabel: .omitted` to omit only the first external parameter label.

```swift
@StoredPropertyInit(defaults: .parameters, firstLabel: .omitted)
struct Box<Value> {
    let value: Value
    var isPinned: Bool = false
}
```

Generated initializer:

```swift
init(_ value: Value, isPinned: Bool = false) {
    self.value = value
    self.isPinned = isPinned
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
- `mode: .dependencies` must include every stored `let` property without an initial value. Any other uninitialized stored property that would be omitted makes the generated initializer invalid.
- The macro does not generate throwing, failable, required, convenience, Codable, or inheritance-aware initializers.
- The macro does not provide property-level customization except `@WrappedInit(type:)`.

## Duplicate Initializer Detection Scope

`StoredPropertyInit` suppresses generation when an existing sync initializer has the same call shape as the initializer the macro would generate. Call-shape comparison uses the external label, internal name, type source text, variadic marker, and sync/async status.

Existing async initializers are not treated as duplicates of the generated sync initializer.

The macro does not resolve semantic type equivalence. For example, `String` and `Swift.String`, `[String]` and `Array<String>`, and `typealias ID = String` versus `String` are treated as different type spellings. In those cases, Swift may still report a duplicate initializer after macro expansion.

## Diagnostics

Representative diagnostics:

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
