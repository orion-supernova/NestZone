import ComposableArchitecture
import Foundation
import SwiftUI

/// The "Hub" tab: a grid of the household's modules, and the screens they open.
@Reducer
public struct HubFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking. The Finance module needs it — a balance is only
        /// meaningful as somebody's.
        public var currentUserID: UserID?
        public var path = StackState<Path.State>()
        /// Live counts for the module tiles, so each card shows something real
        /// rather than a static subtitle.
        public var shoppingCount = 0
        public var recipeCount = 0
        public var movieCount = 0
        /// Bills already due or due within the week. Not "how many bills" —
        /// a tile is worth reading only when its number is asking for
        /// something.
        public var billsDueCount = 0

        public init(homeID: HomeID, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.currentUserID = currentUserID
        }
    }

    @Reducer
    public enum Path {
        case shopping(ShoppingFeature)
        case recipes(RecipesFeature)
        case movies(MoviesFeature)
        case finance(FinanceFeature)
    }

    public enum Action {
        case task
        case countsUpdated(shopping: Int?, recipes: Int?, movies: Int?, billsDue: Int?)
        case moduleTapped(HubModule)
        case showShoppingList
        case path(StackActionOf<Path>)
    }

    private enum CancelID { case shopping, recipes, movies, bills, handoff }

    /// Roughly one navigation transition. There is no completion callback for a
    /// `StackState` pop, so the push that follows one has to wait it out.
    private static let unwind: Duration = .milliseconds(350)

    @Dependency(\.shopping) var shoppingClient
    @Dependency(\.recipes) var recipesClient
    @Dependency(\.movies) var moviesClient
    @Dependency(\.finance) var financeClient
    @Dependency(\.continuousClock) var clock

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
                                recipes: nil, movies: nil, billsDue: nil
                            ))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.shopping, cancelInFlight: true),

                    .run { send in
                        for try await recipes in recipesClient.byHome(homeID) {
                            await send(.countsUpdated(
                                shopping: nil, recipes: recipes.count, movies: nil, billsDue: nil
                            ))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.recipes, cancelInFlight: true),

                    .run { send in
                        for try await movies in moviesClient.allMovies(homeID) {
                            await send(.countsUpdated(
                                shopping: nil, recipes: nil, movies: movies.count, billsDue: nil
                            ))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.movies, cancelInFlight: true),

                    .run { send in
                        for try await bills in financeClient.bills(homeID) {
                            await send(.countsUpdated(
                                shopping: nil, recipes: nil, movies: nil,
                                billsDue: bills.filter { $0.urgency() <= .dueSoon }.count
                            ))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.bills, cancelInFlight: true)
                )

            case let .countsUpdated(shopping, recipes, movies, billsDue):
                if let shopping { state.shoppingCount = shopping }
                if let recipes { state.recipeCount = recipes }
                if let movies { state.movieCount = movies }
                if let billsDue { state.billsDueCount = billsDue }
                return .none

            case let .moduleTapped(module):
                switch module {
                case .shopping:
                    state.path.append(.shopping(ShoppingFeature.State(homeID: state.homeID)))
                case .recipes:
                    state.path.append(.recipes(RecipesFeature.State(homeID: state.homeID)))
                case .movies:
                    state.path.append(.movies(MoviesFeature.State(homeID: state.homeID)))
                case .finance:
                    state.path.append(.finance(FinanceFeature.State(
                        homeID: state.homeID,
                        currentUserID: state.currentUserID
                    )))
                case .maintenance, .calendar:
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

            // A recipe asking for the shopping list: back out to the Hub, then
            // push the list — rather than stacking one module inside another.
            //
            // Unwind first and push second, never both in one pass. The recipe
            // screen presents its detail with `navigationDestination(item:)`
            // *inside* the stack this `path` drives, so by the time this action
            // arrives one destination is already being dismissed. Popping the
            // recipe screen and pushing the list on top of that asked SwiftUI to
            // unwind two levels and push a third in a single update, which it
            // does not do: it left the recipe on screen while the state said
            // "shopping", the detached views re-ran their `task` into elements
            // that no longer existed, and a second tap went nowhere at all.
            // Unwinding several levels at once is fine; it is the push in the
            // same breath that it cannot reconcile.
            case let .path(.element(id: id, action: .recipes(.delegate(.openShoppingList)))):
                state.path.pop(from: id)
                return .run { send in
                    try await clock.sleep(for: Self.unwind)
                    await send(.showShoppingList)
                }
                .cancellable(id: CancelID.handoff, cancelInFlight: true)

            case .showShoppingList:
                // If the person went somewhere else while the pop was playing,
                // leave them there rather than yanking them to the list.
                guard state.path.isEmpty else { return .none }
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
        case .shopping, .recipes, .movies, .finance: true
        case .maintenance, .calendar: false
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension HubFeature.Path.State: Equatable {}
