import ComposableArchitecture
import Foundation

/// Deciding what the household is doing about dinner.
///
/// Dinner is a decision before it is a dish, so the flow asks that first —
/// cook, order in, or go out — and only then asks what. Cooking picks from the
/// home's own recipes; the other two pick a cuisine and, optionally, a place.
///
/// The plan itself is one row per home per day (`meals:set` replaces rather
/// than stacks), so this screen is always editing "tonight", never appending.
@Reducer
public struct DinnerFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var date: String
        public var memberCount: Int
        /// Nil while the first question is still on screen: decide it yourself,
        /// or put it to the household.
        public var route: Route?
        /// Nil while the second question is still on screen.
        public var kind: MealPlan.Kind?
        /// What was chosen last time, so the kind picker can mark it.
        public var prefilledKind: MealPlan.Kind?
        public var recipes: IdentifiedArrayOf<Recipe> = []
        /// The bundled catalogue, so a household with an empty shelf can still
        /// answer "what are we cooking".
        public var samples: IdentifiedArrayOf<Recipe> = []
        public var source: Source = .saved
        public var isLoadingRecipes = true
        public var search = ""
        /// Tags the candidates must carry — "dinner" being the one that earns
        /// its keep here. Empty means everything.
        public var tags: Set<String> = []
        /// The chosen recipe rather than its id: an Explore recipe has no
        /// server id yet, and cannot be reduced to one until it is saved.
        public var selection: Recipe?
        /// A meal nobody wrote down. "Leftovers" is a perfectly good answer and
        /// does not deserve a recipe row.
        public var customTitle = ""
        public var selectedCuisine: Cuisine?
        public var place = ""
        public var isSaving = false
        /// Everything on the ballot, in the order it was added. Only used on
        /// the voting route.
        public var ballot: [DinnerCandidate] = []
        public var isStartingRound = false
        /// The open dinner round, if the household has one.
        public var poll: Poll?
        public var detail: PollDetail?
        /// Locally-cast votes, so a card leaves the deck immediately rather
        /// than waiting for the round trip.
        public var voted: Set<String> = []
        /// What was already decided for this day, if anything. Kept so the
        /// screen can say so plainly rather than silently overwriting it.
        public var existing: MealPlan?
        @Presents public var alert: AlertState<Action.Alert>?

        /// Decide it, or ask the house.
        public enum Route: String, Hashable, Sendable { case set, vote }

        public init(
            homeID: HomeID,
            date: String = MealDate.today,
            memberCount: Int = 1,
            existing: MealPlan? = nil
        ) {
            self.homeID = homeID
            self.date = date
            self.memberCount = memberCount
            // Re-deciding starts from what was already chosen rather than from
            // a blank screen.
            self.existing = existing
            if let existing {
                route = .set
                // Deliberately not `kind`: changing a decided dinner should
                // open on all three ways of answering, not inside the one that
                // was chosen last time, which stranded "order in" behind a Back
                // button.
                prefilledKind = existing.kind
                selection = existing.recipe
                customTitle = existing.title ?? ""
                if existing.recipe == nil, existing.title?.isEmpty == false {
                    source = .custom
                }
                selectedCuisine = existing.cuisine
                place = existing.place ?? ""
            }
        }

        /// Where the cooking candidates come from.
        public enum Source: String, CaseIterable, Hashable, Sendable {
            case saved, explore, custom

            public var title: LocalizedStringResource {
                switch self {
                case .saved: L10n.dinnerSourceSaved
                case .explore: L10n.dinnerSourceExplore
                case .custom: L10n.dinnerSourceCustom
                }
            }
        }

        /// Tags worth filtering a dinner by, and only those the candidates
        /// actually carry — an empty filter chip is worse than no chip.
        public var availableTags: [String] {
            let present = Set(candidates.flatMap(\.tags).map { $0.lowercased() })
            return RecipeTag.suggestions.filter(present.contains)
        }

        private var candidates: [Recipe] {
            switch source {
            case .saved: recipes.elements
            case .explore: samples.elements
            case .custom: []
            }
        }

        public var trimmedCustomTitle: String {
            customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public var matchingRecipes: [Recipe] {
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            return candidates
                .filter { recipe in
                    guard tags.isEmpty else {
                        let carried = Set(recipe.tags.map { $0.lowercased() })
                        return tags.isSubset(of: carried)
                    }
                    return true
                }
                .filter { recipe in
                    query.isEmpty
                        || recipe.title.localizedCaseInsensitiveContains(query)
                        || recipe.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                }
                .sorted { Timestamp.newestFirst($0.created, $1.created) }
        }

        /// Saved is the natural default, but not for a household that has not
        /// saved anything — that lands on an empty screen with a filter bar.
        public var isSourceEmpty: Bool { candidates.isEmpty }

        public var hasOpenRound: Bool { poll?.isOpen == true }

        /// Candidates this member has not voted on yet.
        public var deck: [DinnerCandidate] {
            (detail?.items ?? [])
                .compactMap { DinnerCandidate(externalID: $0.externalID, label: $0.label) }
                .filter { !voted.contains($0.id) }
        }

        /// Everyone said yes. The first one is what the household is eating.
        public var matches: [DinnerCandidate] {
            (detail?.matches(memberCount: memberCount) ?? [])
                .compactMap { DinnerCandidate(externalID: $0.externalID, label: $0.label) }
        }

        public var isDeckFinished: Bool { hasOpenRound && deck.isEmpty }

        /// A vote needs something to choose between.
        public var canStartRound: Bool { !isStartingRound && ballot.count >= 2 }

        public func isOnBallot(_ candidate: DinnerCandidate) -> Bool {
            ballot.contains { $0.id == candidate.id }
        }

        /// Cooking needs a recipe; the other two need a cuisine. A place on its
        /// own is not enough to answer "what are we eating".
        public var canSave: Bool {
            guard !isSaving else { return false }
            return switch kind {
            case .cook: source == .custom ? !trimmedCustomTitle.isEmpty : selection != nil
            case .order, .out: selectedCuisine != nil
            case nil: false
            }
        }
    }

    // Equatable so the Home tab, whose own action type is, can present it.
    public enum Action: Equatable, BindableAction {
        case task
        case recipesUpdated([Recipe])
        case samplesLoaded([Recipe])
        case sourceChanged(State.Source)
        case tagToggled(String)
        case routeChosen(State.Route)
        case kindChosen(MealPlan.Kind)
        case backTapped
        case pollsUpdated([Poll])
        case detailUpdated(PollDetail)
        case ballotToggled(DinnerCandidate)
        case customAdded
        case startRoundTapped
        case roundStarted(PollID)
        case voted(DinnerCandidate, isYes: Bool)
        case matchAccepted(DinnerCandidate)
        case recipeChosen(Recipe)
        case cuisineChosen(Cuisine)
        case saveTapped
        case saved
        case voteFailed(DinnerCandidate.ID, AppError)
        case failed(AppError)
        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {}

        @CasePathable
        public enum Delegate: Equatable {
            case finished
        }
    }

    private enum CancelID { case recipes, polls, detail }

    @Dependency(\.recipes) var recipesClient
    @Dependency(\.meals) var meals
    @Dependency(\.polls) var pollsClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                // Only the cooking branch needs these, but the subscription is
                // opened up front so choosing "cook" lands on a full list
                // instead of a spinner.
                return .merge(
                    .run { [homeID = state.homeID] send in
                        for try await recipes in recipesClient.byHome(homeID) {
                            await send(.recipesUpdated(recipes))
                        }
                    } catch: { _, send in
                        // An empty list is handled on screen; a failed one reads
                        // the same way and is not worth an alert over a picker.
                        // It must still land, though — without this the cook
                        // branch sat on a skeleton list forever.
                        await send(.recipesUpdated([]))
                    }
                    .cancellable(id: CancelID.recipes, cancelInFlight: true),

                    .run { send in
                        await send(.samplesLoaded(recipesClient.samples()))
                    },

                    .run { [homeID = state.homeID] send in
                        for try await polls in pollsClient.byHome(homeID) {
                            await send(.pollsUpdated(polls))
                        }
                    } catch: { _, _ in
                        // No round is the normal case.
                    }
                    .cancellable(id: CancelID.polls, cancelInFlight: true)
                )

            case let .recipesUpdated(recipes):
                state.isLoadingRecipes = false
                state.recipes = IdentifiedArray(uniqueElements: recipes)
                // A household with nothing saved would otherwise open on an
                // empty shelf; the catalogue is the better first answer.
                if recipes.isEmpty, state.selection == nil, state.source == .saved {
                    state.source = .explore
                }
                return .none

            case let .samplesLoaded(samples):
                state.samples = IdentifiedArray(uniqueElements: samples)
                return .none

            case let .sourceChanged(source):
                state.source = source
                // The two ways of answering are exclusive: a typed name and a
                // chosen recipe must never both be live, or the save would have
                // to guess which the cook meant.
                if source == .custom {
                    state.selection = nil
                } else {
                    state.customTitle = ""
                }
                // Tags are per-source: "soup" may exist in one shelf and not
                // the other, and a filter matching nothing looks like a bug.
                state.tags = state.tags.filter(state.availableTags.contains)
                return .none

            case let .tagToggled(tag):
                if state.tags.contains(tag) {
                    state.tags.remove(tag)
                } else {
                    state.tags.insert(tag)
                }
                return .none

            case let .routeChosen(route):
                state.route = route
                return .none

            case let .kindChosen(kind):
                let previous = state.kind
                state.kind = kind
                // Switching between cooking and eating out mid-flow: what was
                // picked for the old answer cannot travel to the new one.
                if previous != nil, previous != kind {
                    state.selection = nil
                    state.selectedCuisine = nil
                    state.customTitle = ""
                    state.ballot.removeAll()
                }
                return .none

            case .backTapped:
                if state.kind != nil {
                    state.kind = nil
                } else {
                    state.route = nil
                }
                return .none

            case let .pollsUpdated(polls):
                // A dinner round and a movie night are the same machinery; the
                // entity kind is what tells them apart.
                let open = polls.first { $0.isOpen && $0.kind == .recipe }
                state.poll = open
                guard let open else {
                    state.detail = nil
                    return .cancel(id: CancelID.detail)
                }
                return .run { send in
                    for try await detail in pollsClient.detail(open.id) {
                        await send(.detailUpdated(detail))
                    }
                } catch: { _, _ in
                }
                .cancellable(id: CancelID.detail, cancelInFlight: true)

            case let .detailUpdated(detail):
                state.detail = detail
                return .none

            case let .ballotToggled(candidate):
                if let index = state.ballot.firstIndex(where: { $0.id == candidate.id }) {
                    state.ballot.remove(at: index)
                } else {
                    state.ballot.append(candidate)
                }
                return .none

            case .customAdded:
                let typed = state.trimmedCustomTitle
                guard !typed.isEmpty else { return .none }
                let candidate = DinnerCandidate(kind: .custom, value: typed, label: typed)
                if !state.isOnBallot(candidate) { state.ballot.append(candidate) }
                state.customTitle = ""
                return .none

            case .startRoundTapped:
                guard state.canStartRound else { return .none }
                state.isStartingRound = true
                return .run { [homeID = state.homeID, ballot = state.ballot] send in
                    let id = try await pollsClient.create(
                        homeID,
                        String(localized: L10n.dinnerRoundTitle),
                        .recipe,
                        nil,
                        ballot.map(\.pollCandidate)
                    )
                    await send(.roundStarted(id))
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case .roundStarted:
                state.isStartingRound = false
                state.ballot = []
                // The live `polls:listByHome` subscription brings the round
                // back as the open one, which is what switches the screen.
                return .none

            case let .voted(candidate, isYes):
                guard let pollID = state.poll?.id else { return .none }
                // Optimistic, and taken back if the vote is refused: the
                // ballot would otherwise show as answered for the rest of the
                // round with nothing recorded behind it.
                let candidateID = candidate.id
                state.voted.insert(candidateID)
                return .run { send in
                    try await pollsClient.vote(pollID, candidateID, isYes)
                } catch: { error, send in
                    await send(.voteFailed(candidateID, AppError(error)))
                }

            case let .matchAccepted(candidate):
                guard let kind = state.kind ?? state.poll.map({ _ in MealPlan.Kind.cook }) else {
                    return .none
                }
                state.isSaving = true
                return .run { [homeID = state.homeID, date = state.date, pollID = state.poll?.id] send in
                    var decision = candidate.decision(homeID: homeID, kind: kind)
                    decision.date = date
                    try await meals.set(decision)
                    // The round has served its purpose; leaving it open would
                    // keep asking a question the household has answered.
                    if let pollID { try await pollsClient.close(pollID) }
                    await send(.saved)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .recipeChosen(recipe):
                // Tapping the chosen one again lets go of it.
                state.selection = state.selection?.id == recipe.id ? nil : recipe
                return .none

            case let .cuisineChosen(cuisine):
                state.selectedCuisine = state.selectedCuisine == cuisine ? nil : cuisine
                return .none

            case .saveTapped:
                guard state.canSave, let kind = state.kind else { return .none }
                state.isSaving = true
                // Captured piecewise: `State` holds `@Presents` and `@Shared`
                // storage and is not `Sendable`, so the effect takes only the
                // values it needs.
                return .run { [
                    homeID = state.homeID,
                    date = state.date,
                    chosen = state.selection,
                    customTitle = state.trimmedCustomTitle,
                    cuisine = state.selectedCuisine,
                    place = state.place
                ] send in
                    // A plan points at a `recipes` row, and an Explore recipe is
                    // bundled with the app rather than stored — so cooking one
                    // saves it into the home first and plans the copy that now
                    // has an id. Which is what the cook wanted anyway.
                    var recipeID = chosen?.id
                    if kind == .cook, let chosen, chosen.isSample {
                        // `adopt`, not `create`: planning the same bundled dish
                        // a second time must land on the copy the home already
                        // has rather than stacking up another one.
                        recipeID = try await recipesClient.adopt(
                            NewRecipe(
                                title: chosen.title,
                                summary: chosen.summary,
                                ingredients: chosen.ingredients,
                                steps: chosen.steps,
                                tags: chosen.tags,
                                prepTime: chosen.prepTime,
                                cookTime: chosen.cookTime,
                                servings: chosen.servings,
                                difficulty: chosen.difficulty,
                                homeID: homeID
                            )
                        ).id
                    }

                    try await meals.set(
                        DinnerDecision(
                            homeID: homeID,
                            date: date,
                            kind: kind,
                            recipeID: kind == .cook ? recipeID : nil,
                            title: kind == .cook && recipeID == nil ? customTitle : nil,
                            cuisine: kind == .cook ? nil : cuisine,
                            place: kind == .cook ? nil : place
                        )
                    )
                    await send(.saved)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case .saved:
                state.isSaving = false
                // The Home tab's live subscription already has it.
                return .send(.delegate(.finished))

            case let .voteFailed(id, error):
                state.voted.remove(id)
                return .send(.failed(error))

            case let .failed(error):
                state.isSaving = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .binding, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension Cuisine {
    public var title: LocalizedStringResource {
        switch self {
        case .turkish: L10n.cuisineTurkish
        case .italian: L10n.cuisineItalian
        case .chinese: L10n.cuisineChinese
        case .japanese: L10n.cuisineJapanese
        case .indian: L10n.cuisineIndian
        case .mexican: L10n.cuisineMexican
        case .thai: L10n.cuisineThai
        case .mediterranean: L10n.cuisineMediterranean
        case .american: L10n.cuisineAmerican
        case .korean: L10n.cuisineKorean
        case .seafood: L10n.cuisineSeafood
        case .other: L10n.cuisineOther
        }
    }
}

extension MealPlan.Kind {
    public var title: LocalizedStringResource {
        switch self {
        case .cook: L10n.dinnerKindCook
        case .order: L10n.dinnerKindOrder
        case .out: L10n.dinnerKindOut
        }
    }

    public var subtitle: LocalizedStringResource {
        switch self {
        case .cook: L10n.dinnerKindCookSubtitle
        case .order: L10n.dinnerKindOrderSubtitle
        case .out: L10n.dinnerKindOutSubtitle
        }
    }

    public var symbol: String {
        switch self {
        case .cook: "frying.pan.fill"
        case .order: "bag.fill"
        case .out: "figure.walk"
        }
    }
}

/// One thing on the ballot of a dinner round.
///
/// Poll items carry only an `external_id`, a label and a thumbnail, so the kind
/// of candidate is encoded into the id — which is also what lets a winning vote
/// turn back into a meal plan without a second lookup.
public struct DinnerCandidate: Equatable, Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case recipe, cuisine, custom
    }

    public var kind: Kind
    /// The recipe id, cuisine raw value, or the typed text.
    public var value: String
    public var label: String

    public var id: String { "\(kind.rawValue):\(value)" }

    public init(kind: Kind, value: String, label: String) {
        self.kind = kind
        self.value = value
        self.label = label
    }

    public init(_ recipe: Recipe) {
        self.init(kind: .recipe, value: recipe.id.rawValue, label: recipe.title)
    }

    public init(_ cuisine: Cuisine) {
        self.init(
            kind: .cuisine,
            value: cuisine.rawValue,
            label: "\(cuisine.emoji)  \(String(localized: cuisine.title))"
        )
    }

    /// Rebuilt from a poll item's external id.
    public init?(externalID: String, label: String?) {
        let parts = externalID.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let kind = Kind(rawValue: String(parts[0])) else { return nil }
        self.kind = kind
        self.value = String(parts[1])
        self.label = label ?? String(parts[1])
    }

    public var pollCandidate: PollCandidate {
        PollCandidate(externalID: id, label: label)
    }

    /// What this candidate means once it wins.
    public func decision(homeID: HomeID, kind mealKind: MealPlan.Kind) -> DinnerDecision {
        switch self.kind {
        case .recipe:
            DinnerDecision(homeID: homeID, kind: .cook, recipeID: RecipeID(value))
        case .cuisine:
            DinnerDecision(
                homeID: homeID,
                kind: mealKind == .cook ? .order : mealKind,
                cuisine: Cuisine(rawValue: value)
            )
        case .custom:
            mealKind == .cook
                ? DinnerDecision(homeID: homeID, kind: .cook, title: label)
                : DinnerDecision(homeID: homeID, kind: mealKind, place: label)
        }
    }
}
