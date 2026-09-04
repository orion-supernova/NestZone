import Foundation

/// Convex stores every timestamp as epoch-**milliseconds**, as a JSON number.
/// The app used to scatter `Date(timeIntervalSince1970: ms / 1000)` and bare
/// `Double` comparisons across view models; this is the one place that knows
/// about the unit.
public struct Timestamp: Hashable, Sendable, Codable, Comparable {
    public var milliseconds: Double

    public init(milliseconds: Double) { self.milliseconds = milliseconds }
    public init(_ date: Date) { self.milliseconds = date.timeIntervalSince1970 * 1000 }

    public var date: Date { Date(timeIntervalSince1970: milliseconds / 1000) }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.milliseconds < rhs.milliseconds }

    public init(from decoder: any Decoder) throws {
        milliseconds = try decoder.singleValueContainer().decode(Double.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(milliseconds)
    }
}

extension Timestamp {
    /// Sorts newest-first, tolerating the documents whose `created` the
    /// PocketBase import left null.
    public static func newestFirst(_ lhs: Timestamp?, _ rhs: Timestamp?) -> Bool {
        (lhs?.milliseconds ?? 0) > (rhs?.milliseconds ?? 0)
    }
}

extension Date {
    /// Epoch-ms, ready to hand to a Convex mutation argument.
    public var convexMillis: Double { timeIntervalSince1970 * 1000 }
}
