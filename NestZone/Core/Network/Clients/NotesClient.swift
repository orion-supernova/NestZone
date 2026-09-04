import ComposableArchitecture
import Foundation
import ConvexMobile

@DependencyClient
public struct NotesClient: Sendable {
    public var byHome: @Sendable (HomeID) -> AsyncThrowingStream<[Note], any Error> = { _ in .never }
    public var create: @Sendable (String, String?, HomeID) async throws -> Void
    public var update: @Sendable (NoteID, String, String?) async throws -> Void
    public var remove: @Sendable (NoteID) async throws -> Void
}

extension NotesClient: DependencyKey {
    public static let liveValue = NotesClient(
        byHome: { homeID in
            ConvexConnection.shared.subscribe(
                to: "notes:listByHome", args: ["homeId": homeID], as: [Note].self
            )
        },
        create: { body, color, homeID in
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.noteEmpty",
                    defaultValue: "Write something first."
                ))
            }
            var args: [String: ConvexEncodable?] = ["description": trimmed, "homeId": homeID]
            if let color { args["color"] = color }
            try await ConvexConnection.shared.mutate("notes:create", args: args)
        },
        update: { id, body, color in
            var args: [String: ConvexEncodable?] = ["id": id, "description": body]
            if let color { args["color"] = color }
            try await ConvexConnection.shared.mutate("notes:update", args: args)
        },
        remove: { id in
            try await ConvexConnection.shared.mutate("notes:remove", args: ["id": id])
        }
    )

    public static let testValue = NotesClient()
}

extension DependencyValues {
    public var notes: NotesClient {
        get { self[NotesClient.self] }
        set { self[NotesClient.self] = newValue }
    }
}
