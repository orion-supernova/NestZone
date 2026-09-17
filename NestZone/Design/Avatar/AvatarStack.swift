import SwiftUI

/// Overlapping avatars for "who's in this home / chat".
///
/// Draws `Avatar`, so it gained photographs the moment `Avatar` did — the id it
/// already carried for the tint is the same id the directory is keyed on.
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
                // A summary, not a roster: the stack stands for "these
                // people" and is routinely the label of something that expands
                // it. Opening one face out of an overlapping pile is a guess
                // about which one was tapped.
                Avatar(initials: member.initials, seed: member.id, size: size, viewable: false)
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
        .accessibilityLabel(Text(L10n.membersAccessibility(members.count)))
    }
}
