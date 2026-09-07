import ComposableArchitecture
import SwiftUI
import UIKit

// The calendar's three sheets: writing an event, reading one, and choosing what
// is being cooked at it.

// MARK: - Composer

/// Adding or editing an event.
///
/// The order is the order somebody thinks in: what it is, when it is, then —
/// only if it needs one — the plan. The kind sits at the top because it is the
/// cheapest question on the sheet and it decides how much of the rest appears.
struct EventComposerSheet: View {
    @Bindable var store: StoreOf<EventComposerFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isItemFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    titleCard.appear(0)
                    kindPicker.appear(1)
                    whenCard.appear(2)
                    whereCard.appear(3)
                    whoCard.appear(4)
                    remindersCard.appear(5)

                    ForEach(planOrder, id: \.self) { section in
                        planCard(section)
                            .transition(.opacity.combined(with: .offset(y: -6)))
                    }

                    if !store.availableSections.isEmpty {
                        addToPlanMenu
                    }

                    if let error = store.inlineError {
                        Label { Text(error) } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                        }
                        .font(.footnote)
                        .foregroundStyle(Palette.danger)
                        .transition(.opacity.combined(with: .offset(y: -4)))
                    }

                    if store.isEditing, let editing = store.editing {
                        Button(role: .destructive) {
                            store.send(.deleteTapped)
                        } label: {
                            Label {
                                Text(editing.isRecurring
                                    ? L10n.calendarDeleteEventRepeating
                                    : L10n.calendarDeleteEvent)
                            } icon: {
                                Image(systemName: "trash")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.glass)
                        .tint(Palette.danger)
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Backdrop(tint: theme.accent))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(store.isEditing
                ? L10n.calendarEditEvent
                : L10n.calendarAddEvent))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                EventComposerToolbar(
                    isSubmitting: store.isSubmitting,
                    canSubmit: store.canSubmit,
                    onSubmit: { store.send(.submitTapped) },
                    onCancel: { dismiss() }
                )
            }
            .animation(Motion.spring, value: store.sections)
            .animation(Motion.spring, value: store.repeats)
            .animation(Motion.spring, value: store.isAllDay)
            .animation(Motion.fade, value: store.inlineError)
            .task { await store.send(.task).finish() }
            .confirmationDialog($store.scope(state: \.scopeDialog, action: \.scopeDialog))
            .sheet(item: $store.scope(state: \.picker, action: \.picker)) { store in
                RecipePickerSheet(store: store)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    /// Stable order, so adding a budget does not shuffle the menu below it.
    private var planOrder: [PlanSection] {
        PlanSection.allCases.filter { store.sections.contains($0) }
    }

    private var titleCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                TextField(text: $store.title) {
                    Text(L10n.calendarTitlePlaceholder)
                }
                .font(.title3.weight(.semibold))
                .textInputAutocapitalization(.sentences)
                .focused($isTitleFocused)
                .submitLabel(.done)

                Divider().opacity(0.4)

                TextField(text: $store.notes, axis: .vertical) {
                    Text(L10n.calendarNotesPlaceholder)
                }
                .font(.subheadline)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
            }
        }
        .shake(on: store.shakes)
    }

    /// Nineteen kinds, grouped, in one horizontal run that reaches both edges.
    ///
    /// A `Menu` would be tidier and would hide the whole point: the icons are
    /// how somebody finds "cinema" without reading nineteen labels, and the
    /// grouping is what makes a run of nineteen scannable rather than a wall.
    ///
    /// The negative padding is what makes it edge to edge. The sheet insets its
    /// whole stack by `screenPadding`, so a scroll view inside that inset stops
    /// short on both sides and the row reads as a boxed-in strip rather than as
    /// something that continues past the screen. Undoing the inset on the scroll
    /// view and re-applying it to its *content* gives the first and last chips
    /// the same margin as everything else while letting the run itself run out
    /// of view.
    private var kindPicker: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(EventKind.Group.allCases) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.title)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        HStack(spacing: 8) {
                            ForEach(group.kinds) { kind in
                                kindChip(kind)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Metrics.screenPadding)
        .animation(Motion.spring, value: store.kind)
    }

    private func kindChip(_ kind: EventKind) -> some View {
        let isSelected = store.kind == kind
        return Button { store.send(.kindSelected(kind)) } label: {
            VStack(spacing: 5) {
                Image(systemName: kind.symbol)
                    .font(.body)
                    .foregroundStyle(isSelected ? .white : kind.tint)
                    .frame(width: 42, height: 42)
                    .background(
                        isSelected
                            ? AnyShapeStyle(kind.tint)
                            : AnyShapeStyle(kind.tint.opacity(0.14)),
                        in: .rect(cornerRadius: 13, style: .continuous)
                    )
                    // Acknowledges the tap on the one that was chosen, and stays
                    // quiet on the eighteen that were not.
                    .bounces(when: isSelected)
                Text(kind.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 62)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var whenCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { store.isAllDay },
                    set: { _ in store.send(.allDayToggled) }
                )) {
                    Label {
                        Text(L10n.calendarAllDayToggle)
                    } icon: {
                        Image(systemName: store.isAllDay ? "sun.max.fill" : "clock.fill")
                            .foregroundStyle(theme.accent)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .font(.subheadline)
                }

                Divider().opacity(0.4)

                DatePicker(
                    selection: $store.startsAt,
                    displayedComponents: store.isAllDay ? [.date] : [.date, .hourAndMinute]
                ) {
                    Text(L10n.calendarStarts).font(.subheadline)
                }

                DatePicker(
                    selection: $store.endsAt,
                    in: store.startsAt...,
                    displayedComponents: store.isAllDay ? [.date] : [.date, .hourAndMinute]
                ) {
                    Text(L10n.calendarEnds).font(.subheadline)
                }

                Divider().opacity(0.4)

                Toggle(isOn: Binding(
                    get: { store.repeats },
                    set: { _ in store.send(.repeatToggled) }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.calendarRepeats).font(.subheadline)
                            if store.repeats {
                                Text(store.repeatSummary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                        }
                    } icon: {
                        Image(systemName: "repeat")
                            .foregroundStyle(store.repeats ? theme.accent : .secondary)
                            .bounces(when: store.repeats)
                    }
                }

                if store.repeats {
                    repeatControls
                        .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }
        }
    }

    @ViewBuilder
    private var repeatControls: some View {
        VStack(spacing: 12) {
            Picker(selection: $store.frequency) {
                ForEach(Recurrence.Frequency.allCases) { frequency in
                    Text(frequencyTitle(frequency)).tag(frequency)
                }
            } label: {
                Text(L10n.calendarRepeatFrequency)
            }
            .pickerStyle(.segmented)

            Stepper(value: $store.interval, in: 1...99) {
                HStack {
                    Text(L10n.calendarRepeatEvery).font(.subheadline)
                    Spacer()
                    Text(store.interval, format: .number)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(store.interval)))
                }
            }

            if store.frequency == .weekly {
                HStack(spacing: 4) {
                    ForEach(Recurrence.weekdayOrder, id: \.self) { day in
                        let isOn = store.weekdays.contains(day)
                        Button { store.send(.weekdayToggled(day)) } label: {
                            Text(Recurrence.shortWeekdaySymbols[day].prefix(2))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isOn ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(
                                    isOn ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.quaternary),
                                    in: .rect(cornerRadius: 8, style: .continuous)
                                )
                                .contentShape(.rect)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .animation(Motion.spring, value: store.weekdays)
            }

            Toggle(isOn: $store.hasEnd) {
                Text(L10n.calendarRepeatEnds).font(.subheadline)
            }
            if store.hasEnd {
                DatePicker(
                    selection: $store.until,
                    in: store.startsAt...,
                    displayedComponents: [.date]
                ) {
                    Text(L10n.calendarRepeatUntil).font(.subheadline)
                }
                .transition(.opacity)
            }
        }
        .animation(Motion.spring, value: store.frequency)
        .animation(Motion.spring, value: store.hasEnd)
    }

    private var whereCard: some View {
        GlassCard {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(theme.accent)
                    .frame(width: 20)
                TextField(text: $store.location) {
                    Text(L10n.calendarLocationPlaceholder)
                }
                .font(.subheadline)
                .textInputAutocapitalization(.words)
            }
        }
    }

    private var whoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text(L10n.calendarWhoIsComing)
                    } icon: {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(theme.accent)
                    }
                    .font(.subheadline.weight(.medium))
                    Spacer()
                    Button { store.send(.everyoneTapped) } label: {
                        Text(store.attendees.count == store.members.count
                            ? L10n.calendarClearAll
                            : L10n.calendarEveryone)
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                }

                FlowLayout(spacing: 8) {
                    ForEach(store.orderedMembers) { member in
                        let isOn = store.attendees.contains(member.id)
                        Button { store.send(.attendeeToggled(member.id)) } label: {
                            HStack(spacing: 6) {
                                Avatar(
                                    initials: member.initials,
                                    seed: member.id.rawValue,
                                    size: 22
                                )
                                Text(member.id == store.currentUserID
                                    ? String(localized: L10n.financeYou)
                                    : member.displayName)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .font(.caption2)
                                    .foregroundStyle(isOn ? theme.accent : Palette.accessory)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                isOn ? theme.accent.opacity(0.14) : Color.clear,
                                in: .capsule
                            )
                            .overlay {
                                if !isOn {
                                    Capsule().strokeBorder(.quaternary, lineWidth: 1)
                                }
                            }
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .animation(Motion.spring, value: store.attendees)
            }
        }
    }

    private var remindersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(L10n.calendarRemindMe)
                } icon: {
                    Image(systemName: store.reminders.isEmpty ? "bell.slash" : "bell.badge.fill")
                        .foregroundStyle(store.reminders.isEmpty ? .secondary : theme.accent)
                        .contentTransition(.symbolEffect(.replace))
                }
                .font(.subheadline.weight(.medium))

                FlowLayout(spacing: 8) {
                    ForEach(EventReminder.allCases) { reminder in
                        Chip(
                            String(localized: reminder.title),
                            isSelected: store.reminders.contains(reminder)
                        ) {
                            store.send(.reminderToggled(reminder))
                        }
                    }
                }
                .animation(Motion.spring, value: store.reminders)
            }
        }
    }

    // MARK: Plan

    @ViewBuilder
    private func planCard(_ section: PlanSection) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text(section.title)
                    } icon: {
                        Image(systemName: section.symbol)
                            .foregroundStyle(section.tint)
                            .bounces()
                    }
                    .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button { store.send(.sectionRemoved(section)) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Palette.accessory)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(L10n.calendarRemoveFromPlan))
                }

                switch section {
                case .budget: budgetFields
                case .menu: menuFields
                case .tickets: ticketFields
                case .shopping: shoppingFields
                }
            }
        }
    }

    private var budgetFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(store.currencyOptions, id: \.self) { code in
                        Button(code) { store.send(.binding(.set(\.currency, code))) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(store.currency)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                }

                TextField(text: $store.budgetText) {
                    Text(verbatim: "0")
                }
                .font(.system(.title3, design: .rounded, weight: .bold))
                .keyboardType(.decimalPad)
                .monospacedDigit()

                if store.budgetMinor > 0 {
                    Text(Money.text(store.budgetMinor, currency: store.currency))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            .animation(Motion.fade, value: store.budgetMinor > 0)

            Text(L10n.calendarBudgetHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Things to buy, typed before the event exists.
    ///
    /// Nothing is written from here: a shopping item is a link *to* an event and
    /// there is not one yet, so these are held and sent in a single write the
    /// moment the event has an id. The chips are the feedback that they were
    /// taken — a field that clears itself with nothing to show for it reads as a
    /// key that did not register.
    private var shoppingFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.shoppingDraft.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(store.shoppingDraft, id: \.self) { name in
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Button { store.send(.draftItemRemoved(name)) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Palette.accessory)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Palette.success.opacity(0.14), in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(Motion.spring, value: store.shoppingDraft)
            }

            // The leading glyph is a basket, not a plus.
            //
            // It used to be a plus, and a plus in front of a text field reads as
            // the button that adds the thing — so that is what got tapped, and
            // it was a decorative `Image` that did nothing. The only control was
            // the trailing arrow, which appeared *after* you typed and was a
            // 17pt glyph with no padding around it. Now the icon says "list",
            // the button is always there, and it is a full tap target.
            AddItemField(
                text: $store.newItem,
                isFocused: $isItemFocused,
                canAdd: store.canAddItem,
                tint: Palette.success,
                onSubmit: { store.send(.itemDrafted) }
            )

            Text(store.sections.contains(.menu)
                ? L10n.calendarShoppingHintWithMenu
                : L10n.calendarShoppingHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var menuFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.menu.isEmpty {
                Text(L10n.calendarMenuEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(store.menu) { recipe in
                        HStack(spacing: 6) {
                            Text(recipe.title)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Button { store.send(.recipeRemoved(recipe.id)) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Palette.accessory)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Palette.warning.opacity(0.14), in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(Motion.spring, value: store.recipeIDs)
            }

            Button { store.send(.pickRecipesTapped) } label: {
                HStack(spacing: 8) {
                    if store.isAdoptingRecipes {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "fork.knife.circle.fill")
                    }
                    Text(store.menu.isEmpty ? L10n.calendarPickRecipes : L10n.calendarEditMenu)
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .contentShape(.rect)
            }
            .buttonStyle(.glass)
            .tint(Palette.warning)
            .disabled(store.isAdoptingRecipes)
            .animation(Motion.fade, value: store.isAdoptingRecipes)
        }
    }

    private var ticketFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(Palette.violet)
                    .frame(width: 20)
                TextField(text: $store.url) {
                    Text(L10n.calendarTicketsPlaceholder)
                }
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            }
            Text(L10n.calendarTicketsHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var addToPlanMenu: some View {
        Menu {
            ForEach(store.availableSections) { section in
                Button { store.send(.sectionAdded(section)) } label: {
                    Label { Text(section.title) } icon: {
                        Image(systemName: section.symbol)
                    }
                }
            }
        } label: {
            Label {
                Text(L10n.calendarAddToPlan)
            } icon: {
                Image(systemName: "plus.circle")
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.glass)
    }

    private func frequencyTitle(_ frequency: Recurrence.Frequency) -> LocalizedStringResource {
        switch frequency {
        case .daily: L10n.calendarFrequencyDaily
        case .weekly: L10n.calendarFrequencyWeekly
        case .monthly: L10n.calendarFrequencyMonthly
        case .yearly: L10n.calendarFrequencyYearly
        }
    }
}

/// Cancel and Save, with the keyboard resigned before either fires.
///
/// A focused field writes its binding one last time as it resigns, and
/// dismissing the sheet first meant that write landed after the store's
/// presentation state was already `nil` — TCA's "received a presentation action
/// when destination state was absent" warning, on every cancel. Resigning first
/// puts the last write back inside the sheet's own lifetime.
private struct EventComposerToolbar: ToolbarContent {
    let isSubmitting: Bool
    let canSubmit: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    private func endEditing() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .cancel) {
                endEditing()
                onCancel()
            } label: {
                Text(L10n.commonCancel)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                endEditing()
                onSubmit()
            } label: {
                if isSubmitting {
                    ProgressView().controlSize(.small)
                } else {
                    Text(L10n.commonSave).bold()
                }
            }
            .disabled(!canSubmit)
            .sensoryFeedback(.impact(weight: .medium), trigger: isSubmitting) { was, now in
                !was && now
            }
        }
    }
}

// MARK: - Detail

/// One event, and everything the household has to get ready for it.
struct EventDetailSheet: View {
    @Bindable var store: StoreOf<EventDetailFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @FocusState private var isItemFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    hero.appear(0)
                    rsvpCard.appear(1)
                    if !store.state.roster.isEmpty { rosterCard.appear(2) }

                    ForEach(Array(store.state.visibleSections.enumerated()), id: \.element) { index, section in
                        planCard(section).appear(index + 3)
                    }

                    if !store.hasPlan && !store.isLoadingPlan {
                        planInvitation.appear(3)
                    }

                    if let notes = store.occurrence.notes, !notes.isEmpty {
                        notesCard(notes).appear(6)
                    }
                }
                .padding(Metrics.screenPadding)
                .padding(.bottom, 20)
            }
            .background(Backdrop(tint: store.occurrence.kind.tint))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(store.occurrence.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(L10n.commonClose) }
                }
                ToolbarItem(placement: .primaryAction) { overflow }
            }
            .task { await store.send(.task).finish() }
            .alert($store.scope(state: \.alert, action: \.alert))
            .confirmationDialog($store.scope(state: \.scopeDialog, action: \.scopeDialog))
            .sheet(item: $store.scope(state: \.expense, action: \.expense)) { store in
                ExpenseComposerSheet(store: store)
            }
            .animation(Motion.spring, value: store.state.visibleSections)
            .animation(Motion.spring, value: store.plan)
        }
    }

    private var overflow: some View {
        Menu {
            Button { store.send(.editTapped) } label: {
                Label { Text(L10n.commonEdit) } icon: { Image(systemName: "pencil") }
            }
            if store.occurrence.budget != nil || !(store.plan?.expenses.isEmpty ?? true) {
                Button { store.send(.addExpenseTapped) } label: {
                    Label { Text(L10n.financeAddExpense) } icon: {
                        Image(systemName: "creditcard")
                    }
                }
            }
            Divider()
            Button(role: .destructive) { store.send(.deleteTapped) } label: {
                Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(Text(L10n.commonMore))
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: store.occurrence.kind.symbol)
                    .font(.title3)
                    .foregroundStyle(store.occurrence.kind.tint)
                    .frame(width: 46, height: 46)
                    .background(
                        store.occurrence.kind.tint.opacity(0.16),
                        in: .rect(cornerRadius: 14, style: .continuous)
                    )
                    .bounces(when: store.occurrence.isInProgress)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.occurrence.kind.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(store.occurrence.kind.tint)
                    CountdownText(store.occurrence.start)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                detailRow(
                    symbol: store.occurrence.isAllDay ? "sun.max" : "clock",
                    text: fullWhen
                )
                if let location = store.occurrence.location, !location.isEmpty {
                    detailRow(symbol: "mappin.and.ellipse", text: location)
                }
                if let rule = store.occurrence.recurrence {
                    detailRow(symbol: "repeat", text: rule.summary)
                }
                if !store.occurrence.reminderChoices.isEmpty {
                    detailRow(
                        symbol: "bell.badge",
                        text: store.occurrence.reminderChoices
                            .map { String(localized: $0.title) }
                            .joined(separator: ", ")
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tinted: store.occurrence.kind.tint.opacity(0.16))
    }

    private func detailRow(symbol: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    private var fullWhen: String {
        let occurrence = store.occurrence
        let dayStyle = Date.FormatStyle(date: .complete, time: .omitted).locale(L10n.locale)
        let day = occurrence.start.formatted(dayStyle)
        if occurrence.isAllDay {
            return "\(day) · \(String(localized: L10n.calendarAllDay))"
        }
        return "\(day) · \(occurrence.timeText)"
    }

    private var rsvpCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.calendarAreYouComing)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if store.goingCount > 0 {
                        Label {
                            AnimatedNumber(store.goingCount)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.success)
                    }
                }

                HStack(spacing: 6) {
                    ForEach(RSVPStatus.allCases) { status in
                        let isMine = store.myRSVP == status
                        Button { store.send(.rsvpTapped(status)) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: status.symbol)
                                    .font(.caption.weight(.bold))
                                    .bounces(when: isMine)
                                Text(status.title)
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(isMine ? .white : status.tint)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                isMine
                                    ? AnyShapeStyle(status.tint)
                                    : AnyShapeStyle(status.tint.opacity(0.14)),
                                in: .capsule
                            )
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(isMine ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .animation(Motion.spring, value: store.myRSVP)
                .sensoryFeedback(.selection, trigger: store.myRSVP)
            }
        }
    }

    private var rosterCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.calendarWhoIsComing)
                    .font(.subheadline.weight(.semibold))
                ForEach(store.state.roster, id: \.user) { row in
                    HStack(spacing: 10) {
                        if let member = store.members[id: row.user] {
                            Avatar(initials: member.initials, seed: row.user.rawValue, size: 26)
                        }
                        Text(store.state.name(for: row.user))
                            .font(.subheadline)
                        Spacer(minLength: 0)
                        if let status = row.status {
                            Label {
                                Text(status.title)
                            } icon: {
                                Image(systemName: status.symbol)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(status.tint)
                        } else {
                            Text(L10n.calendarNoAnswer)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .animation(Motion.fade, value: store.occurrence.rsvps)
        }
    }

    // MARK: Plan cards

    @ViewBuilder
    private func planCard(_ section: PlanSection) -> some View {
        switch section {
        case .budget: budgetCard
        case .shopping: shoppingCard
        case .menu: menuCard
        case .tickets: ticketsCard
        }
    }

    private var budgetCard: some View {
        let plan = store.plan ?? .empty
        let currency = store.state.planCurrency
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    PlanRing(
                        progress: plan.budgetProgress,
                        tint: Palette.indigo,
                        symbol: "creditcard.fill",
                        size: 48,
                        isOver: plan.isOverBudget
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.calendarPlanBudget)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Money.text(plan.spent, currency: currency))
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .contentTransition(.numericText())
                            if let budget = plan.budget {
                                Text(L10n.calendarOfBudget(Money.compactText(budget, currency: currency)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let remaining = plan.remaining {
                            Text(plan.isOverBudget
                                ? L10n.calendarOverBudget(Money.text(-remaining, currency: currency))
                                : L10n.calendarLeftToSpend(Money.text(remaining, currency: currency)))
                                .font(.caption)
                                .foregroundStyle(plan.isOverBudget ? Palette.danger : Palette.success)
                        }
                    }
                    Spacer(minLength: 0)
                }

                if plan.isMixedCurrency {
                    // Sums are scoped to one currency, and a plan paid partly in
                    // another has to say so rather than quietly under-reporting.
                    Label {
                        Text(L10n.calendarMixedCurrencies)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.caption2)
                    .foregroundStyle(Palette.warning)
                }

                if !plan.expenses.isEmpty {
                    Divider().opacity(0.4)
                    VStack(spacing: 8) {
                        ForEach(store.state.visibleExpenses) { expense in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(expense.category.tint)
                                    .frame(width: 7, height: 7)
                                Text(expense.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(store.state.name(for: expense.paidBy))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(Money.text(expense.amount, currency: expense.currency))
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                            }
                        }
                        if store.state.hiddenExpenseCount > 0 {
                            // A fold, not a dead end: this used to be a plain
                            // label, so "+4 more" named four expenses the
                            // sheet gave no way at all to read.
                            DisclosureRow(
                                isExpanded: store.isExpensesExpanded,
                                collapsedTitle: L10n.calendarMoreExpenses(
                                    store.state.hiddenExpenseCount
                                )
                            ) { store.send(.expensesExpandToggled) }
                        }
                    }
                    .animation(Motion.spring, value: store.isExpensesExpanded)
                }

                Button { store.send(.addExpenseTapped) } label: {
                    Label { Text(L10n.calendarLogSpend) } icon: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .contentShape(.rect)
                }
                .buttonStyle(.glass)
                .tint(Palette.indigo)
            }
        }
    }

    private var shoppingCard: some View {
        let plan = store.plan ?? .empty
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    PlanRing(
                        progress: plan.shoppingProgress,
                        tint: Palette.success,
                        symbol: plan.shoppingIsDone ? "checkmark" : "cart.fill",
                        size: 44
                    )
                    .opacity(plan.shoppingTotal == 0 ? 0.5 : 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.calendarPlanShopping)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        // "0 of 0 bought" is not a progress report, it is an
                        // empty list pretending to be one.
                        Text(plan.shoppingTotal == 0
                            ? String(localized: L10n.calendarNothingToBuyYet)
                            : String(localized: L10n.calendarBoughtOf(
                                plan.shoppingPurchased, plan.shoppingTotal
                            )))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 0)
                }

                VStack(spacing: 2) {
                    ForEach(store.state.visibleShopping) { item in
                        shoppingRow(item)
                    }
                    if store.state.hiddenShoppingCount > 0 {
                        // The bug this replaces: a bulk add would put thirty
                        // things on the list and the card would print "+18
                        // more items" as flat text, which is a count of things
                        // nobody could see, tick off, or reach from anywhere.
                        DisclosureRow(
                            isExpanded: store.isShoppingExpanded,
                            collapsedTitle: L10n.calendarMoreItems(
                                store.state.hiddenShoppingCount
                            )
                        ) { store.send(.shoppingExpandToggled) }
                        .padding(.top, 4)
                    }
                }
                .animation(Motion.spring, value: plan.shoppingPurchased)
                .animation(Motion.spring, value: store.isShoppingExpanded)

                addItemField
            }
        }
    }

    private func shoppingRow(_ item: EventPlan.LinkedItem) -> some View {
        Button {
            store.send(.itemToggled(item.id, !item.isPurchased))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(item.isPurchased ? Palette.success : Palette.accessory)
                    // The tick grows into place rather than appearing, which is
                    // the whole feedback for a one-tap action.
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, options: .nonRepeating, value: item.isPurchased)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.subheadline)
                        .strikethrough(item.isPurchased, color: .secondary)
                        .foregroundStyle(item.isPurchased ? .secondary : .primary)
                        .lineLimit(1)
                    if let recipe = item.recipeTitle, !recipe.isEmpty {
                        Text(recipe)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: item.isPurchased)
    }

    private var addItemField: some View {
        AddItemField(
            text: $store.newItem,
            isFocused: $isItemFocused,
            canAdd: !store.newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            tint: Palette.success,
            isBusy: store.isAddingItem,
            onSubmit: { store.send(.addItemTapped) }
        )
    }

    private var menuCard: some View {
        let plan = store.plan ?? .empty
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text(L10n.calendarPlanMenu)
                    } icon: {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(Palette.warning)
                    }
                    .font(.subheadline.weight(.semibold))
                    Spacer()
                    if plan.menuIngredientCount > 0 {
                        Text(L10n.calendarIngredientCount(plan.menuIngredientCount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.isLoadingPlan {
                    SkeletonList(rows: 2, height: 44)
                } else {
                    ForEach(plan.recipes) { recipe in
                        HStack(spacing: 10) {
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Palette.warning)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(recipe.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    if let minutes = recipe.totalMinutes {
                                        Label {
                                            Text(L10n.calendarMinutes(minutes))
                                        } icon: {
                                            Image(systemName: "clock")
                                        }
                                    }
                                    if let servings = recipe.servings {
                                        Label {
                                            Text(L10n.calendarServes(servings))
                                        } icon: {
                                            Image(systemName: "person.2")
                                        }
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // The one button that makes the whole module worth having: a
                // menu becomes a shopping list in one write, tagged to this
                // event, skipping anything already on the list.
                Button { store.send(.stockUpTapped) } label: {
                    HStack(spacing: 8) {
                        if store.isStockingUp {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: hasNothingToStockUp
                                ? "checkmark.circle.fill"
                                : "cart.badge.plus")
                                .contentTransition(.symbolEffect(.replace))
                                .bounces(when: store.state.suggestsStockUp)
                        }
                        Text(stockUpTitle)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .contentShape(.rect)
                }
                .buttonStyle(.glassProminent)
                .tint(hasNothingToStockUp ? Palette.accessory : Palette.warning)
                .disabled(store.isStockingUp || !store.state.canStockUp)
                // Spelled out rather than left to the button style: a prominent
                // glass button barely dims on its own, and a live-looking
                // control whose only outcome is "that did nothing" is worse
                // than one that plainly says there is nothing to do.
                .opacity(hasNothingToStockUp ? 0.55 : 1)
                .animation(Motion.fade, value: hasNothingToStockUp)

                // Suppressed when it would only repeat the button above it:
                // after a press that added nothing, both say the same sentence.
                // A press that *did* add something still reports what it did.
                if let result = store.lastStockUp,
                   !(result.added == 0 && hasNothingToStockUp) {
                    Text(stockUpSummary(result))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }

                // The other half of the dinner link. A dinner party is a meal
                // *and* an event; this is the one field that says so, and it
                // means the Home tab's tonight card can point at the thing that
                // owns the menu, the shopping and the budget rather than
                // carrying a second copy of any of them.
                if store.state.canPlanDinner {
                    Divider().opacity(0.4)
                    Button { store.send(.planAsDinnerTapped) } label: {
                        HStack(spacing: 8) {
                            if store.isPlanningDinner {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: store.state.isDinner
                                    ? "checkmark.circle.fill"
                                    : "fork.knife.circle")
                                    .contentTransition(.symbolEffect(.replace))
                                    .bounces(when: store.didPlanDinner)
                            }
                            Text(dinnerButtonTitle)
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.glass)
                    .tint(store.state.isDinner ? Palette.success : Palette.warning)
                    .disabled(store.isPlanningDinner || store.state.isDinner)
                    .animation(Motion.spring, value: store.state.isDinner)

                    // Said out loud only on a repeating event, where it is the
                    // one thing that is not obvious: a meal plan is one row per
                    // household per day, so "every Friday" cannot claim them
                    // all. The button sets this Friday, and next Friday is
                    // still a question — which the button naming its own date
                    // is what makes readable.
                    if store.occurrence.isRecurring {
                        Text(L10n.calendarDinnerThisDateOnly)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .animation(Motion.fade, value: store.lastStockUp)
        }
    }

    /// A menu with nothing left to send: every ingredient is already on the
    /// household's list. Distinct from "no menu at all", which shows no card.
    private var hasNothingToStockUp: Bool {
        !(store.plan?.recipes.isEmpty ?? true) && !store.state.canStockUp
    }

    /// Names the day on a repeating event, and only there.
    ///
    /// "Make it dinner that day" is unambiguous on a one-off and meaningless on
    /// "movie night, every Friday" — which Friday? So the repeating case spells
    /// the date out and the one-off keeps the shorter sentence.
    private var dinnerButtonTitle: LocalizedStringResource {
        guard store.occurrence.isRecurring else {
            return store.state.isDinner ? L10n.calendarIsDinner : L10n.calendarMakeItDinner
        }
        let day = store.occurrence.start.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        )
        return store.state.isDinner
            ? L10n.calendarIsDinnerOn(day)
            : L10n.calendarMakeItDinnerOn(day)
    }

    private var stockUpTitle: LocalizedStringResource {
        if hasNothingToStockUp { return L10n.calendarAllAlreadyListed }
        return (store.plan?.shoppingTotal ?? 0) > 0
            ? L10n.calendarStockUpAgain
            : L10n.calendarStockUp
    }

    private func stockUpSummary(_ result: StockUpResult) -> LocalizedStringResource {
        if result.added == 0 && result.skipped > 0 { return L10n.calendarAllAlreadyListed }
        if result.skipped == 0 { return L10n.calendarItemsAdded(result.added) }
        return L10n.calendarItemsAddedSkipped(result.added, result.skipped)
    }

    private var ticketsCard: some View {
        GlassCard {
            Button { store.send(.openURLTapped) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "ticket.fill")
                        .font(.title3)
                        .foregroundStyle(Palette.violet)
                        .bounces()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.calendarPlanTickets)
                            .font(.subheadline.weight(.semibold))
                        Text(store.occurrence.url ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right.square")
                        .font(.footnote)
                        .foregroundStyle(Palette.accessory)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
        }
    }

    /// Shown when an event has no plan at all — one line about what a plan is
    /// for, rather than three empty cards pretending it has one.
    private var planInvitation: some View {
        Button { store.send(.editTapped) } label: {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(PlanSection.allCases) { section in
                        Image(systemName: section.symbol)
                            .font(.footnote)
                            .foregroundStyle(section.tint)
                            .frame(width: 30, height: 30)
                            .background(section.tint.opacity(0.14), in: .circle)
                    }
                }
                Text(L10n.calendarPlanInvitation)
                    .font(.subheadline.weight(.medium))
                Text(L10n.calendarPlanInvitationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard()
    }

    private func notesCard(_ notes: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(L10n.calendarNotes)
                } icon: {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// "Add something to buy" — one field, used by the composer and the detail sheet.
///
/// Two rules it exists to hold. The icon in front of a text field must not look
/// like the button that submits it: a leading plus is read as the add control,
/// and a decorative one is a dead tap in the exact spot people aim for. And the
/// real control is always on screen, disabled rather than absent — a button that
/// materialises only once you have typed cannot be found before you type, and at
/// 17pt with no padding it was under the 44pt target the rest of the app keeps.
private struct AddItemField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let canAdd: Bool
    let tint: Color
    var isBusy: Bool = false
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "basket")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(text: $text) {
                Text(L10n.calendarAddItemPlaceholder)
            }
            .font(.subheadline)
            .focused($isFocused)
            // The keyboard's own key is the fast path: a list of ten is ten
            // taps in one place rather than ten round trips to a button.
            .submitLabel(.done)
            .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Group {
                    if isBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(canAdd ? tint : Palette.accessory)
                    }
                }
                .frame(width: 34, height: Metrics.minTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .disabled(!canAdd || isBusy)
            .accessibilityLabel(Text(L10n.calendarAddItemPlaceholder))
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(height: Metrics.minTapTarget)
        .background(.quaternary.opacity(0.5), in: .capsule)
        // The capsule is mostly empty space, and tapping empty space beside a
        // text field should put the caret in it.
        .contentShape(.capsule)
        .onTapGesture { isFocused = true }
        .animation(Motion.fade, value: canAdd)
        .animation(Motion.fade, value: isBusy)
    }
}

/// The fold at the bottom of a plan list.
///
/// Both plan lists cut off — a detail sheet is a summary, and a party with
/// forty shopping lines should not push its add field off the screen. What
/// makes a fold honest is that it is a control: "+8 more items" as flat text is
/// a promise of eight things with no way to reach them, which is how a bulk add
/// could put a whole recipe on the list and then hide most of it.
private struct DisclosureRow: View {
    let isExpanded: Bool
    let collapsedTitle: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(isExpanded ? L10n.calendarShowLess : collapsedTitle)
                    .font(.caption2.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .frame(height: Metrics.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(isExpanded ? L10n.calendarShowLess : collapsedTitle))
    }
}

// MARK: - Recipe picker

/// Choosing what is being cooked.
struct RecipePickerSheet: View {
    @Bindable var store: StoreOf<RecipePickerFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if store.state.isEmpty {
                        EmptyStateView(
                            title: L10n.calendarNoRecipes,
                            message: L10n.calendarNoRecipesMessage,
                            symbol: "fork.knife",
                            isCompact: true
                        )
                        .padding(.top, 24)
                    } else {
                        if !store.state.filtered.isEmpty {
                            if !store.state.filteredSamples.isEmpty {
                                sectionHeading(L10n.calendarYourRecipes, symbol: "books.vertical.fill")
                            }
                            ForEach(Array(store.state.filtered.enumerated()), id: \.element.id) { index, recipe in
                                row(recipe).appear(index)
                            }
                        }

                        // Explore, underneath. A household planning its first
                        // dinner party has saved nothing yet, and a picker that
                        // answers "no recipes" at that moment is a dead end.
                        // Choosing one copies it onto the household's own shelf
                        // first — an event has to point at a recipe this home
                        // owns, and the copy is the thing it points at.
                        if !store.state.filteredSamples.isEmpty {
                            sectionHeading(L10n.calendarExploreRecipes, symbol: "sparkles")
                                .padding(.top, store.state.filtered.isEmpty ? 0 : 10)
                            ForEach(Array(store.state.filteredSamples.enumerated()), id: \.element.id) { index, recipe in
                                row(recipe).appear(index)
                            }
                        }
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Backdrop(tint: theme.accent))
            .searchable(text: $store.search, prompt: Text(L10n.calendarSearchRecipes))
            .navigationTitle(Text(L10n.calendarPlanMenu))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: { Text(L10n.commonCancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { store.send(.doneTapped) } label: {
                        Text(L10n.commonDone).bold()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !store.selected.isEmpty {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "cart")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.warning)
                            // The number that makes the choice concrete: four
                            // recipes is an abstraction, thirty-one ingredients
                            // is a shopping trip.
                            Text(L10n.calendarMenuSummary(
                                store.state.chosen.count,
                                store.state.ingredientCount
                            ))
                            .font(.caption.weight(.medium))
                            .contentTransition(.numericText())
                        }
                        // Said out loud, because it is a side effect somebody
                        // did not ask for: picking an Explore recipe puts a copy
                        // on the household's own shelf.
                        if store.state.adoptedCount > 0 {
                            Text(L10n.calendarWillSaveToHome(store.state.adoptedCount))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Motion.spring, value: store.selected)
        }
    }

    private func sectionHeading(
        _ title: LocalizedStringResource,
        symbol: String
    ) -> some View {
        Label { Text(title) } icon: { Image(systemName: symbol) }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
            .padding(.bottom, 2)
    }

    private func row(_ recipe: Recipe) -> some View {
        let isOn = store.selected.contains(recipe.id)
        return Button { store.send(.toggled(recipe.id)) } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Palette.warning : Palette.accessory)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, options: .nonRepeating, value: isOn)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Label {
                            Text(L10n.calendarIngredientCount(recipe.ingredients.count))
                        } icon: {
                            Image(systemName: "basket")
                        }
                        if let servings = recipe.servings {
                            Label {
                                Text(L10n.calendarServes(servings))
                            } icon: {
                                Image(systemName: "person.2")
                            }
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(cornerRadius: Metrics.tightRadius, tinted: isOn ? Palette.warning.opacity(0.16) : nil)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
