import ComposableArchitecture
import Foundation
import ConvexMobile

@DependencyClient
public struct ShoppingClient: Sendable {
    public var byHome: @Sendable (HomeID) -> AsyncThrowingStream<[ShoppingItem], any Error> = { _ in .never }
    public var create: @Sendable (NewShoppingItem) async throws -> Void
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

extension DependencyValues {
    public var shopping: ShoppingClient {
        get { self[ShoppingClient.self] }
        set { self[ShoppingClient.self] = newValue }
    }
}
