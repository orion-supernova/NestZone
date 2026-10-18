import ComposableArchitecture
import SwiftUI

/// The Add anything sheet.
///
/// Three things, top to bottom, in the order a person uses them: the field,
/// where the line goes, and what will actually be written. The preview is the
/// part that earns trust — "Add 3 to Shopping" over three rows is a promise
/// somebody can check before tapping, which is what makes a guessing input
/// safe to use without reading the chips at all.
struct CaptureView: View {
    @Bindable var store: StoreOf<CaptureFeature>

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    field
                    chips
                    preview
                }
                .padding(Metrics.screenPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { addButton }
            .background(Backdrop(tint: store.kind.tint))
            .navigationTitle(Text(L10n.captureTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { store.send(.cancelTapped) } label: {
                        Text(L10n.commonCancel)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        // A swipe down is a cancel, and cancelling takes the in-flight write
        // with it: while something is being saved, the sheet stays.
        .interactiveDismissDisabled(store.isSaving)
        .presentationBackground(.regularMaterial)
        .task { await store.send(.task).finish() }
        .onAppear { isFocused = true }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(state: \.composer?.problem, action: \.composer.problem)) { store in
            IssueComposerSheet(store: store)
        }
        .sheet(item: $store.scope(state: \.composer?.event, action: \.composer.event)) { store in
            EventComposerSheet(store: store)
        }
        .sheet(item: $store.scope(state: \.composer?.expense, action: \.composer.expense)) { store in
            ExpenseComposerSheet(store: store)
        }
    }

    // MARK: Field

    /// One line, and Return adds — the whole sheet is built so that typing
    /// and pressing Return is enough.
    private var field: some View {
        TextField(text: $store.text, prompt: Text(L10n.capturePlaceholder)) {
            Text(L10n.captureFieldLabel)
        }
        .focused($isFocused)
        .font(.title3.weight(.medium))
        .submitLabel(store.kind.continuesInComposer ? .next : .done)
        .onSubmit { store.send(.addTapped) }
        .padding(.horizontal, Metrics.cardPadding)
        .frame(minHeight: 56)
        .glassCard(cornerRadius: Metrics.tightRadius)
    }

    // MARK: Chips

    private var chips: some View {
        GlassGroup(spacing: 8) {
            // Wraps rather than scrolls: six fit on two lines at most, and a
            // chip scrolled out of sight is a choice nobody knows they have.
            FlowLayout(spacing: 8) {
                ForEach(CaptureKind.allCases) { kind in
                    Chip(
                        String(localized: kind.title),
                        symbol: kind.symbol,
                        isSelected: store.kind == kind
                    ) {
                        store.send(.kindTapped(kind), animation: Motion.spring)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: store.kind)
    }

    // MARK: Preview

    @ViewBuilder
    private var preview: some View {
        if !store.draft.isEmpty {
            Group {
                switch store.kind {
                case .shopping: shoppingPreview
                case .chore: chorePreview
                case .note: notePreview
                case .problem, .event, .expense: composerPreview
                }
            }
            .transition(.opacity)
        }
    }

    /// The list as it will land: one row per item.
    @ViewBuilder
    private var shoppingPreview: some View {
        if !store.draft.items.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.draft.items, id: \.self) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "circle")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(CaptureKind.shopping.tint)
                            Text(item)
                                .font(.body)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    /// The chore's title, and the two things the line can set on it.
    private var chorePreview: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                let title = store.draft.title(for: .chore)
                Text(title.isEmpty ? String(localized: L10n.captureChoreNeedsWords) : title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(title.isEmpty ? .secondary : .primary)
                details(date: store.draft.date, person: store.assignee, amount: nil)
            }
        }
    }

    private var notePreview: some View {
        GlassCard {
            Text(store.draft.title(for: .note))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .lineLimit(6)
        }
    }

    /// What has been understood so far, and where the rest gets asked for.
    private var composerPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(L10n.captureContinuesInForm)
            } icon: {
                Image(systemName: store.kind.symbol)
                    .foregroundStyle(store.kind.tint)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            switch store.kind {
            case .event:
                details(date: store.draft.date, person: nil, amount: nil)
            case .expense:
                details(date: nil, person: store.payer, amount: store.draft.amount)
            default:
                EmptyView()
            }
        }
    }

    /// A row of small badges — when, who, how much — for whichever of them
    /// the line said. Nothing at all when it said none.
    @ViewBuilder
    private func details(date: CaptureDate?, person: User?, amount: CaptureAmount?) -> some View {
        if date != nil || person != nil || amount != nil {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                if let date {
                    Badge(Self.text(for: date), tint: store.kind.tint, symbol: "calendar")
                }
                if let amount {
                    Badge(
                        Money.text(amount.minorUnits, currency: amount.currency ?? store.fallbackCurrency),
                        tint: store.kind.tint,
                        symbol: "banknote"
                    )
                }
                if let person {
                    HStack(spacing: 6) {
                        Avatar(user: person, size: 20, viewable: false)
                        Text(store.kind == .expense
                            ? L10n.capturePaidBy(person.displayName)
                            : L10n.captureFor(person.displayName))
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.trailing, 9)
                    .padding(.leading, 3)
                    .padding(.vertical, 3)
                    .background(Palette.inset, in: .capsule)
                }
            }
        }
    }

    /// "Fri 23 Oct, 20:00", or just the day when no time was said.
    static func text(for date: CaptureDate) -> String {
        let day = Date.FormatStyle.dateTime
            .weekday(.abbreviated)
            .day()
            .month(.abbreviated)
            .locale(L10n.locale)
        return date.hasTime
            ? date.date.formatted(day.hour().minute())
            : date.date.formatted(day)
    }

    // MARK: Add

    private var addButton: some View {
        PrimaryButton(
            addTitle,
            symbol: store.kind.continuesInComposer ? "arrow.right" : "plus",
            isLoading: store.isSaving
        ) {
            store.send(.addTapped)
        }
        .disabled(!store.canAdd)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    /// Says what the tap will do, not just "Add".
    private var addTitle: LocalizedStringResource {
        switch store.kind {
        case .shopping:
            let count = store.draft.items.count
            return count == 0 ? L10n.captureAdd : L10n.captureAddShopping(count)
        case .chore: return L10n.captureAddChore
        case .note: return L10n.captureAddNote
        case .problem, .event, .expense: return L10n.captureContinue
        }
    }
}

// MARK: - Presentation

extension CaptureKind {
    var title: LocalizedStringResource {
        switch self {
        case .shopping: L10n.captureKindShopping
        case .chore: L10n.captureKindChore
        case .note: L10n.captureKindNote
        case .problem: L10n.captureKindProblem
        case .event: L10n.captureKindEvent
        case .expense: L10n.captureKindExpense
        }
    }

    /// The same glyph the module wears in Household, so a chip and the place
    /// it sends things to are recognisably one thing.
    var symbol: String {
        switch self {
        case .shopping: "cart.fill"
        case .chore: "checklist"
        case .note: "note.text"
        case .problem: "wrench.adjustable.fill"
        case .event: "calendar.badge.clock"
        case .expense: "dollarsign.circle.fill"
        }
    }

    /// And the same colour.
    var tint: Color {
        switch self {
        case .shopping: Palette.success
        case .chore: Palette.statTasks
        case .note: Palette.statNotes
        case .problem: Palette.cyan
        case .event: Palette.hotPink
        case .expense: Palette.indigo
        }
    }
}

extension CaptureOutcome {
    /// The line the caller shows once the sheet has gone — "Added 3 to
    /// Shopping", "Problem reported".
    var message: LocalizedStringResource {
        switch kind {
        case .shopping:
            count == 0 ? L10n.captureAlreadyListed : L10n.captureAddedShopping(count)
        case .chore: L10n.captureAddedChore
        case .note: L10n.captureAddedNote
        case .problem: L10n.captureAddedProblem
        case .event: L10n.captureAddedEvent
        case .expense: L10n.captureAddedExpense
        }
    }
}
