import SwiftUI
import Synchronization

/// The colour that stands for one household member.
///
/// Derived from their id, so the same person is the same colour on every screen
/// and on every device with nothing to store — and, more usefully, so a slice of
/// the contributions ring is visibly *their* slice because it matches the avatar
/// next to it. `Avatar` and every chart go through here for exactly that reason.
///
/// `Palette` holds `static let` constants because a `body` must never build a
/// colour. That rule cannot hold literally for a value keyed on a runtime id, so
/// this does the next best thing: the hash — the part that actually costs
/// something, a pass over the id string — is computed once per member and cached.
/// What remains at the call site is a struct initialiser over three `Double`s.
public enum MemberTint {
    private static let hues = Mutex<[String: Double]>([:])

    /// Stable hue in `0..<1` for `seed`.
    ///
    /// Not `String.hashValue`: that is seeded per process, so it would give the
    /// same member a different colour on every launch. djb2 is stable forever.
    public static func hue(for seed: String) -> Double {
        if let cached = hues.withLock({ $0[seed] }) { return cached }
        var hash: UInt64 = 5381
        for byte in seed.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        let hue = Double(hash % 360) / 360
        hues.withLock { $0[seed] = hue }
        return hue
    }

    /// The flat colour: chart segments, legend dots, bars.
    public static func color(for seed: String) -> Color {
        Color(hue: hue(for: seed), saturation: 0.62, brightness: 0.82)
    }

    /// The two-stop version, for a filled surface big enough to show it — an
    /// avatar, a ring segment.
    public static func gradient(for seed: String) -> LinearGradient {
        let hue = hue(for: seed)
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.62, brightness: 0.82),
                Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.66),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Work nobody can be credited with. Grey on purpose — it has to read as
    /// "no one" rather than as a sixth housemate.
    public static let unattributed = Color.secondary.opacity(0.35)
}
