import Foundation

/// The house's vote for its next companion, as `companion:forHome` serves it:
/// the options with their tally, this person's own answers, and how many
/// people have answered every one.
///
/// Ballots go to the vote's poll (`polls:vote` / `polls:unvote`) with a species
/// as the target; closing it is the server's (everyone answered, the deadline,
/// `companion:decide`, or a pick before anyone else had answered).
///
/// Everything here degrades on its own: a status or an ending this build has
/// not heard of is `.other`, and a species it cannot draw is an option with no
/// `species`, never another one in its place.
public struct CompanionVote: Decodable, Equatable, Sendable {
    public var pollID: PollID
    public var status: Status
    public var openedAt: Date
    /// When it closes on its own if not everybody has answered every option.
    public var closesAt: Date
    public var closedAt: Date?
    /// How it ended. `nil` while it is open.
    public var how: How?
    /// What it chose: `nil` while open, and on a vote that ended with no yes,
    /// after which anyone picks.
    public var winner: String?
    /// Best first.
    public var options: [Option]
    /// This person's own answers, by species.
    public var mine: [String: Bool]
    /// Current members, and how many of them have answered every option.
    public var members: Int
    public var answered: Int
    /// Somebody other than this person has answered. While it is false a pick
    /// is still a pick; once it is true the ballots decide.
    public var othersVoted: Bool

    public enum Status: String, Decodable, Sendable {
        case open, closed
        /// A state added after this build. Nothing can be sent to it.
        case other
    }

    public enum How: String, Decodable, Sendable {
        case everyone, deadline, decided, picked, moved
        case other
    }

    public struct Option: Decodable, Equatable, Sendable, Identifiable {
        /// The species' raw value, which is also the ballot's target.
        public var id: String
        public var isPet: Bool
        /// Already in the album: a tie goes to one that is not.
        public var grown: Bool
        public var yes: Int
        public var no: Int

        /// `nil` for a species this build cannot draw.
        public var species: Species? { Species(rawValue: id) }

        enum CodingKeys: String, CodingKey { case species, isPet, grown, yes, no }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .species)
            isPet = (try? c.decodeIfPresent(Bool.self, forKey: .isPet)) ?? Species(rawValue: id)?.isPet ?? false
            grown = (try? c.decodeIfPresent(Bool.self, forKey: .grown)) ?? false
            yes = c.decodeNumber(forKey: .yes)
            no = c.decodeNumber(forKey: .no)
        }

        public init(id: String, isPet: Bool = false, grown: Bool = false, yes: Int = 0, no: Int = 0) {
            self.id = id
            self.isPet = isPet
            self.grown = grown
            self.yes = yes
            self.no = no
        }
    }

    public var isOpen: Bool { status == .open }

    /// This person has answered every option, which is what counts as having
    /// voted.
    public var hasAnsweredAll: Bool { !options.isEmpty && options.allSatisfy { mine[$0.id] != nil } }

    /// A yes was said to at least one option, so settling it has a winner.
    public var hasYes: Bool { options.contains { $0.yes > 0 } }

    public init(
        pollID: PollID, status: Status = .open, openedAt: Date, closesAt: Date, closedAt: Date? = nil, how: How? = nil,
        winner: String? = nil, options: [Option], mine: [String: Bool] = [:], members: Int, answered: Int = 0,
        othersVoted: Bool = false
    ) {
        self.pollID = pollID
        self.status = status
        self.openedAt = openedAt
        self.closesAt = closesAt
        self.closedAt = closedAt
        self.how = how
        self.winner = winner
        self.options = options
        self.mine = mine
        self.members = members
        self.answered = answered
        self.othersVoted = othersVoted
    }

    enum CodingKeys: String, CodingKey {
        case pollId, status, openedAt, closesAt, closedAt, how, winner, options, mine, members, answered, othersVoted
    }

    private struct Answer: Decodable {
        var species: String
        var yes: Bool
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pollID = try c.decode(PollID.self, forKey: .pollId)
        status = c.decodeLenient(Status.self, forKey: .status, default: .other)
        openedAt = Self.date(c, .openedAt) ?? .distantPast
        closesAt = Self.date(c, .closesAt) ?? .distantFuture
        closedAt = Self.date(c, .closedAt)
        if let raw = (try? c.decodeIfPresent(String.self, forKey: .how)) ?? nil {
            how = How(rawValue: raw) ?? .other
        } else {
            how = nil
        }
        winner = (try? c.decodeIfPresent(String.self, forKey: .winner)) ?? nil
        options = (try? c.decodeIfPresent(LossyList<Option>.self, forKey: .options))?.elements ?? []
        let answers = (try? c.decodeIfPresent(LossyList<Answer>.self, forKey: .mine))?.elements ?? []
        mine = Dictionary(answers.map { ($0.species, $0.yes) }, uniquingKeysWith: { _, last in last })
        members = c.decodeNumber(forKey: .members)
        answered = c.decodeNumber(forKey: .answered)
        othersVoted = (try? c.decodeIfPresent(Bool.self, forKey: .othersVoted)) ?? false
    }

    private static func date(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Date? {
        ((try? c.decodeIfPresent(Double.self, forKey: key)) ?? nil).map { Date(timeIntervalSince1970: $0 / 1000) }
    }

    // MARK: Laying an answer over the tally

    /// Puts this person's answer to one option (`nil` takes it back) into the
    /// tally, the way the server would count it. Only what this person's own
    /// ballot changes moves: the option's yes and no, `mine`, and whether they
    /// are among those who have answered everything.
    public mutating func answer(_ id: String, as answer: Bool?) {
        guard let index = options.firstIndex(where: { $0.id == id }), mine[id] != answer else { return }
        let hadAll = hasAnsweredAll
        switch mine[id] {
        case true?: options[index].yes -= 1
        case false?: options[index].no -= 1
        case nil: break
        }
        switch answer {
        case true?: options[index].yes += 1
        case false?: options[index].no += 1
        case nil: break
        }
        mine[id] = answer
        if hadAll != hasAnsweredAll { answered += hasAnsweredAll ? 1 : -1 }
    }

    /// Ends it with what was chosen, as the server's answer says it did.
    public mutating func close(winner: String?, how: How, at date: Date? = nil) {
        status = .closed
        self.winner = winner
        self.how = how
        if let date { closedAt = date }
    }
}
