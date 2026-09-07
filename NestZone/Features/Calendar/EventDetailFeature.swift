import ComposableArchitecture
import Foundation
import SwiftUI

/// One event, and everything the household has to get ready for it.
///
/// The screen is two halves. The top is the event — when, where, who is coming,
/// what it repeats as. The bottom is the *plan*: what it costs against what was
/// budgeted, what still has to be bought, and what is being cooked. Those three
/// live in Finance, Shopping and Recipes respectively, and this screen does not
/// copy any of them — `events:detail` rolls them up in one subscription, so the
/// number at the top of a card and the rows underneath it are computed from the
/// same read and cannot drift apart.
@Reducer
public struct EventDetailFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var occurrence: EventOccurrence
        public var members: IdentifiedArrayOf<User>
        public var currentUserID: UserID?

        /// The rollup. `nil` until the first push, and again if the event is
        /// deleted from another device while this sheet is open.
        public var plan: EventPlan?
        public var isLoadingPlan = true

        /// Freeform "and get some ice" field under the shopping list.
        public var newItem = ""
        /// Whether the plan's two long lists are showing every row.
        ///
        /// Both open collapsed, because a detail sheet is a summary and forty
        /// shopping lines stacked above the add field is not one. What was
        /// wrong was not the fold but the label on it: the remainder was
        /// printed as plain text, so "+8 more items" named eight things and
        /// gave no way whatsoever to reach them.
        public var isShoppingExpanded = false
        public var isExpensesExpanded = false
        public var isStockingUp = false
        public var isAddingItem = false
        /// Items whose tick is in flight, so a second tap cannot race the first.
        public var toggling: Set<ShoppingItemID> = []
        /// What the last bulk add did, so the button can say "8 added, 3 already
        /// on the list" instead of appearing to have done nothing.
        public var lastStockUp: StockUpResult?
        /// Series whose RSVP is in flight.
        public var isAnsweringRSVP = false
        /// Setting this event as the household's dinner is in flight.
        public var isPlanningDinner = false
        /// Set once it has been, so the button can say so rather than looking
        /// like it did nothing. Cleared by nothing — the sheet is short-lived,
        /// and the Home tab is where the answer actually lives.
        public var didPlanDinner = false

        @Presents public var expense: ExpenseComposerFeature.State?
        @Presents public var scopeDialog: ConfirmationDialogState<Action.Scope>?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            occurrence: EventOccurrence,
            members: IdentifiedArrayOf<User>,
            currentUserID: UserID?
        ) {
            self.occurrence = occurrence
            self.members = members
            self.currentUserID = currentUserID
        }

        // MARK: Derived

        public var myRSVP: RSVPStatus? { occurrence.rsvp(of: currentUserID) }

        public func name(for id: UserID?) -> String {
            guard let id else { return String(localized: L10n.calendarSomeone) }
            if id == currentUserID { return String(localized: L10n.financeYou) }
            return members[id: id]?.displayName ?? String(localized: L10n.calendarSomeone)
        }

        /// Everyone expected, with the answer they gave. Attendees first, then
        /// anybody who answered without being invited — which is a normal thing
        /// to happen in a house.
        public var roster: [(user: UserID, status: RSVPStatus?)] {
            var seen = Set<UserID>()
            var rows: [(UserID, RSVPStatus?)] = []
            for id in occurrence.attendees where seen.insert(id).inserted {
                rows.append((id, occurrence.rsvp(of: id)))
            }
            for rsvp in occurrence.rsvps where seen.insert(rsvp.userID).inserted {
                rows.append((rsvp.userID, rsvp.status))
            }
            return rows
        }

        public var goingCount: Int { occurrence.going.count }

        /// The currency the plan's money is written in — the budget's own, or
        /// whatever the linked expenses used.
        public var planCurrency: String {
            plan?.currency ?? occurrence.currency ?? Money.deviceDefault
        }

        /// How many rows each collapsed list shows before it folds.
        ///
        /// The shopping list sorts unbought first, so a collapsed list is the
        /// twelve things still to buy rather than an arbitrary dozen.
        static let shoppingPreview = 12
        static let expensePreview = 6

        public var shopping: [EventPlan.LinkedItem] { plan?.shopping ?? [] }
        public var expenses: [EventPlan.LinkedExpense] { plan?.expenses ?? [] }

        public var visibleShopping: [EventPlan.LinkedItem] {
            isShoppingExpanded ? shopping : Array(shopping.prefix(Self.shoppingPreview))
        }

        public var hiddenShoppingCount: Int {
            max(0, shopping.count - Self.shoppingPreview)
        }

        public var visibleExpenses: [EventPlan.LinkedExpense] {
            isExpensesExpanded ? expenses : Array(expenses.prefix(Self.expensePreview))
        }

        public var hiddenExpenseCount: Int {
            max(0, expenses.count - Self.expensePreview)
        }

        /// Whether this event is being planned at all.
        ///
        /// The test for showing an empty shopping card: an event with a budget,
        /// a menu or a ticket is one somebody is organising, and organising it
        /// means remembering to buy the ice. An event with none of those gets
        /// the invitation instead of four empty cards.
        public var isPlanned: Bool {
            occurrence.budget != nil
                || !occurrence.recipeIDs.isEmpty
                || occurrence.url?.isEmpty == false
                || (plan?.shoppingTotal ?? 0) > 0
                || !(plan?.expenses.isEmpty ?? true)
        }

        /// Which plan cards to draw. An event with nothing planned shows the
        /// invitation to plan one instead of four empty cards.
        public var visibleSections: [PlanSection] {
            var sections: [PlanSection] = []
            if occurrence.budget != nil || !(plan?.expenses.isEmpty ?? true) {
                sections.append(.budget)
            }
            // Shown empty on a planned event, and only there.
            //
            // The add field lives inside this card, so gating it on the list
            // already having something in it made the first item impossible to
            // add from here — the one place somebody is actually looking at the
            // event and remembering what it needs.
            if (plan?.shoppingTotal ?? 0) > 0 || isPlanned { sections.append(.shopping) }
            if !occurrence.recipeIDs.isEmpty { sections.append(.menu) }
            if occurrence.url?.isEmpty == false { sections.append(.tickets) }
            return sections
        }

        public var hasPlan: Bool { !visibleSections.isEmpty }

        /// Whether "stock up" has anything left to do.
        ///
        /// The server counts the menu's ingredients that are not yet on the
        /// household's list, because nothing here can: a `MenuRecipe` carries a
        /// count and not the names. Without it the button stayed lit on a menu
        /// that was fully bought in, and pressing it spent a round trip to be
        /// told everything was already listed — a control whose only outcome is
        /// "that did nothing" should not look like a control.
        public var canStockUp: Bool {
            guard let plan, !plan.recipes.isEmpty else { return false }
            return plan.stockUpPending > 0
        }

        /// The menu has recipes but nothing has been sent to the shopping list
        /// yet — the one moment "stock up" is the obvious next thing to do.
        public var suggestsStockUp: Bool {
            guard let plan, !plan.recipes.isEmpty, canStockUp else { return false }
            return plan.shoppingTotal == 0
        }

        /// Whether "make it dinner" makes sense here.
        ///
        /// A menu and a single day. A three-day trip has no one dinner to be,
        /// and a meal plan is one row per home per *day* — offering it on a
        /// multi-day event would silently pick one of them.
        public var canPlanDinner: Bool {
            !occurrence.recipeIDs.isEmpty && !occurrence.isMultiDay && !occurrence.isPast
        }

        /// The day it would be dinner on.
        public var dinnerDay: String { MealDate.key(occurrence.start) }

        /// Whether *this occurrence's* day is already the household's dinner.
        ///
        /// Read off the plan rather than remembered locally. `didPlanDinner`
        /// only ever knew about a press in this sheet, so reopening an event
        /// offered to make it dinner all over again — and on a repeating event
        /// every occurrence looked equally undecided, because the one that had
        /// been set left no mark on the others.
        public var isDinnerAlready: Bool {
            plan?.dinnerDays.contains(dinnerDay) ?? false
        }

        /// Settled, either because it already was or because it just became so.
        public var isDinner: Bool { didPlanDinner || isDinnerAlready }

        public var ticketURL: URL? {
            guard let raw = occurrence.url?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { return nil }
            // A link somebody pasted from a chat rarely carries its scheme.
            if let url = URL(string: raw), url.scheme != nil { return url }
            return URL(string: "https://\(raw)")
        }
    }

    public enum Action: BindableAction {
        case task
        case planUpdated(EventPlan?)
        case planFailed(AppError)

        case rsvpTapped(RSVPStatus)
        case rsvpFailed([EventRSVP], AppError)

        case itemToggled(ShoppingItemID, Bool)
        case itemToggleFailed(ShoppingItemID, Bool, AppError)
        case addItemTapped
        case stockUpTapped
        case bulkAddFinished(StockUpResult)
        case writeFailed(AppError)
        case shoppingExpandToggled
        case expensesExpandToggled

        case addExpenseTapped
        case planAsDinnerTapped
        case dinnerPlanned
        case editTapped
        case deleteTapped
        case openURLTapped

        case expense(PresentationAction<ExpenseComposerFeature.Action>)
        case scopeDialog(PresentationAction<Scope>)
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case delegate(Delegate)

        public enum Scope: Equatable {
            case editThisOne
            case editAll
            case deleteThisOne
            case deleteAll
        }

        public enum Alert: Equatable {}

        public enum Delegate: Equatable {
            case edit(EventOccurrence, EventScope)
            case deleted(EventOccurrence, EventScope)
            /// Hands the answer back so the grid behind the sheet agrees the
            /// moment it closes, rather than waiting for the next push.
            case rsvpChanged(EventID, [EventRSVP])
        }
    }

    private enum CancelID { case plan }

    @Dependency(\.events) var events
    @Dependency(\.shopping) var shopping
    @Dependency(\.meals) var meals
    @Dependency(\.openURL) var openURL

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                let id = state.occurrence.eventID
                return .run { send in
                    for try await plan in events.plan(id) {
                        await send(.planUpdated(plan))
                    }
                } catch: { error, send in
                    await send(.planFailed(AppError(error)))
                }
                .cancellable(id: CancelID.plan, cancelInFlight: true)

            case let .planUpdated(plan):
                state.isLoadingPlan = false
                guard plan != state.plan else { return .none }
                state.plan = plan
                return .none

            case let .planFailed(error):
                state.isLoadingPlan = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // MARK: RSVP
            //
            // Optimistic, with a real rollback: a refused write changed nothing
            // on the server, so no push is coming to correct the button.

            case let .rsvpTapped(status):
                guard let userID = state.currentUserID, !state.isAnsweringRSVP else {
                    return .none
                }
                let previous = state.occurrence.rsvps
                // Tapping the answer you already gave withdraws it, which is the
                // only way back to undecided.
                let next: RSVPStatus? = state.myRSVP == status ? nil : status
                let eventID = state.occurrence.eventID

                state.isAnsweringRSVP = true
                var rsvps = previous.filter { $0.userID != userID }
                if let next { rsvps.append(EventRSVP(userID: userID, status: next)) }
                state.occurrence.rsvps = rsvps

                return .merge(
                    .send(.delegate(.rsvpChanged(eventID, rsvps))),
                    .run { send in
                        try await events.rsvp(eventID, next)
                    } catch: { error, send in
                        await send(.rsvpFailed(previous, AppError(error)))
                    }
                )

            case let .rsvpFailed(previous, error):
                state.isAnsweringRSVP = false
                state.occurrence.rsvps = previous
                return .merge(
                    .send(.delegate(.rsvpChanged(state.occurrence.eventID, previous))),
                    .send(.writeFailed(error))
                )

            // MARK: Shopping

            case let .itemToggled(id, purchased):
                guard !state.toggling.contains(id) else { return .none }
                state.toggling.insert(id)
                // Optimistic on the rolled-up copy. The subscription will agree
                // in a moment; until then the tick has to move under the finger.
                setPurchased(&state, id, purchased)
                return .run { _ in
                    try await shopping.setPurchased(id, purchased)
                } catch: { error, send in
                    await send(.itemToggleFailed(id, !purchased, AppError(error)))
                }

            case let .itemToggleFailed(id, restored, error):
                state.toggling.remove(id)
                setPurchased(&state, id, restored)
                return .send(.writeFailed(error))

            case .addItemTapped:
                let name = state.newItem.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !state.isAddingItem else { return .none }
                state.isAddingItem = true
                // Cleared now rather than on success: the field is the input, and
                // a line that lingers after Return reads as a key that did not
                // take. If the write fails the text comes back with the error.
                state.newItem = ""
                let id = state.occurrence.eventID
                return .run { send in
                    let result = try await events.addItems(id, [name], nil)
                    await send(.bulkAddFinished(result))
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case .stockUpTapped:
                guard !state.isStockingUp else { return .none }
                state.isStockingUp = true
                let id = state.occurrence.eventID
                return .run { send in
                    let result = try await events.stockUp(id, .groceries)
                    await send(.bulkAddFinished(result))
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case let .bulkAddFinished(result):
                state.isStockingUp = false
                state.isAddingItem = false
                // Kept so the button can report what happened. `skipped` is the
                // interesting half — without it, adding a menu whose ingredients
                // are all already on the list looks like a dead button.
                state.lastStockUp = result
                return .none

            case let .writeFailed(error):
                state.isStockingUp = false
                state.isAddingItem = false
                state.isPlanningDinner = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .shoppingExpandToggled:
                state.isShoppingExpanded.toggle()
                return .none

            case .expensesExpandToggled:
                state.isExpensesExpanded.toggle()
                return .none

            // MARK: Money

            case .addExpenseTapped:
                // The Finance composer, unchanged, carrying the link. Money for
                // an event is an ordinary expense that happens to know what it
                // was for — a second, simpler composer here would be a second
                // splitting model to keep in step with the server's.
                state.expense = ExpenseComposerFeature.State(
                    homeID: state.occurrence.homeID ?? HomeID(""),
                    members: state.members,
                    currentUserID: state.currentUserID,
                    currency: state.planCurrency,
                    knownCurrencies: state.plan?.currencies ?? [],
                    // Dated to the event rather than to today: an expense logged
                    // the morning after a party belongs to the party.
                    defaultDate: state.occurrence.start,
                    eventID: state.occurrence.eventID,
                    suggestedTitle: state.occurrence.title
                )
                return .none

            case .expense(.presented(.delegate(.saved))):
                state.expense = nil
                // Nothing is inserted by hand: the plan is a live query, and the
                // new expense arrives through it.
                return .none

            // MARK: Dinner
            //
            // The other half of the link the Dinner sheet writes when somebody
            // makes a meal "an occasion". Both directions set one field —
            // `meal_plans.event_id` — because a dinner party is a meal *and* an
            // event, and the alternative is two copies of the menu that can
            // disagree.

            case .planAsDinnerTapped:
                guard state.canPlanDinner, !state.isPlanningDinner else { return .none }
                state.isPlanningDinner = true
                let homeID = state.occurrence.homeID ?? HomeID("")
                let day = state.dinnerDay
                let eventID = state.occurrence.eventID
                // The first course is what the card shows. A menu of four is
                // still one dinner, and the event is one tap away for the rest.
                let recipeID = state.plan?.recipes.first?.id ?? state.occurrence.recipeIDs.first
                let title = state.occurrence.title

                return .run { send in
                    try await meals.set(DinnerDecision(
                        homeID: homeID,
                        date: day,
                        kind: .cook,
                        recipeID: recipeID,
                        // A menu whose recipes have all been deleted still names
                        // a dinner: the event's own title stands in, which is
                        // what `meals:set` accepts for a recipe-less cook plan.
                        title: recipeID == nil ? title : nil,
                        eventID: eventID
                    ))
                    await send(.dinnerPlanned)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case .dinnerPlanned:
                state.isPlanningDinner = false
                state.didPlanDinner = true
                return .none

            // MARK: Editing

            case .editTapped:
                guard state.occurrence.isRecurring else {
                    return .send(.delegate(.edit(state.occurrence, .series)))
                }
                state.scopeDialog = .detailEditScope()
                return .none

            case .scopeDialog(.presented(.editThisOne)):
                return .send(.delegate(.edit(state.occurrence, .occurrence)))

            case .scopeDialog(.presented(.editAll)):
                return .send(.delegate(.edit(state.occurrence, .series)))

            case .deleteTapped:
                guard state.occurrence.isRecurring else {
                    return .send(.delegate(.deleted(state.occurrence, .series)))
                }
                state.scopeDialog = .detailDeleteScope()
                return .none

            case .scopeDialog(.presented(.deleteThisOne)):
                return .send(.delegate(.deleted(state.occurrence, .occurrence)))

            case .scopeDialog(.presented(.deleteAll)):
                return .send(.delegate(.deleted(state.occurrence, .series)))

            case .openURLTapped:
                guard let url = state.ticketURL else { return .none }
                return .run { _ in await openURL(url) }

            case .binding, .expense, .scopeDialog, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$expense, action: \.expense) { ExpenseComposerFeature() }
        .ifLet(\.$scopeDialog, action: \.scopeDialog)
        .ifLet(\.$alert, action: \.alert)
    }

    /// Moves one tick on the rolled-up copy, and the two counters that are
    /// drawn from it.
    ///
    /// The plan arrives pre-totalled from the server, so an optimistic tick has
    /// to move the total as well as the row — otherwise the ring says "4 of 11"
    /// over a list showing five ticked, for as long as the round trip takes.
    private func setPurchased(_ state: inout State, _ id: ShoppingItemID, _ purchased: Bool) {
        guard var plan = state.plan,
              let index = plan.shopping.firstIndex(where: { $0.id == id }),
              plan.shopping[index].isPurchased != purchased else { return }
        plan.shopping[index].isPurchased = purchased
        plan.shoppingPurchased += purchased ? 1 : -1
        state.plan = plan
    }
}

// MARK: - Scope dialogs

extension ConfirmationDialogState where Action == EventDetailFeature.Action.Scope {
    static func detailEditScope() -> Self {
        ConfirmationDialogState {
            TextState(String(localized: L10n.calendarScopeEditTitle))
        } actions: {
            ButtonState(action: .editThisOne) {
                TextState(String(localized: L10n.calendarScopeThisEvent))
            }
            ButtonState(action: .editAll) {
                TextState(String(localized: L10n.calendarScopeAllEvents))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.calendarScopeEditMessage))
        }
    }

    static func detailDeleteScope() -> Self {
        ConfirmationDialogState {
            TextState(String(localized: L10n.calendarScopeDeleteTitle))
        } actions: {
            ButtonState(role: .destructive, action: .deleteThisOne) {
                TextState(String(localized: L10n.calendarScopeThisEvent))
            }
            ButtonState(role: .destructive, action: .deleteAll) {
                TextState(String(localized: L10n.calendarScopeAllEvents))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.calendarScopeDeleteMessage))
        }
    }
}
