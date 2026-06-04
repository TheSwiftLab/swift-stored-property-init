import SwiftSyntax

extension PatternBindingSyntax {
    /// 현재 binding이 computed property인지 나타냅니다.
    ///
    /// `willSet` / `didSet`만 있는 observed stored property는 제외하지 않습니다.
    var isComputedProperty: Bool {
        guard let accessorBlock else {
            return false
        }

        switch accessorBlock.accessors {
        case .getter:
            return true
        case let .accessors(accessors):
            return accessors.contains { accessor in
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.get), .keyword(.set), .keyword(._read), .keyword(._modify):
                    return true
                default:
                    return false
                }
            }
        }
    }
}
