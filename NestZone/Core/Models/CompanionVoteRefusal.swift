import Foundation

/// The things the server says on purpose when the vote for the next companion
/// (or a colour the house cannot have yet) turns a write away. They are not failures to retry: someone else moved
/// first, and the live read is already about to show it. Matched on the
/// message, because the server throws them as plain errors (`companion:start`,
/// `polls:vote`); Convex wraps the text, so it is searched for, not compared.
public enum CompanionVoteRefusal: Equatable, Sendable {
    /// A pick after somebody else has answered: the ballots decide now.
    case voting
    /// A pick of something else after the vote chose.
    case chose
    /// A ballot on a vote that has closed.
    case over
    /// A ballot on something that is not one of the options.
    case notAnOption
    /// A start in a colour the house cannot have: before the finale, for a
    /// species it has not grown, or one it has grown in that colour already.
    case colourLocked
    /// A start in a colour that is not one of the three.
    case noSuchColour

    public init?(serverMessage message: String) {
        if message.contains("The house is voting on the next one") {
            self = .voting
        } else if message.contains("The house already chose") {
            self = .chose
        } else if message.contains("That vote is over") {
            self = .over
        } else if message.contains("That isn't one of the options") {
            self = .notAnOption
        } else if message.contains("That colour can't be grown yet") {
            self = .colourLocked
        } else if message.contains("There's no such colour") {
            self = .noSuchColour
        } else {
            return nil
        }
    }

    public var copy: LocalizedStringResource {
        switch self {
        case .voting: L10n.voteRefusedVoting
        case .chose: L10n.voteRefusedChose
        case .over: L10n.voteRefusedOver
        case .notAnOption: L10n.voteRefusedOption
        case .colourLocked: L10n.colourRefusedLocked
        case .noSuchColour: L10n.colourRefusedNone
        }
    }
}
