import ComposableArchitecture
import Foundation
import SwiftUI

// Adding or editing an event, and the recipe picker its menu section opens.
//
// The composer's one idea: an event is a time *plus a plan*, and which parts of
// the plan are worth showing depends on what kind of thing it is. A dinner party
// opens with a menu, a shopping list and a budget already unfolded; a dentist
// appointment opens with none of them. Everything is still one tap away from the
// plan menu — the kind is a guess, not a rule — but the guess is what keeps the
// form from being nineteen collapsed sections deep for every event anybody adds.

@Reducer
public struct EventComposerFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var members: IdentifiedArrayOf<User>
        public var currentUserID: UserID?
        /// The occurrence being edited, if this is an edit.
        public var editing: EventOccurrence?
        /// Whether an edit applies to the whole series or lifts one date out of
        /// it. Decided before saving, when the event repeats.
        public var scope: EventScope = .series

        public var title = ""
        public var notes = ""
        public var location = ""
        public var url = ""
        public var kind: EventKind = .general
        public var isAllDay = false
        public var startsAt: Date
        public var endsAt: Date

        public var attendees: Set<UserID> = []
        public var reminders: Set<EventReminder> = []

        /// The repeat rule, as three independent controls rather than a
        /// `Recurrence?` — the sheet has to remember "every 2 weeks on Tue" while
        /// the repeat is switched off, or turning it back on loses the answer.
        public var repeats = false
        public var frequency: Recurrence.Frequency = .weekly
        public var interval = 1
        public var weekdays: Set<Int> = []
        public var hasEnd = false
        public var until: Date

        /// Which optional halves of the plan are on screen.
        public var sections: Set<PlanSection> = []
        public var budgetText = ""
        public var currency: String = Money.deviceDefault
        public var recipeIDs: [RecipeID] = []

        /// Things to buy, typed before the event exists.
        ///
        /// Held here rather than written as they are typed, because a shopping
        /// item needs an event to belong to and there is not one yet. They are
        /// sent in a single `addItems` write once the event has an id — which
        /// is also why `create` and `update` hand one back.
        public var shoppingDraft: [String] = []
        public var newItem = ""

        /// The household's recipes, for the menu chips and the picker.
        ///
        /// Subscribed to only once the menu section is actually open. A
        /// household that is adding a dentist appointment never pays for this
        /// query at all.
        public var recipes: IdentifiedArrayOf<Recipe> = []
        /// The bundled Explore recipes, for a household that has not saved any
        /// of its own yet.
        ///
        /// Loaded from the app bundle, not the network: a new home planning its
        /// first dinner party should not find an empty picker and a dead end.
        /// Choosing one adopts it into the home first — see `.recipesAdopted`.
        public var samples: IdentifiedArrayOf<Recipe> = []
        public var isSubscribedToRecipes = false
        /// A sample being copied into the home. Brief, but it is a round trip,
        /// and the chip cannot appear until it has an id of its own.
        public var isAdoptingRecipes = false

        public var isSubmitting = false
        public var inlineError: String?
        /// Bumped to shake the field the sheet is refusing. A rejection has to
        /// be felt, not just read.
        public var shakes = 0

        @Presents public var picker: RecipePickerFeature.State?
        @Presents public var scopeDialog: ConfirmationDialogState<Action.Scope>?

        /// A starting point for an event being written *from* something else —
        /// a meal plan becoming an occasion, so far.
        ///
        /// Not an `editing:` occurrence: nothing exists yet, and the sheet must
        /// behave as a create (no delete button, no "this one or all of them").
        /// Everything here is a default the person can still change, which is
        /// the whole reason the composer is opened rather than the event being
        /// written behind their back.
        public struct Seed: Equatable, Sendable {
            public var kind: EventKind
            public var title: String
            public var startsAt: Date
            public var recipeIDs: [RecipeID]

            public init(
                kind: EventKind,
                title: String,
                startsAt: Date,
                recipeIDs: [RecipeID] = []
            ) {
                self.kind = kind
                self.title = title
                self.startsAt = startsAt
                self.recipeIDs = recipeIDs
            }
        }

        public init(
            homeID: HomeID,
            members: IdentifiedArrayOf<User>,
            currentUserID: UserID?,
            day: CalendarDay,
            editing: EventOccurrence? = nil,
            scope: EventScope = .series,
            seed: Seed? = nil
        ) {
            self.homeID = homeID
            self.members = members
            self.currentUserID = currentUserID
            self.editing = editing
            self.scope = scope

            // Every stored property is given a value before anything reads one.
            //
            // `@ObservableState` routes property access through the observation
            // registrar, so reading `currency` — or any other field — is a
            // *method call on self*, and the compiler will not allow that while
            // a stored property is still uninitialised. The three dates have no
            // default of their own, so they are seeded here and refined below.
            //
            // A new event lands on the day the calendar was showing, at the next
            // round hour, which is nearly always what somebody tapping "+" on a
            // Thursday meant.
            let start = editing?.start ?? State.defaultStart(on: day)
            self.startsAt = start
            self.endsAt = editing?.end ?? start.addingTimeInterval(EventKind.general.defaultDuration)
            self.until = editing?.recurrence?.until?.date
                ?? start.addingTimeInterval(365 * 24 * 3600)

            guard let editing else {
                // Everybody, until somebody says otherwise: a household event
                // that quietly excluded half the house would be worse than one
                // that has to be narrowed.
                attendees = Set(members.ids)
                reminders = [.oneHour]

                if let seed {
                    kind = seed.kind
                    title = seed.title
                    startsAt = seed.startsAt
                    endsAt = seed.startsAt.addingTimeInterval(seed.kind.defaultDuration)
                    recipeIDs = seed.recipeIDs
                    // What the kind would have suggested, plus a menu if one
                    // came with the seed — a dish already chosen is a menu
                    // whatever the taxonomy thinks.
                    sections = seed.kind.suggestedPlan
                    if !seed.recipeIDs.isEmpty { sections.insert(.menu) }
                    reminders = [.oneDay]
                }
                return
            }

            title = editing.title
            notes = editing.notes ?? ""
            location = editing.location ?? ""
            url = editing.url ?? ""
            kind = editing.kind
            isAllDay = editing.isAllDay
            attendees = Set(editing.attendees)
            reminders = Set(editing.reminderChoices)
            recipeIDs = editing.recipeIDs
            currency = editing.currency ?? Money.deviceDefault
            if let budget = editing.budget, budget > 0 {
                budgetText = Money.editableText(budget, currency: currency)
            }
            if let rule = editing.recurrence {
                repeats = true
                frequency = rule.frequency
                interval = rule.interval
                weekdays = Set(rule.weekdays)
                hasEnd = rule.until != nil
            }
            // Open on what the event actually has, not on what its kind usually
            // wants: reopening a party that nobody budgeted must not present an
            // empty budget field as though one had been set.
            sections = State.sectionsPresent(in: editing)
        }

        /// The next whole hour on `day`, or 9am if the day is not today.
        static func defaultStart(on day: CalendarDay, now: Date = .now) -> Date {
            let calendar = Calendar.current
            let midnight = day.date(calendar)
            guard day == CalendarDay(now, calendar: calendar) else {
                return calendar.date(byAdding: .hour, value: 9, to: midnight) ?? midnight
            }
            let hour = calendar.component(.hour, from: now)
            return calendar.date(byAdding: .hour, value: hour + 1, to: midnight) ?? now
        }

        static func sectionsPresent(in occurrence: EventOccurrence) -> Set<PlanSection> {
            var present: Set<PlanSection> = []
            if occurrence.budget != nil { present.insert(.budget) }
            if !occurrence.recipeIDs.isEmpty { present.insert(.menu) }
            if occurrence.url?.isEmpty == false { present.insert(.tickets) }
            return present
        }

        // MARK: Derived

        public var isEditing: Bool { editing != nil }
        /// An edit to something that repeats has to say which of it it means.
        public var needsScopeChoice: Bool { editing?.isRecurring == true }

        public var trimmedTitle: String {
            title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public var canSubmit: Bool {
            !trimmedTitle.isEmpty && endsAt >= startsAt && !isSubmitting
        }

        /// Minor units. Zero — including an empty field — means no budget.
        public var budgetMinor: Int { Money.parse(budgetText, currency: currency) }

        /// The rule as the wire wants it, or `nil`.
        public var recurrence: Recurrence? {
            guard repeats else { return nil }
            return Recurrence(
                frequency: frequency,
                interval: interval,
                // Weekdays are a weekly-only refinement, and an empty set means
                // "the day it starts on" rather than "no days at all".
                weekdays: frequency == .weekly ? Array(weekdays).sorted() : [],
                until: hasEnd ? Timestamp(until) : nil
            )
        }

        public var currencyOptions: [String] { Money.pickerCodes(used: [currency]) }

        /// Members in a stable order, the viewer first.
        public var orderedMembers: [User] {
            members.sorted { lhs, rhs in
                if lhs.id == currentUserID { return true }
                if rhs.id == currentUserID { return false }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                    == .orderedAscending
            }
        }

        /// The plan sections not yet on screen, for the "add to plan" menu.
        ///
        /// All four, always. The kind's suggestion is a starting point and
        /// nothing more: cooking for a movie night is an ordinary thing to want,
        /// and a taxonomy that quietly refuses it is worse than no taxonomy.
        public var availableSections: [PlanSection] {
            PlanSection.allCases.filter { !sections.contains($0) }
        }

        /// The menu, resolved to recipes we actually have.
        ///
        /// Ordered by `recipeIDs` rather than by the recipe list, so the order
        /// somebody put the courses in survives.
        public var menu: [Recipe] {
            recipeIDs.compactMap { recipes[id: $0] }
        }

        public var canAddItem: Bool {
            !newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        /// Whether the menu section needs the recipe list loaded.
        public var wantsRecipes: Bool { sections.contains(.menu) }

        /// How the repeat reads back, so it can be checked at a glance.
        public var repeatSummary: String {
            recurrence?.summary ?? String(localized: L10n.calendarRepeatNever)
        }

        /// Reminders in the order they fire, which is not the order they are
        /// listed in.
        public var orderedReminders: [EventReminder] {
            reminders.sorted { $0.minutes > $1.minutes }
        }
    }

    public enum Action: BindableAction, Equatable {
        case task
        case recipesUpdated([Recipe])
        case samplesLoaded([Recipe])

        case kindSelected(EventKind)
        case allDayToggled
        case attendeeToggled(UserID)
        case everyoneTapped
        case reminderToggled(EventReminder)
        case weekdayToggled(Int)
        case repeatToggled
        case sectionAdded(PlanSection)
        case sectionRemoved(PlanSection)

        case pickRecipesTapped
        case recipeRemoved(RecipeID)
        case recipesAdopted([Recipe], [RecipeID])
        case picker(PresentationAction<RecipePickerFeature.Action>)

        case itemDrafted
        case draftItemRemoved(String)

        case submitTapped
        /// Saved, and this is the id it landed on — for a caller that has to
        /// point something else at the event it just asked for.
        case savedAs(EventID)
        case deleteTapped
        case scopeDialog(PresentationAction<Scope>)
        case saved
        case failed(AppError)

        case binding(BindingAction<State>)
        case delegate(Delegate)

        /// Which part of a repeating event an action is about.
        public enum Scope: Equatable {
            case saveThisOne
            case saveAll
            case deleteThisOne
            case deleteAll
        }

        public enum Delegate: Equatable {
            /// The id is `nil` for an edit, which landed on an event the caller
            /// already knew about.
            case saved(EventID?)
            case deleted(EventOccurrence, EventScope)
        }
    }

    private enum CancelID { case recipes }

    @Dependency(\.events) var events
    @Dependency(\.recipes) var recipesClient
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                return state.wantsRecipes ? subscribeToRecipes(&state) : .none

            case let .savedAs(id):
                state.isSubmitting = false
                return .send(.delegate(.saved(id)))

            case let .recipesUpdated(recipes):
                var incoming = IdentifiedArray(uniqueElements: recipes)
                // A recipe just adopted is already in hand — `adopt` returns the
                // stored row — and the subscription has not caught up yet.
                // Dropping it here would make the chip vanish and come back.
                for adopted in state.recipes where incoming[id: adopted.id] == nil
                    && state.recipeIDs.contains(adopted.id) {
                    incoming.append(adopted)
                }
                guard incoming != state.recipes else { return .none }
                state.recipes = incoming
                return .none

            case let .samplesLoaded(samples):
                state.samples = IdentifiedArray(uniqueElements: samples)
                return .none

            case let .kindSelected(kind):
                let previous = state.kind
                state.kind = kind

                // The kind carries a set of defaults, and changing it should
                // move them — but only the ones nobody has touched. Overwriting
                // a typed duration because somebody re-picked the icon is the
                // kind of helpfulness people learn to fight.
                if !state.isEditing {
                    if state.endsAt == state.startsAt.addingTimeInterval(previous.defaultDuration) {
                        state.endsAt = state.startsAt.addingTimeInterval(kind.defaultDuration)
                    }
                    if state.isAllDay == previous.isTypicallyAllDay {
                        state.isAllDay = kind.isTypicallyAllDay
                    }
                    if !state.repeats, let suggested = kind.suggestedRecurrence {
                        state.repeats = true
                        state.frequency = suggested.frequency
                        state.interval = suggested.interval
                    }
                    // Sections are only ever *added* by a kind change. Removing
                    // one would throw away a budget somebody had already typed.
                    state.sections.formUnion(kind.suggestedPlan)
                }
                return state.wantsRecipes && !state.isSubscribedToRecipes
                    ? subscribeToRecipes(&state)
                    : .none

            case .allDayToggled:
                state.isAllDay.toggle()
                let calendar = Calendar.current
                if state.isAllDay {
                    // An all-day event is a half-open span of whole days: local
                    // midnight to local midnight on the day after the last one,
                    // which is what stops a one-day event claiming two.
                    state.startsAt = calendar.startOfDay(for: state.startsAt)
                    let lastDay = calendar.startOfDay(for: state.endsAt)
                    state.endsAt = calendar.date(byAdding: .day, value: 1, to: lastDay)
                        ?? state.startsAt.addingTimeInterval(24 * 3600)
                } else {
                    let start = State.defaultStart(on: CalendarDay(state.startsAt))
                    state.startsAt = start
                    state.endsAt = start.addingTimeInterval(state.kind.defaultDuration)
                }
                return .none

            case let .attendeeToggled(id):
                if state.attendees.contains(id) {
                    state.attendees.remove(id)
                } else {
                    state.attendees.insert(id)
                }
                return .none

            case .everyoneTapped:
                // One control for both directions: with everybody already in,
                // it clears; otherwise it fills. A separate "clear" button for
                // a four-person household is a button nobody presses.
                state.attendees = state.attendees.count == state.members.count
                    ? []
                    : Set(state.members.ids)
                return .none

            case let .reminderToggled(reminder):
                if state.reminders.contains(reminder) {
                    state.reminders.remove(reminder)
                } else if state.reminders.count < EventReminder.maximum {
                    state.reminders.insert(reminder)
                } else {
                    // Refused rather than silently dropped: a fourth reminder
                    // that just does not appear reads as a broken control.
                    state.shakes += 1
                    state.inlineError = String(localized: L10n.calendarReminderLimit)
                }
                return .none

            case let .weekdayToggled(day):
                if state.weekdays.contains(day) {
                    state.weekdays.remove(day)
                } else {
                    state.weekdays.insert(day)
                }
                return .none

            case .repeatToggled:
                state.repeats.toggle()
                // Turning a weekly repeat on with nothing selected should mean
                // "the day it starts on", which is what an empty set already
                // says — but pre-selecting it makes that visible rather than
                // implied.
                if state.repeats, state.frequency == .weekly, state.weekdays.isEmpty {
                    let weekday = Calendar.current.component(.weekday, from: state.startsAt)
                    state.weekdays = [weekday - 1]
                }
                return .none

            case let .sectionAdded(section):
                state.sections.insert(section)
                if section == .budget, state.budgetText.isEmpty {
                    state.currency = Money.deviceDefault
                }
                return section == .menu && !state.isSubscribedToRecipes
                    ? subscribeToRecipes(&state)
                    : .none

            case let .sectionRemoved(section):
                state.sections.remove(section)
                // Clearing the field is the whole point of removing the section:
                // a budget left behind would be saved by a sheet that no longer
                // shows it.
                switch section {
                case .budget: state.budgetText = ""
                case .menu: state.recipeIDs = []
                case .tickets: state.url = ""
                case .shopping:
                    state.shoppingDraft = []
                    state.newItem = ""
                }
                return .none

            case .pickRecipesTapped:
                state.picker = RecipePickerFeature.State(
                    recipes: state.recipes,
                    samples: state.samples,
                    selected: Set(state.recipeIDs)
                )
                return .none

            case let .recipeRemoved(id):
                state.recipeIDs.removeAll { $0 == id }
                return .none

            case .itemDrafted:
                let name = state.newItem.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return .none }
                // Case-insensitively unique: typing "ice" twice on the way to
                // remembering you already typed it should not put it on the list
                // twice.
                guard !state.shoppingDraft.contains(where: {
                    $0.caseInsensitiveCompare(name) == .orderedSame
                }) else {
                    state.newItem = ""
                    state.shakes += 1
                    return .none
                }
                state.shoppingDraft.append(name)
                state.newItem = ""
                return .none

            case let .draftItemRemoved(name):
                state.shoppingDraft.removeAll { $0 == name }
                return .none

            case let .picker(.presented(.delegate(.chose(chosen)))):
                state.picker = nil
                let saved = chosen.filter { !$0.isSample }
                let samples = chosen.filter(\.isSample)

                // Nothing bundled was picked, so there is nothing to copy.
                guard !samples.isEmpty else {
                    state.recipeIDs = merge(state.recipeIDs, with: saved.map(\.id))
                    return .none
                }

                // A bundled recipe has no id in this home — its `homeID` is the
                // Explore sentinel — so it has to be adopted before an event can
                // point at it. `adopt` dedupes by title, so choosing the same
                // sample for two events does not leave the shelf with two copies
                // of it.
                state.isAdoptingRecipes = true
                let homeID = state.homeID
                let savedIDs = saved.map(\.id)
                return .run { send in
                    var stored: [Recipe] = []
                    for sample in samples {
                        stored.append(try await recipesClient.adopt(NewRecipe(
                            title: sample.title,
                            summary: sample.summary,
                            ingredients: sample.ingredients,
                            steps: sample.steps,
                            tags: sample.tags,
                            prepTime: sample.prepTime,
                            cookTime: sample.cookTime,
                            servings: sample.servings,
                            difficulty: sample.difficulty,
                            homeID: homeID
                        )))
                    }
                    await send(.recipesAdopted(stored, savedIDs))
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .recipesAdopted(stored, savedIDs):
                state.isAdoptingRecipes = false
                // Held locally as well as merged: the subscription will deliver
                // these in a moment, and until it does the chips need titles.
                for recipe in stored where state.recipes[id: recipe.id] == nil {
                    state.recipes.append(recipe)
                }
                state.recipeIDs = merge(state.recipeIDs, with: savedIDs + stored.map(\.id))
                return .none

            // MARK: Saving

            case .submitTapped:
                guard state.canSubmit else {
                    state.shakes += 1
                    return .none
                }
                guard state.endsAt >= state.startsAt else {
                    state.inlineError = String(localized: L10n.calendarErrorEndsBeforeStart)
                    state.shakes += 1
                    return .none
                }
                // A repeating event has to say which of it an edit means, and
                // the answer changes what is written — so it is asked before the
                // write, not after.
                if state.needsScopeChoice {
                    state.scopeDialog = .editScope()
                    return .none
                }
                return save(&state, scope: state.isEditing ? .series : .series)

            case .scopeDialog(.presented(.saveThisOne)):
                return save(&state, scope: .occurrence)

            case .scopeDialog(.presented(.saveAll)):
                return save(&state, scope: .series)

            case .deleteTapped:
                guard let editing = state.editing else { return .none }
                if editing.isRecurring {
                    state.scopeDialog = .deleteScope()
                    return .none
                }
                return .send(.delegate(.deleted(editing, .series)))

            case .scopeDialog(.presented(.deleteThisOne)):
                guard let editing = state.editing else { return .none }
                return .send(.delegate(.deleted(editing, .occurrence)))

            case .scopeDialog(.presented(.deleteAll)):
                guard let editing = state.editing else { return .none }
                return .send(.delegate(.deleted(editing, .series)))

            case .saved:
                state.isSubmitting = false
                return .send(.delegate(.saved(nil)))

            case let .failed(error):
                state.isSubmitting = false
                state.shakes += 1
                guard !error.isSilent else { return .none }
                state.inlineError = error.errorDescription
                return .none

            // Any edit clears the last refusal: the message is about a state the
            // person has now moved on from.
            case .binding:
                if state.inlineError != nil { state.inlineError = nil }
                return .none

            case .picker, .scopeDialog, .delegate:
                return .none
            }
        }
        .ifLet(\.$picker, action: \.picker) { RecipePickerFeature() }
        .ifLet(\.$scopeDialog, action: \.scopeDialog)
    }

    /// Keeps the order the menu was already in and appends what is new, so
    /// re-opening the picker never shuffles the courses.
    private func merge(_ existing: [RecipeID], with chosen: [RecipeID]) -> [RecipeID] {
        let kept = existing.filter { chosen.contains($0) }
        return kept + chosen.filter { !kept.contains($0) }
    }

    private func subscribeToRecipes(_ state: inout State) -> Effect<Action> {
        guard !state.isSubscribedToRecipes else { return .none }
        state.isSubscribedToRecipes = true
        let homeID = state.homeID
        return .merge(
            .run { send in
                for try await recipes in recipesClient.byHome(homeID) {
                    await send(.recipesUpdated(recipes))
                }
            } catch: { _, _ in }
                .cancellable(id: CancelID.recipes, cancelInFlight: true),

            // The bundled Explore recipes, read from the app bundle rather than
            // the network. A household planning its first dinner party has
            // saved nothing yet, and a picker that answers "no recipes" is a
            // dead end at exactly the moment the feature is meant to help.
            .run { send in
                await send(.samplesLoaded(recipesClient.samples()))
            }
        )
    }

    private func save(_ state: inout State, scope: EventScope) -> Effect<Action> {
        state.isSubmitting = true
        state.inlineError = nil

        let budget = state.sections.contains(.budget) && state.budgetMinor > 0
            ? state.budgetMinor
            : nil
        let url = state.sections.contains(.tickets)
            ? state.url.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        let recipeIDs = state.sections.contains(.menu) ? state.recipeIDs : []

        // Typed before the event existed, so it could not be written yet.
        let drafts = state.sections.contains(.shopping) ? state.shoppingDraft : []

        if let editing = state.editing {
            let edit = EventEdit(
                title: state.trimmedTitle,
                notes: state.notes,
                location: state.location,
                kind: state.kind,
                startsAt: state.startsAt,
                endsAt: state.endsAt,
                isAllDay: state.isAllDay,
                // An occurrence lifted out of a series never repeats — it is
                // one date now, by definition.
                recurrence: scope == .occurrence ? .some(nil) : .some(state.recurrence),
                attendees: Array(state.attendees),
                reminders: state.orderedReminders,
                url: url,
                budget: .some(budget),
                currency: state.currency,
                recipeIDs: recipeIDs
            )
            let start = scope == .occurrence ? editing.start : nil
            return .run { send in
                // The id the edit landed on, which is not the one passed in when
                // a single occurrence was lifted out of a series — the drafted
                // shopping belongs to the detached copy, not to the series it
                // left.
                let id = try await events.update(editing.eventID, scope, start, edit)
                if !drafts.isEmpty {
                    _ = try await events.addItems(id, drafts, nil)
                }
                await send(.saved)
            } catch: { error, send in
                await send(.failed(AppError(error)))
            }
        }

        let new = NewEvent(
            homeID: state.homeID,
            title: state.trimmedTitle,
            notes: state.notes,
            location: state.location,
            kind: state.kind,
            startsAt: state.startsAt,
            endsAt: state.endsAt,
            isAllDay: state.isAllDay,
            recurrence: state.recurrence,
            attendees: Array(state.attendees),
            reminders: state.orderedReminders,
            url: url,
            budget: budget,
            currency: state.currency,
            recipeIDs: recipeIDs
        )
        return .run { send in
            let id = try await events.create(new)
            // Two writes rather than one, and deliberately in this order: the
            // shopping is a link *to* an event, so there has to be an event.
            // A failure here leaves the event saved and the list short, which
            // is recoverable from the detail screen — the other order would
            // leave orphaned items nothing could ever clean up.
            if !drafts.isEmpty {
                _ = try await events.addItems(id, drafts, nil)
            }
            await send(.savedAs(id))
        } catch: { error, send in
            await send(.failed(AppError(error)))
        }
    }
}

// MARK: - Scope dialogs

extension ConfirmationDialogState where Action == EventComposerFeature.Action.Scope {
    /// "This event, or all of them?" — asked before the write, because the
    /// answer changes what gets written rather than just what gets confirmed.
    static func editScope() -> Self {
        ConfirmationDialogState {
            TextState(String(localized: L10n.calendarScopeEditTitle))
        } actions: {
            ButtonState(action: .saveThisOne) {
                TextState(String(localized: L10n.calendarScopeThisEvent))
            }
            ButtonState(action: .saveAll) {
                TextState(String(localized: L10n.calendarScopeAllEvents))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(String(localized: L10n.calendarScopeEditMessage))
        }
    }

    static func deleteScope() -> Self {
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

// MARK: - Recipe picker

/// Choosing what is being cooked.
///
/// Reads the recipe list the composer already subscribed to rather than opening
/// its own: the sheet is presented from a screen that has the data in hand, and
/// a second live query for the same rows would push twice for every edit.
@Reducer
public struct RecipePickerFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        /// What the household has saved.
        public var recipes: IdentifiedArrayOf<Recipe>
        /// The bundled Explore recipes, offered underneath — minus anything the
        /// home has already adopted, so the same dish is never on screen twice
        /// under two different ids.
        public var samples: IdentifiedArrayOf<Recipe>
        public var selected: Set<RecipeID>
        public var search = ""

        public init(
            recipes: IdentifiedArrayOf<Recipe>,
            samples: IdentifiedArrayOf<Recipe> = [],
            selected: Set<RecipeID>
        ) {
            self.recipes = recipes
            let saved = Set(recipes.map { $0.title.lowercased() })
            self.samples = samples.filter { !saved.contains($0.title.lowercased()) }
                .reduce(into: IdentifiedArrayOf<Recipe>()) { $0.append($1) }
            self.selected = selected
        }

        private func matches(_ recipe: Recipe, _ needle: String) -> Bool {
            needle.isEmpty
                || recipe.title.localizedCaseInsensitiveContains(needle)
                || recipe.tags.contains { $0.localizedCaseInsensitiveContains(needle) }
        }

        private var needle: String {
            search.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public var filtered: [Recipe] {
            recipes.filter { matches($0, needle) }
        }

        public var filteredSamples: [Recipe] {
            samples.filter { matches($0, needle) }
        }

        public var isEmpty: Bool { filtered.isEmpty && filteredSamples.isEmpty }

        /// Everything selected, saved or bundled, in list order.
        public var chosen: [Recipe] {
            (recipes + samples).filter { selected.contains($0.id) }
        }

        /// How many ingredients the chosen menu adds up to — the number that
        /// makes "send it all to the shopping list" worth pressing.
        public var ingredientCount: Int {
            chosen.reduce(0) { $0 + $1.ingredients.count }
        }

        /// How many of the chosen are bundled, so the sheet can warn that
        /// choosing them saves them to the household's own shelf.
        public var adoptedCount: Int { chosen.count { $0.isSample } }
    }

    public enum Action: BindableAction, Equatable {
        case toggled(RecipeID)
        case doneTapped
        case binding(BindingAction<State>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            /// The whole recipes, not their ids: a bundled one has no id in this
            /// home yet, and the composer needs its contents to adopt it.
            case chose([Recipe])
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .toggled(id):
                if state.selected.contains(id) {
                    state.selected.remove(id)
                } else {
                    state.selected.insert(id)
                }
                return .none

            case .doneTapped:
                // Ordered by the list rather than by the set, so the menu comes
                // back in a stable order however the taps happened.
                return .send(.delegate(.chose(state.chosen)))

            case .binding, .delegate:
                return .none
            }
        }
    }
}
