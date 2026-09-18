import Foundation

/// The app's own version, and how it compares to somebody else's.
///
/// This exists because deploying the backend and shipping a build are two
/// different events that will never coincide. A release note for 1.9.0 is
/// written and published the moment the work lands; the households reading it
/// are on 1.8.1, on 1.7, and on whatever Apple has not finished reviewing. A
/// changelog that assumed otherwise would promise every reader a button that
/// half of them do not have.
///
/// So the note carries the version it belongs to and **the client decides**:
/// at or below mine and it is something I have, above mine and it is coming.
/// The decision is local, needs no round trip, and is right on a phone that has
/// been offline for a week.
///
/// Compared component by component as numbers, never as text. "1.10.0" is above
/// "1.9.0" and a string comparison says the opposite — which would quietly
/// invert the gate for exactly one release in ten.
public struct AppVersion: Hashable, Sendable, Comparable, CustomStringConvertible {
    /// Major, minor, patch, and whatever else was written. Trailing zeros are
    /// not trimmed: comparison pads instead, so 1.9 and 1.9.0 are equal.
    public let components: [Int]
    /// What was parsed, for display. Never re-derived from `components` — a
    /// version is a string the App Store shows, not a tuple.
    public let raw: String

    public var description: String { raw }

    /// Parses a marketing version. Anything unparseable in a component reads as
    /// zero rather than failing: a build tagged "1.9.0-beta2" is still 1.9.0 for
    /// the purpose of "do I have this feature", and a gate that threw would
    /// leave the reader with no answer at all.
    public init(_ raw: String) {
        self.raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        components = self.raw
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { part in
                // Leading digits only, so "0-beta2" is 0 and "2rc1" is 2.
                Int(part.prefix { $0.isNumber }) ?? 0
            }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        let width = max(lhs.components.count, rhs.components.count)
        for index in 0..<width {
            // Padded rather than truncated, so 1.9 == 1.9.0 and 1.9 < 1.9.1.
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    /// This build's marketing version, read once.
    ///
    /// `CFBundleShortVersionString` and not the build number: the build number
    /// is 1 in this project and moves for reasons that have nothing to do with
    /// what the app can do, while the marketing version is what a release note
    /// is written against.
    public static let current: AppVersion = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return AppVersion(raw ?? "0")
    }()
}

/// Whether a release note describes something this build actually has.
public enum UpdateAvailability: Hashable, Sendable {
    /// Shipped at or before this build's version — or tied to no version at
    /// all, which is what an announcement is.
    case available
    /// Published, but it lands in a version this phone does not have yet.
    case comingSoon
}

extension AppUpdate {
    /// Whether this is something the reader has, or something they are waiting
    /// for.
    ///
    /// Defaulting to `.available` when there is no version is deliberate and is
    /// the safe direction: an announcement about the service is true on every
    /// build, and the failure mode of guessing wrong here is a note that reads
    /// as ordinary news rather than one that dangles a feature nobody can find.
    public func availability(
        against version: AppVersion = .current
    ) -> UpdateAvailability {
        guard let raw = self.version, !raw.isEmpty else { return .available }
        return AppVersion(raw) <= version ? .available : .comingSoon
    }

    /// Convenience for the view layer, which asks this per row.
    public var isComingSoon: Bool { availability() == .comingSoon }
}
