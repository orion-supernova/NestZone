import ComposableArchitecture
import Foundation
import SwiftUI

/// The "Hub" tab: a grid of the household's modules, and the screens they open.
@Reducer
public struct HubFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var path = StackState<Path.State>()
        /// Live counts for the module tiles, so each card shows something real
        /// rather than a static subtitle.
        public var shoppingCount = 0
        public var recipeCount = 0
        public var movieCount = 0

        public init(homeID: HomeID) { self.homeID = homeID }
    }

    @Reducer
    public enum Path {
        case shopping(ShoppingFeature)
        case recipes(RecipesFeature)
        case movies(MoviesFeature)
    }

    public enum Action {
        case task
        case countsUpdated(shopping: Int?, recipes: Int?, movies: Int?)
        case moduleTapped(HubModule)
        case path(StackActionOf<Path>)
    }

    private enum CancelID { case shopping, recipes, movies }

    @Dependency(\.shopping) var shoppingClient
    @Dependency(\.recipes) var recipesClient
    @Dependency(\.movies) var moviesClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .merge(
                    .run { send in
                        for try await items in shoppingClient.byHome(homeID) {
                            await send(.countsUpdated(
                                shopping: items.filter { !$0.isPurchased }.count,
                                recipes: nil, movies: nil
                            ))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.shopping, cancelInFlight: true),

                    .run { send in
                        for try await recipes in recipesClient.byHome(homeID) {
                            await send(.countsUpdated(
                                shopping: nil, recipes: recipes.count, movies: nil
                            ))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.recipes, cancelInFlight: true),

                    .run { send in
                        for try await movies in moviesClient.allMovies(homeID) {
                            await send(.countsUpdated(
                                shopping: nil, recipes: nil, movies: movies.count
                            ))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.movies, cancelInFlight: true)
                )

            case let .countsUpdated(shopping, recipes, movies):
                if let shopping { state.shoppingCount = shopping }
                if let recipes { state.recipeCount = recipes }
                if let movies { state.movieCount = movies }
                return .none

            case let .moduleTapped(module):
                switch module {
                case .shopping:
                    state.path.append(.shopping(ShoppingFeature.State(homeID: state.homeID)))
                case .recipes:
                    state.path.append(.recipes(RecipesFeature.State(homeID: state.homeID)))
                case .movies:
                    state.path.append(.movies(MoviesFeature.State(homeID: state.homeID)))
                case .maintenance, .finance, .calendar:
                    // Not built yet; the tile is disabled, so this is unreachable.
                    break
                }
                return .none

            // Leaving the shopping list with a swipe still inside its undo
            // window. The screen cannot do this itself: `onDisappear` fires
            // after the pop, so the action arrived at an element that no longer
            // existed and the delete was dropped (with a runtime warning). Here
            // the element is still in the stack — parent reducers run before
            // `forEach` — so the write can be read off it and sent.
            case let .path(.popFrom(id)):
                guard case let .shopping(shopping) = state.path[id: id],
                      let pending = shopping.pendingDeletion else { return .none }
                return .run { _ in
                    try await shoppingClient.remove(pending.id)
                } catch: { _, _ in
                    // The row is already gone from a screen that is going away.
                }

            // A recipe asking for the shopping list: pop back to the Hub and
            // push the list, rather than stacking one module inside another.
            case let .path(.element(id: id, action: .recipes(.delegate(.openShoppingList)))):
                state.path.pop(from: id)
                state.path.append(.shopping(ShoppingFeature.State(homeID: state.homeID)))
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

/// The tiles on the Hub.
///
/// `notes` used to be listed here as "coming soon" while also being its own tab,
/// so it is not a module — it is one tap away on the tab bar.
public enum HubModule: String, CaseIterable, Identifiable, Sendable {
    case shopping, recipes, movies, maintenance, finance, calendar

    public var id: String { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .shopping: L10n.managementModuleShoppingTitle
        case .recipes: L10n.managementModuleRecipesTitle
        case .movies: L10n.managementModuleMoviesTitle
        case .maintenance: L10n.managementModuleMaintenanceTitle
        case .finance: L10n.managementModuleFinanceTitle
        case .calendar: L10n.managementModuleCalendarTitle
        }
    }

    public var subtitle: LocalizedStringResource {
        switch self {
        case .shopping: L10n.managementModuleShoppingSubtitle
        case .recipes: L10n.managementModuleRecipesSubtitle
        case .movies: L10n.managementModuleMoviesSubtitle
        case .maintenance: L10n.managementModuleMaintenanceSubtitle
        case .finance: L10n.managementModuleFinanceSubtitle
        case .calendar: L10n.managementModuleCalendarSubtitle
        }
    }

    public var symbol: String {
        switch self {
        case .shopping: "cart.fill"
        case .recipes: "fork.knife"
        case .movies: "film.fill"
        case .maintenance: "wrench.adjustable.fill"
        case .finance: "dollarsign.circle.fill"
        case .calendar: "calendar"
        }
    }

    public var tint: Color {
        switch self {
        case .shopping: Palette.success
        case .recipes: Palette.warning
        case .movies: Palette.violet
        case .maintenance: Palette.cyan
        case .finance: Palette.indigo
        case .calendar: Palette.danger
        }
    }

    public var isAvailable: Bool {
        switch self {
        case .shopping, .recipes, .movies: true
        case .maintenance, .finance, .calendar: false
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension HubFeature.Path.State: Equatable {}
