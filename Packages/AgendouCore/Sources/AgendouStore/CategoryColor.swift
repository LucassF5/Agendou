/// The fixed palette. Categories store the key, so the actual colors can be tuned for light and dark
/// mode without migrating anything.
public enum CategoryColor: String, CaseIterable, Sendable {
    case teal, blue, indigo, purple, pink, red, orange, brown, green, mint

    /// Unknown keys (from a newer export, say) fall back to the default instead of failing.
    public init(key: String) {
        self = CategoryColor(rawValue: key) ?? .teal
    }
}
