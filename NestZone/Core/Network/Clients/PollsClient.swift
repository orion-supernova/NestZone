import ComposableArchitecture
import Foundation
import ConvexMobile

@DependencyClient
public struct PollsClient: Sendable {
    public var byHome: @Sendable (HomeID) -> AsyncThrowingStream<[Poll], any Error> = { _ in .never }
    /// Live detail for one poll. This is what makes the swipe game multiplayer:
    /// another member's vote arrives here without anyone refreshing.
    public var detail: @Sendable (PollID) -> AsyncThrowingStream<PollDetail, any Error> = { _ in .never }
    /// Creates a round and returns its id. `kind` is the *entity* being voted
    /// on — a movie night and a dinner round share every line of this machinery
    /// and differ only here.
    public var create: @Sendable (HomeID, String, Poll.Kind, String?, [PollCandidate]) async throws -> PollID
    public var addItem: @Sendable (PollID, PollCandidate, Int?) async throws -> Void
    public var vote: @Sendable (PollID, String, Bool) async throws -> Void
    public var close: @Sendable (PollID) async throws -> Void
    public var remove: @Sendable (PollID) async throws -> Void
}

/// A movie put up for a vote.
public struct PollCandidate: Equatable, Sendable {
    public var externalID: String
    public var label: String?
    public var thumbnailURL: String?

    public init(externalID: String, label: String? = nil, thumbnailURL: String? = nil) {
        self.externalID = externalID
        self.label = label
        self.thumbnailURL = thumbnailURL
    }

    public init(_ movie: Movie) {
        externalID = movie.id
        label = movie.title
        thumbnailURL = movie.poster
    }

    var arguments: [String: ConvexEncodable?] {
        var args: [String: ConvexEncodable?] = ["external_id": externalID]
        if let label { args["label"] = label }
        if let thumbnailURL { args["thumbnail_url"] = thumbnailURL }
        return args
    }
}

extension PollsClient: DependencyKey {
    public static let liveValue = PollsClient(
        byHome: { homeID in
            ConvexConnection.shared.subscribe(
                to: "polls:listByHome", args: ["homeId": homeID], as: [Poll].self
            )
        },
        detail: { pollID in
            ConvexConnection.shared.subscribe(
                to: "polls:detail", args: ["pollId": pollID], as: PollDetail.self
            )
        },
        create: { homeID, title, kind, genre, candidates in
            var args: [String: ConvexEncodable?] = [
                "homeId": homeID,
                "title": title,
                "type": kind.rawValue,
                "items": candidates.map { $0.arguments as ConvexEncodable? },
            ]
            if let genre { args["genre"] = genre }
            // `polls:create` returns the inserted document, not a bare id.
            let poll = try await ConvexConnection.shared.mutate(
                "polls:create", args: args, as: Poll.self
            )
            return poll.id
        },
        addItem: { pollID, candidate, order in
            var args = candidate.arguments
            args["pollId"] = pollID
            if let order { args["order"] = order.convexNumber }
            try await ConvexConnection.shared.mutate("polls:addItem", args: args)
        },
        vote: { pollID, externalID, isYes in
            try await ConvexConnection.shared.mutate(
                "polls:vote",
                args: ["pollId": pollID, "target_external_id": externalID, "vote": isYes]
            )
        },
        close: { pollID in
            try await ConvexConnection.shared.mutate(
                "polls:setStatus", args: ["pollId": pollID, "status": "closed"]
            )
        },
        remove: { pollID in
            try await ConvexConnection.shared.mutate("polls:remove", args: ["pollId": pollID])
        }
    )

    public static let testValue = PollsClient()
}

extension DependencyValues {
    public var polls: PollsClient {
        get { self[PollsClient.self] }
        set { self[PollsClient.self] = newValue }
    }
}
