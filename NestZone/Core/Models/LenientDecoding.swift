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

    /// The same leniency for a field that is genuinely optional: absent and
    /// unrecognised both come back as `nil` rather than throwing.
    func decodeLenientIfPresent<T: RawRepresentable & Decodable>(
        _ type: T.Type,
        forKey key: Key
    ) -> T? where T.RawValue: Decodable {
        guard let raw = try? decodeIfPresent(T.RawValue.self, forKey: key) else { return nil }
        return T(rawValue: raw)
    }
}

extension KeyedDecodingContainer {
    /// Decodes a number that must land as an `Int` — an amount in minor units,
    /// a count, a year.
    ///
    /// Convex's `v.number()` is float64. Integer-valued numbers have always
    /// come back over this wire without a decimal point, which is why the rest
    /// of the app decodes counts straight into `Int` — but money is the one
    /// field where being wrong is not a cosmetic problem, and an expense list
    /// is decoded as a single array, so one `1234.0` would blank the whole
    /// ledger rather than one row. Trying `Int` and falling back to a rounded
    /// `Double` accepts both spellings of the same value.
    func decodeNumber(forKey key: Key, default fallback: Int = 0) -> Int {
        if let exact = try? decodeIfPresent(Int.self, forKey: key) { return exact }
        if let loose = try? decodeIfPresent(Double.self, forKey: key), loose.isFinite {
            return Int(loose.rounded())
        }
        return fallback
    }

    /// The same, for a number that is genuinely optional — a budget nobody set,
    /// a serving count nobody filled in.
    ///
    /// `contains(_:)` cannot answer this question, which is what the three call
    /// sites that used it got wrong. Convex writes an absent field as an
    /// explicit `null`, and a key holding `null` is just as *present* as one
    /// holding a number, so `contains(.budget) ? decodeNumber(...) : nil` came
    /// back as a budget of **zero** for every event that had none. A zero
    /// budget is not the absence of one: it makes the plan's ring read as
    /// overspent the instant a penny is logged, and prints "of 0,00" beside the
    /// total. Asking for the value is the only way to tell the two apart.
    func decodeNumberIfPresent(forKey key: Key) -> Int? {
        if let exact = (try? decodeIfPresent(Int.self, forKey: key)) ?? nil { return exact }
        if let loose = (try? decodeIfPresent(Double.self, forKey: key)) ?? nil, loose.isFinite {
            return Int(loose.rounded())
        }
        return nil
    }
}
