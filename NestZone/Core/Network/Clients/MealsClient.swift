import ComposableArchitecture
import Foundation
import ConvexMobile

/// Tonight's dinner, and the days after it.
@DependencyClient
public struct MealsClient: Sendable {
    /// Live plans from `from` (a `YYYY-MM-DD` key) onwards, soonest first.
    public var fromDate: @Sendable (HomeID, String) -> AsyncThrowingStream<[MealPlan], any Error> = { _, _ in .never }
    public var set: @Sendable (DinnerDecision) async throws -> Void
    public var clear: @Sendable (HomeID, String) async throws -> Void
}

/// What the household decided, on its way to the server.
public struct DinnerDecision: Equatable, Sendable {
    public var homeID: HomeID
    public var date: String
    public var kind: MealPlan.Kind
    public var recipeID: RecipeID?
    public var title: String?
    public var cuisine: Cuisine?
    public var place: String?
    /// The calendar event this meal belongs to, when it is part of one.
    public var eventID: EventID?

    public init(
        homeID: HomeID,
        date: String = MealDate.today,
        kind: MealPlan.Kind,
        recipeID: RecipeID? = nil,
        title: String? = nil,
        cuisine: Cuisine? = nil,
        place: String? = nil,
        eventID: EventID? = nil
    ) {
        self.homeID = homeID
        self.date = date
        self.kind = kind
        self.recipeID = recipeID
        self.title = title
        self.cuisine = cuisine
        self.place = place
        self.eventID = eventID
    }
}

extension MealsClient: DependencyKey {
    public static let liveValue = MealsClient(
        fromDate: { homeID, from in
            ConvexConnection.shared.subscribe(
                to: "meals:forHome",
                args: ["homeId": homeID, "from": from],
                as: [MealPlan].self
            )
        },
        set: { decision in
            var args: [String: ConvexEncodable?] = [
                "homeId": decision.homeID,
                "date": decision.date,
                "kind": decision.kind.rawValue,
            ]
            // Sent only when they apply: the server clears the fields that do
            // not belong to the chosen kind, and an explicit null would fail
            // the optional-id validator.
            if let recipeID = decision.recipeID { args["recipeId"] = recipeID }
            if let title = decision.title?.trimmingCharacters(in: .whitespacesAndNewlines),
               !title.isEmpty {
                args["title"] = title
            }
            if let cuisine = decision.cuisine { args["cuisine"] = cuisine.rawValue }
            if let place = decision.place?.trimmingCharacters(in: .whitespacesAndNewlines),
               !place.isEmpty {
                args["place"] = place
            }
            // Sent only when there is one: the server reads an absent `eventId`
            // as "leave the link alone", so re-deciding the same evening cannot
            // silently detach the dinner from the party it belongs to.
            if let eventID = decision.eventID { args["eventId"] = eventID }
            try await ConvexConnection.shared.mutate("meals:set", args: args)
        },
        clear: { homeID, date in
            try await ConvexConnection.shared.mutate(
                "meals:clear", args: ["homeId": homeID, "date": date]
            )
        }
    )

    public static let testValue = MealsClient()
}

extension DependencyValues {
    public var meals: MealsClient {
        get { self[MealsClient.self] }
        set { self[MealsClient.self] = newValue }
    }
}
