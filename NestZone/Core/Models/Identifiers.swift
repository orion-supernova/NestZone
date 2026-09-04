import Foundation

/// A Convex document id, tagged with the table it points into.
///
/// Convex ids are opaque strings and every one of them used to be typed `String`
/// in this app, which is how `homeId` ended up passed where a `userId` was
/// expected. The phantom type makes that a compile error while still encoding
/// and decoding as a plain string on the wire.
public struct ConvexID<Table>: Hashable, Sendable, Codable, RawRepresentable,
                               ExpressibleByStringLiteral, CustomStringConvertible {
    public var rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public var description: String { rawValue }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// Table markers. Uninhabited on purpose — they only ever exist as a phantom.
public enum UsersTable {}
public enum HomesTable {}
public enum TasksTable {}
public enum ShoppingTable {}
public enum NotesTable {}
public enum ConversationsTable {}
public enum MessagesTable {}
public enum RecipesTable {}
public enum MovieListsTable {}
public enum MoviesTable {}
public enum PollsTable {}

public typealias UserID = ConvexID<UsersTable>
public typealias HomeID = ConvexID<HomesTable>
public typealias TaskID = ConvexID<TasksTable>
public typealias ShoppingItemID = ConvexID<ShoppingTable>
public typealias NoteID = ConvexID<NotesTable>
public typealias ConversationID = ConvexID<ConversationsTable>
public typealias MessageID = ConvexID<MessagesTable>
public typealias RecipeID = ConvexID<RecipesTable>
public typealias MovieListID = ConvexID<MovieListsTable>
public typealias StoredMovieID = ConvexID<MoviesTable>
public typealias PollID = ConvexID<PollsTable>
