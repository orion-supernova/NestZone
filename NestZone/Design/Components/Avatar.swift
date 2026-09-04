import SwiftUI

/// A person, drawn as their initials on a colour derived from their id.
///
/// Deriving the colour from the id means the same member is the same colour on
/// every screen and across devices, with nothing to store.
public struct Avatar: View {
    private let initials: String
    private let seed: String
    private let size: CGFloat

    public init(initials: String, seed: String, size: CGFloat = 36) {
        self.initials = initials
        self.seed = seed
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(Self.gradient(for: seed))
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }

    /// Stable hash → hue. `String.hashValue` is seeded per-process, so it would
    /// give the same member a different colour on every launch.
    private static func gradient(for seed: String) -> LinearGradient {
        var hash: UInt64 = 5381
        for byte in seed.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        let hue = Double(hash % 360) / 360
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.62, brightness: 0.82),
                Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.66),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Overlapping avatars for "who's in this home / chat".
public struct AvatarStack: View {
    public struct Member: Identifiable, Hashable, Sendable {
        public let id: String
        public let initials: String

        public init(id: String, initials: String) {
            self.id = id
            self.initials = initials
        }
    }

    private let members: [Member]
    private let size: CGFloat
    private let maxVisible: Int

    public init(members: [Member], size: CGFloat = 28, maxVisible: Int = 4) {
        self.members = members
        self.size = size
        self.maxVisible = maxVisible
    }

    public var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(members.prefix(maxVisible)) { member in
                Avatar(initials: member.initials, seed: member.id, size: size)
                    .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
            }
            if members.count > maxVisible {
                Circle()
                    .fill(.quaternary)
                    .frame(width: size, height: size)
                    .overlay {
                        Text("+\(members.count - maxVisible)")
                            .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(members.count) members"))
    }
}
