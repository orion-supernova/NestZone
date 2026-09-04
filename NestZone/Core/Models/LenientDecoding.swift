import Foundation

extension KeyedDecodingContainer {
    /// Decodes an enum, falling back instead of throwing on a value this build
    /// does not know.
    ///
    /// This matters more than it looks. Every list in the app is backed by a
    /// live subscription that decodes an *array*, so a single row carrying an
    /// unrecognised enum — a status added server-side, a value written by a
    /// newer client, a legacy row from the PocketBase import — throws and takes
    /// the entire screen down with it. Degrading one field is always better
    /// than blanking the list.
    func decodeLenient<T: RawRepresentable & Decodable>(
        _ type: T.Type,
        forKey key: Key,
        default fallback: T
    ) -> T where T.RawValue: Decodable {
        guard let raw = try? decodeIfPresent(T.RawValue.self, forKey: key) else { return fallback }
        return T(rawValue: raw) ?? fallback
    }
}
