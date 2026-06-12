# swift-stored-property-init
Generate Swift initializers from stored properties using macros.

## Duplicate Initializer Detection Scope

StoredPropertyInit suppresses generation when an existing sync initializer has the same call shape as the initializer the macro would generate. Call-shape comparison uses the external label and type source text written in the declaration. Existing async initializers are not treated as duplicates of the generated sync initializer.

The macro does not resolve semantic type equivalence. For example, `String` and `Swift.String`, `[String]` and `Array<String>`, and `typealias ID = String` versus `String` are treated as different type spellings. In those cases, Swift may still report a duplicate initializer after macro expansion.
