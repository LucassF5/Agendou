import Foundation

/// Something marked by hand: an extra shift, or the cancellation of a generated one.
public struct Override: Hashable, Sendable, Identifiable {
    public enum Kind: Int, Hashable, Sendable {
        case extra = 0
        case cancellation = 1
    }

    public var id: UUID
    public var categoryID: UUID
    public var kind: Kind
    public var startsAt: Int64
    public var endsAt: Int64

    public init(id: UUID, categoryID: UUID, kind: Kind, startsAt: Int64, endsAt: Int64) {
        self.id = id
        self.categoryID = categoryID
        self.kind = kind
        self.startsAt = startsAt
        self.endsAt = endsAt
    }
}
