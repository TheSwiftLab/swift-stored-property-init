import XCTest

#if canImport(StoredPropertyInitMacros)
import StoredPropertyInitMacros
#endif

final class StoredPropertyInitTests: XCTestCase {
    func testStoredPropertyInitMacroLoads() throws {
        #if canImport(StoredPropertyInitMacros)
        XCTAssertNotNil(StoredPropertyInitMacro.self)
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
