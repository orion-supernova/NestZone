import ComposableArchitecture
import Foundation
import ConvexMobile

@DependencyClient
public struct ShoppingClient: Sendable {
    public var byHome: @Sendable (HomeID) -> AsyncThrowingStream<[ShoppingItem], any Error> = { _ in .never }
    public var create: @Sendable (NewShoppingItem) async throws -> Void
    /// Sends a recipe's ingredients to the list in one round trip. Returns how
    /// many were added — the server skips anything already outstanding, so the
    /// count is what the person actually gained.
    public var addFromRecipe: @Sendable (RecipeIngredients) async throws -> Int
    public var setPurchased: @Sendable (ShoppingItemID, Bool) async throws -> Void
    public var update: @Sendable (ShoppingItemID, String, Double?, ShoppingItem.Category) async throws -> Void
    public var remove: @Sendable (ShoppingItemID) async throws -> Void
}

public struct NewShoppingItem: Equatable, Sendable {
    public var name: String
    public var quantity: Double?
    public var category: ShoppingItem.Category
    public var homeID: HomeID

    public init(
        name: String,
        quantity: Double? = nil,
        category: ShoppingItem.Category = .other,
        homeID: HomeID
    ) {
        self.name = name
        self.quantity = quantity
        self.category = category
        self.homeID = homeID
    }
}

/// A recipe's ingredient lines, on their way to the shopping list.
public struct RecipeIngredients: Equatable, Sendable {
    public var recipeID: RecipeID
    public var recipeTitle: String
    public var names: [String]
    public var homeID: HomeID

    public init(recipeID: RecipeID, recipeTitle: String, names: [String], homeID: HomeID) {
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.names = names
        self.homeID = homeID
    }
}

extension ShoppingClient: DependencyKey {
    public static let liveValue = ShoppingClient(
        byHome: { homeID in
            ConvexConnection.shared.subscribe(
                to: "shopping:listByHome", args: ["homeId": homeID], as: [ShoppingItem].self
            )
        },
        create: { item in
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.validation(String(
                    localized: "validation.itemNameEmpty",
                    defaultValue: "Name the item first."
                ))
            }
            var args: [String: ConvexEncodable?] = [
                "name": trimmed,
                "homeId": item.homeID,
                "category": item.category.rawValue,
            ]
            if let quantity = item.quantity { args["quantity"] = quantity }
            try await ConvexConnection.shared.mutate("shopping:create", args: args)
        },
        addFromRecipe: { batch in
            let names = batch.names
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !names.isEmpty else { return 0 }
            let result = try await ConvexConnection.shared.mutate(
                "shopping:createFromRecipe",
                args: [
                    "homeId": batch.homeID,
                    "recipeId": batch.recipeID,
                    "recipeTitle": batch.recipeTitle,
                    // `[String]` is not `ConvexEncodable` — only `[ConvexEncodable?]`
                    // is, so the array has to be widened element by element.
                    "names": names.map { $0 as ConvexEncodable? },
                ],
                as: AddedCount.self
            )
            return result.added
        },
        setPurchased: { id, isPurchased in
            try await ConvexConnection.shared.mutate(
                "shopping:setPurchased", args: ["id": id, "is_purchased": isPurchased]
            )
        },
        update: { id, name, quantity, category in
            var args: [String: ConvexEncodable?] = [
                "id": id,
                "name": name,
                "category": category.rawValue,
            ]
            if let quantity { args["quantity"] = quantity }
            try await ConvexConnection.shared.mutate("shopping:update", args: args)
        },
        remove: { id in
            try await ConvexConnection.shared.mutate("shopping:remove", args: ["id": id])
        }
    )

    public static let testValue = ShoppingClient()
}

/// `shopping:createFromRecipe` answers with what it actually did.
private struct AddedCount: Decodable {
    let added: Int
    let skipped: Int
}

extension DependencyValues {
    public var shopping: ShoppingClient {
        get { self[ShoppingClient.self] }
        set { self[ShoppingClient.self] = newValue }
    }
}
