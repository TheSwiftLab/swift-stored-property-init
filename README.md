# swift-stored-property-init

[한국어](README.md) | [English](README.en.md)

`StoredPropertyInit`은 모델, DTO, actor, 의존성 주입 중심의 `final class`를 위해 저장 프로퍼티에서 initializer를 생성하는 Swift 6 매크로입니다.

Swift의 기본 memberwise initializer는 주로 `struct` 선언 안에서 편리하게 동작합니다.

하지만 접근 수준을 직접 지정하거나 `actor` 혹은 `final class`에 적용하거나 property wrapper 초기화처럼 더 명시적인 생성 규칙이 필요한 경우에는 한계가 있습니다.

`StoredPropertyInit`은 저장 프로퍼티를 기준으로 initializer를 생성하면서 접근 수준과 생성 모드와 기본값 처리와 property wrapper 포함 여부를 명시적으로 제어할 수 있게 해줍니다.

## 설치

이 패키지는 아직 릴리스 태그를 배포하지 않았습니다.

첫 릴리스 전까지는 Swift package dependencies에 개발 브랜치를 추가합니다.

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/TheSwiftLab/swift-stored-property-init.git",
        branch: "develop"
    )
]
```

그다음 매크로를 사용할 target에 `StoredPropertyInit`을 추가합니다.

```swift
.target(
    name: "AppFeature",
    dependencies: [
        .product(name: "StoredPropertyInit", package: "swift-stored-property-init")
    ]
)
```

첫 릴리스 태그가 배포된 뒤에는 branch requirement 대신 `from: "0.1.0"` 같은 version requirement 사용을 권장합니다.

## StoredPropertyInit을 사용하는 이유

`@StoredPropertyInit`은 initializer 생성 규칙을 여러 타입에서 일관되게 적용하고 싶을 때 사용합니다.

- public model 또는 DTO initializer
- actor initializer
- `final class` 타입의 의존성 initializer
- initializer default argument를 통한 기본값 보존
- backing storage 대입을 통한 명시적 property wrapper 초기화

생성되는 initializer body에는 프로퍼티에 값을 대입하는 코드만 들어갑니다.

검증이나 로그 기록이나 추가 설정 같은 다른 동작은 생성하지 않습니다.

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

생성되는 initializer

```swift
public init(x: Double, y: Double) {
    self.x = x
    self.y = y
}
```

기본값인 `mode: .storedProperties`는 초기값이 없는 저장 프로퍼티를 포함하고 이미 초기값이 있는 저장 프로퍼티는 생략합니다.

## Final Class 의존성 Initializer

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

생성되는 initializer

```swift
public init(store: LibraryStore) {
    self.store = store
}
```

`mode: .dependencies`는 초기값이 없는 모든 저장 `let` 프로퍼티를 포함합니다.

`var` 프로퍼티, property-wrapper 프로퍼티, 초기값이 있는 프로퍼티는 제외합니다.

## 기본값 정책

`defaults: .omitted`는 기본 정책입니다. 초기값이 있는 non-wrapper 저장 프로퍼티를 initializer 파라미터에서 생략합니다.

```swift
@StoredPropertyInit(defaults: .omitted)
struct Size {
    let width: Double
    let height: Double
    var scale: Double = 1
}
```

생성되는 initializer

```swift
init(width: Double, height: Double) {
    self.width = width
    self.height = height
}
```

`defaults: .parameters`는 초기값이 있는 non-wrapper `var` 프로퍼티를 property initializer에서 복사한 default argument와 함께 파라미터에 포함합니다.

```swift
@StoredPropertyInit(.public, defaults: .parameters)
public struct Rectangle {
    public var width: Double = 100
    public var height: Double = 100
}
```

생성되는 initializer

```swift
public init(width: Double = 100, height: Double = 100) {
    self.width = width
    self.height = height
}
```

초기값이 있는 non-wrapper `let` 프로퍼티는 `defaults: .parameters`로 포함할 수 없습니다.

Swift가 생성된 initializer 안에서 해당 프로퍼티에 다시 대입하는 것을 허용하지 않기 때문입니다.

## Property Wrapper 초기화

Property-wrapper 프로퍼티는 기본적으로 제외됩니다.

SwiftUI에서는 상태를 소유하는 parent `View`가 `@State`를 가지고 child `View`는 `@Binding`으로 그 상태를 전달받는 형태가 일반적입니다.

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

생성되는 initializer

```swift
public init(isOn: Binding<Bool>) {
    self._isOn = isOn
}
```

`mode: .storedProperties`에서 property-wrapper 프로퍼티를 명시적으로 포함하려면 `@WrappedInit(type:)`을 사용합니다.

`@WrappedInit(type:)`은 전달된 `type:` 표현식에서 `.self`를 제거한 값을 initializer 파라미터 타입으로 렌더링한 뒤 해당 파라미터를 backing storage에 대입합니다.

위 예제에서는 `ContentView`의 `$isOn`이 생성된 `public init(isOn:)`으로 전달되고 `Binding<Bool>.self`가 `Binding<Bool>` 파라미터를 만들며 initializer는 `self._isOn = isOn`으로 대입합니다.

## 첫 번째 파라미터 레이블

`firstLabel: .omitted`를 사용하면 첫 번째 external parameter label만 생략합니다.

```swift
@StoredPropertyInit(defaults: .parameters, firstLabel: .omitted)
struct Pair<Value> {
    let first: Value
    var second: Value? = nil
}
```

생성되는 initializer

```swift
init(_ first: Value, second: Value? = nil) {
    self.first = first
    self.second = second
}
```

## 지원 선언

`@StoredPropertyInit`은 다음 선언을 지원합니다.

- `struct`
- `actor`
- 상속하거나 protocol을 채택하지 않는 `final class`

지원하는 initializer 접근 수준:

- `private`
- `fileprivate`
- `internal`
- `package` 접근 수준
- `public`

`InitAccess.open`은 public API에 존재하지만 Swift initializer는 `open`일 수 없습니다. 대신 `.public`을 사용합니다.

## 제한 사항

- Non-final class는 지원하지 않습니다.
- 다른 타입을 상속하거나 protocol을 채택한 `final class` 선언은 지원하지 않습니다.
- `enum`, `protocol`, `extension` 및 다른 선언 종류는 지원하지 않습니다.
- `static`, computed, `lazy`, multi-binding, non-identifier-pattern 프로퍼티는 건너뜁니다.
- Property-wrapper 프로퍼티는 `@WrappedInit(type:)`이 붙어 있지 않으면 건너뜁니다.
- 선택된 non-wrapper 프로퍼티에는 명시적 타입 annotation이 필요합니다.
- `mode: .dependencies`는 초기값이 없는 모든 저장 `let` 프로퍼티를 포함해야 합니다. 초기화되지 않은 다른 저장 프로퍼티가 생략되어 생성 initializer가 유효하지 않으면 오류를 보고합니다.
- 이 매크로는 throwing, failable, required, convenience, Codable, 상속을 고려한 initializer를 생성하지 않습니다.
- 이 매크로는 `@WrappedInit(type:)` 외의 프로퍼티 단위 설정을 제공하지 않습니다.

## 중복 Initializer 감지 범위

`StoredPropertyInit`은 기존 sync initializer가 매크로가 생성할 initializer와 같은 call shape를 가지면 생성을 억제합니다.

Call-shape 비교에는 external label, internal name, type source text, variadic marker, sync/async 상태를 사용합니다.

기존 async initializer는 생성될 sync initializer의 중복으로 취급하지 않습니다.

이 매크로는 semantic type equivalence를 해석하지 않습니다. 예를 들어 `String`과 `Swift.String`, `[String]`과 `Array<String>`, `typealias ID = String`과 `String`은 서로 다른 type spelling으로 취급합니다. 이 경우 Swift가 macro expansion 이후에 duplicate initializer를 보고할 수 있습니다.

## 오류 메시지

매크로가 보고할 수 있는 대표 메시지입니다.

- 오류: `@StoredPropertyInit requires classes to be final.`
- 오류: `@StoredPropertyInit does not support final classes with inheritance clauses.`
- 오류: `@StoredPropertyInit can only be applied to a struct, final class, or actor.`
- 오류: `StoredPropertyInit requires an explicit type annotation for generated initializer parameters.`
- 오류: `StoredPropertyInit cannot use initialized let property 'id' with defaults: .parameters.`
- 오류: `StoredPropertyInit cannot omit uninitialized property 'cache' in mode: .dependencies.`
- 오류: `StoredPropertyInit cannot generate an open initializer. Use public access instead.`
- 경고: `StoredPropertyInit skipped generation because a matching initializer exists.`
- 노트: `StoredPropertyInit skipped attribute-decorated property 'name'.`
- 노트: `StoredPropertyInit skipped computed, static, lazy, or multi-binding property 'name'.`
- 노트: `StoredPropertyInit skipped a property because its pattern is not a simple identifier.`

## License

`swift-stored-property-init`은 MIT license로 제공됩니다.

Copyright (c) 2026 TheSwiftLab
