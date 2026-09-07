import ComposableArchitecture
import SwiftUI

/// The dinner decision, as a sheet: what are we doing, then what are we having.
struct DinnerSheet: View {
    @Bindable var store: StoreOf<DinnerFeature>

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Namespace private var glass

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(tint: theme.accent)

                VStack(spacing: 0) {
                    if let existing = store.existing {
                        AlreadyDecidedBanner(plan: existing)
                            .padding(.horizontal, Metrics.screenPadding)
                            .padding(.bottom, Metrics.stackSpacing)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                if store.hasOpenRound {
                    RoundView(store: store)
                        .transition(.opacity)
                } else if store.route == nil {
                    routePicker
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else if let kind = store.kind {
                    detail(for: kind)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    kindPicker
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(Motion.spring, value: store.kind)
            .animation(Motion.spring, value: store.route)
            .animation(Motion.spring, value: store.hasOpenRound)
            .navigationTitle(Text(navigationTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if store.route == nil || store.hasOpenRound {
                        Button(role: .cancel) { dismiss() } label: { Text(L10n.commonCancel) }
                    } else {
                        Button { store.send(.backTapped) } label: {
                            Label { Text(L10n.commonBack) } icon: {
                                Image(systemName: "chevron.left")
                            }
                            .labelStyle(.iconOnly)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomAction }
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var navigationTitle: LocalizedStringResource {
        if store.hasOpenRound { return L10n.dinnerRoundTitle }
        if let kind = store.kind { return kind.title }
        return store.route == nil ? L10n.dinnerEmptyTitle : L10n.dinnerEmptyTitle
    }

    /// One button, saying the thing this screen is currently for.
    @ViewBuilder
    private var bottomAction: some View {
        if store.hasOpenRound {
            EmptyView()
        } else if store.kind != nil, store.route == .vote {
            VStack(spacing: 4) {
                PrimaryButton(
                    L10n.dinnerRoundStart,
                    symbol: "checklist",
                    isLoading: store.isStartingRound
                ) { store.send(.startRoundTapped) }
                    .disabled(!store.canStartRound)
                    .opacity(store.canStartRound ? 1 : 0.5)

                Text(store.ballot.count >= 2
                    ? L10n.dinnerRoundSelected(store.ballot.count)
                    : L10n.dinnerRoundNeedsTwo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, 8)
            .animation(Motion.spring, value: store.ballot.count)
        } else if store.kind != nil {
            VStack(spacing: 10) {
                // Only for cooking, and only once there is something to cook.
                //
                // Most dinners are a decision, not an occasion — a calendar that
                // fills up with "Tuesday: pasta" is one nobody reads. But some
                // are a party, and those need a menu, a shopping list built from
                // it and a budget. Rather than growing all of that onto a meal
                // plan, this turns the meal into a calendar event and leaves the
                // plan pointing at it.
                if store.kind == .cook, store.canSave {
                    occasionToggle
                    if store.makeItAnOccasion {
                        occasionTime
                            .transition(.opacity.combined(with: .offset(y: -6)))
                    }
                }
                PrimaryButton(
                    L10n.dinnerSetButton,
                    symbol: "checkmark",
                    isLoading: store.isSaving
                ) { store.send(.saveTapped) }
                    .disabled(!store.canSave)
                    .opacity(store.canSave ? 1 : 0.5)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, 8)
            .animation(Motion.spring, value: store.canSave)
            .animation(Motion.spring, value: store.makeItAnOccasion)
        }
    }

    /// "Make it an occasion" — the one control that turns a meal into an event.
    private var occasionToggle: some View {
        Button { store.send(.occasionToggled) } label: {
            HStack(spacing: 10) {
                Image(systemName: store.makeItAnOccasion
                    ? "party.popper.fill"
                    : "calendar.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(store.makeItAnOccasion ? Palette.eventParty : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .bounces(when: store.makeItAnOccasion)

                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.dinnerMakeItAnOccasion)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(L10n.dinnerMakeItAnOccasionHint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: store.makeItAnOccasion
                    ? "checkmark.circle.fill"
                    : "circle")
                    .font(.title3)
                    .foregroundStyle(store.makeItAnOccasion ? Palette.eventParty : Palette.accessory)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(
            cornerRadius: Metrics.tightRadius,
            tinted: store.makeItAnOccasion ? Palette.eventParty.opacity(0.16) : nil
        )
        .sensoryFeedback(.selection, trigger: store.makeItAnOccasion)
        .accessibilityAddTraits(store.makeItAnOccasion ? [.isButton, .isSelected] : .isButton)
    }

    /// When the occasion starts. Only the clock face — the day is the day being
    /// planned, and a date picker beside it would be a second way to say the
    /// same thing, and a way to disagree with it.
    private var occasionTime: some View {
        HStack {
            Label {
                Text(L10n.dinnerOccasionStarts)
            } icon: {
                Image(systemName: "clock.fill")
                    .foregroundStyle(Palette.eventParty)
            }
            .font(.subheadline)

            Spacer(minLength: 8)

            DatePicker(
                selection: $store.occasionStart,
                displayedComponents: [.hourAndMinute]
            ) {
                Text(L10n.dinnerOccasionStarts)
            }
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: Metrics.tightRadius)
    }

    // MARK: - Deciding, or asking

    /// The question before the question: who decides.
    private var routePicker: some View {
        ScrollView {
            VStack(spacing: Metrics.stackSpacing) {
                Text(L10n.dinnerRouteTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.screenPadding)
                    .appear(0)

                GlassGroup {
                    VStack(spacing: Metrics.stackSpacing) {
                        RouteCard(
                            title: L10n.dinnerRouteSet,
                            subtitle: L10n.dinnerRouteSetSubtitle,
                            symbol: "hand.point.up.left.fill",
                            tint: theme.accent
                        ) { store.send(.routeChosen(.set)) }
                        .appear(1)

                        RouteCard(
                            title: L10n.dinnerRouteVote,
                            subtitle: L10n.dinnerRouteVoteSubtitle,
                            symbol: "person.3.fill",
                            tint: theme.support
                        ) { store.send(.routeChosen(.vote)) }
                        .appear(2)
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
            }
            .padding(.top, Metrics.stackSpacing + topInset)
            .padding(.bottom, Metrics.stackSpacing)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - What are we doing

    private var topInset: CGFloat { store.existing == nil ? 0 : 76 }

    private var kindPicker: some View {
        ScrollView {
            VStack(spacing: Metrics.stackSpacing) {
                // Naming the act, because three verbs on three cards read like
                // a menu of polls rather than "this sets dinner, right now".
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.dinnerSetDirectly)
                        .font(.headline)
                    Text(L10n.dinnerSetDirectlyHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.screenPadding)
                .appear(0)

                GlassGroup {
                    VStack(spacing: Metrics.stackSpacing) {
                        ForEach(Array(MealPlan.Kind.allCases.enumerated()), id: \.element) { index, kind in
                            KindCard(
                                kind: kind,
                                tint: tint(for: kind),
                                isCurrent: store.prefilledKind == kind
                            ) { store.send(.kindChosen(kind)) }
                            .appear(index + 1)
                        }
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
            }
            .padding(.top, Metrics.stackSpacing + topInset)
            .padding(.bottom, Metrics.stackSpacing)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func tint(for kind: MealPlan.Kind) -> Color {
        switch kind {
        case .cook: theme.accent
        case .order: theme.support
        case .out: Palette.warning
        }
    }

    // MARK: - What are we having

    @ViewBuilder
    private func detail(for kind: MealPlan.Kind) -> some View {
        VStack(spacing: Metrics.stackSpacing) {
            kindSwitcher(current: kind)
            switch kind {
            case .cook: recipePicker
            case .order, .out: cuisinePicker(for: kind)
            }
        }
    }

    /// The three ways of answering stay on screen after one is chosen. Going
    /// back to swap "cook" for "order in" was two taps and a wrong mental model
    /// — they are alternatives, not steps.
    private func kindSwitcher(current: MealPlan.Kind) -> some View {
        Picker(selection: Binding(
            get: { current },
            set: { store.send(.kindChosen($0)) }
        )) {
            ForEach(MealPlan.Kind.allCases, id: \.self) { kind in
                Text(kind.title).tag(kind)
            }
        } label: { EmptyView() }
        .pickerStyle(.segmented)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, topInset)
    }

    private var recipePicker: some View {
        VStack(spacing: Metrics.stackSpacing) {
            sourceControl
            if store.source == .custom {
                customMeal
                Spacer(minLength: 0)
            } else {
                tagFilters
                recipeList
            }
        }
        .animation(Motion.spring, value: store.source)
        .animation(Motion.spring, value: store.tags)
    }

    /// Your shelf or the catalogue. A household that has saved nothing opens on
    /// the catalogue, because an empty shelf is not an answer to "what's for
    /// dinner".
    private var sourceControl: some View {
        Picker(selection: Binding(
            get: { store.source },
            set: { store.send(.sourceChanged($0)) }
        )) {
            ForEach(DinnerFeature.State.Source.allCases, id: \.self) { source in
                Text(source.title).tag(source)
            }
        } label: { EmptyView() }
        .pickerStyle(.segmented)
        .padding(.horizontal, Metrics.screenPadding)
    }

    /// Only tags the candidates actually carry — "dinner" being the one that
    /// earns its keep. An empty chip is worse than no chip.
    @ViewBuilder
    private var tagFilters: some View {
        if !store.availableTags.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(store.availableTags, id: \.self) { tag in
                        Chip(
                            tag.capitalized,
                            isSelected: store.tags.contains(tag)
                        ) { store.send(.tagToggled(tag)) }
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// For the nights the answer is not in any list.
    private var customMeal: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.dinnerCustomLabel, symbol: "square.and.pencil")
                .padding(.horizontal, Metrics.screenPadding)

            HStack(spacing: 10) {
                GlassTextField(
                    L10n.dinnerCustomPlaceholder,
                    text: $store.customTitle,
                    symbol: "fork.knife"
                )
                .textInputAutocapitalization(.sentences)
                .submitLabel(store.route == .vote ? .next : .done)
                .onSubmit { if store.route == .vote { store.send(.customAdded) } }

                // On the voting route a typed meal is one more thing on the
                // ballot, so it needs adding rather than replacing.
                if store.route == .vote {
                    Button { store.send(.customAdded) } label: {
                        Text(L10n.dinnerRoundAddCustom)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.pressable)
                    .glassControl()
                    .disabled(store.trimmedCustomTitle.isEmpty)
                    .opacity(store.trimmedCustomTitle.isEmpty ? 0.5 : 1)
                    .animation(Motion.spring, value: store.trimmedCustomTitle.isEmpty)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)

            // What is already on the ballot, so nothing gets added twice.
            if store.route == .vote, !store.ballot.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(store.ballot) { candidate in
                            Chip(candidate.label, symbol: "xmark", isSelected: true) {
                                store.send(.ballotToggled(candidate))
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .transition(.opacity)
            }
        }
        .transition(.opacity)
    }

    private var recipeList: some View {
        Group {
            if store.isLoadingRecipes {
                SkeletonList(rows: 6, height: 56).padding(.horizontal, Metrics.screenPadding)
            } else if store.matchingRecipes.isEmpty {
                EmptyStateView(
                    title: store.isSourceEmpty
                        ? L10n.dinnerNoRecipes
                        : L10n.recipesExploreFiltersNoRecipesFound,
                    message: L10n.recipesEmptyStateSubtitle,
                    symbol: "fork.knife"
                )
                .transition(.opacity)
            } else {
                ScrollView {
                    GlassGroup {
                        VStack(spacing: 8) {
                            ForEach(store.matchingRecipes) { recipe in
                                RecipeChoice(
                                    recipe: recipe,
                                    isSelected: store.route == .vote
                                        ? store.state.isOnBallot(DinnerCandidate(recipe))
                                        : store.selection?.id == recipe.id
                                ) {
                                    store.send(store.route == .vote
                                        ? .ballotToggled(DinnerCandidate(recipe))
                                        : .recipeChosen(recipe))
                                }
                                .glassEffectID(recipe.id.rawValue, in: glass)
                            }
                        }
                        .padding(.horizontal, Metrics.screenPadding)
                    }
                    .padding(.vertical, Metrics.stackSpacing)
                }
                .scrollBounceBehavior(.basedOnSize)
                .searchable(text: $store.search, prompt: Text(L10n.recipesSearchPlaceholder))
            }
        }
        .animation(Motion.spring, value: store.selection)
    }

    private func cuisinePicker(for kind: MealPlan.Kind) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                    SectionHeader(L10n.dinnerChooseCuisine, symbol: "globe")
                        .padding(.horizontal, Metrics.screenPadding)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 104), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(Array(Cuisine.allCases.enumerated()), id: \.element) { index, cuisine in
                            CuisineTile(
                                cuisine: cuisine,
                                isSelected: store.route == .vote
                                    ? store.state.isOnBallot(DinnerCandidate(cuisine))
                                    : store.selectedCuisine == cuisine
                            ) {
                                store.send(store.route == .vote
                                    ? .ballotToggled(DinnerCandidate(cuisine))
                                    : .cuisineChosen(cuisine))
                            }
                            .appear(min(index, 6))
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }

                VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                    SectionHeader(
                        kind == .order ? L10n.dinnerPlaceOrder : L10n.dinnerPlaceOut,
                        symbol: kind == .order ? "bag" : "mappin.and.ellipse"
                    )
                    .padding(.horizontal, Metrics.screenPadding)

                    GlassTextField(
                        L10n.dinnerPlacePlaceholder,
                        text: $store.place,
                        symbol: "storefront"
                    )
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
            .padding(.vertical, Metrics.stackSpacing)
        }
        .scrollBounceBehavior(.basedOnSize)
        .animation(Motion.spring, value: store.selectedCuisine)
    }
}

/// One of the three ways a household answers "what are we eating".
private struct KindCard: View {
    let kind: MealPlan.Kind
    let tint: Color
    /// What the household settled on last time, marked so changing a decision
    /// starts from where it left off.
    var isCurrent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: kind.symbol)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title).font(.headline)
                    Text(kind.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.white, tint)
                        .transition(.scale.combined(with: .opacity))
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
        .animation(Motion.spring, value: isCurrent)
    }
}

private struct CuisineTile: View {
    let cuisine: Cuisine
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(cuisine.emoji)
                    .font(.system(size: 30))
                    .scaleEffect(isSelected ? 1.12 : 1)
                Text(cuisine.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? Color.primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Metrics.tightRadius, style: .continuous)
                    .fill(theme.accent.opacity(0.16))
            }
        }
        .glassCard(cornerRadius: Metrics.tightRadius)
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white, theme.accent)
                    .padding(6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Motion.spring, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

private struct RecipeChoice: View {
    let recipe: Recipe
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? theme.accent : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let minutes = recipe.totalMinutes {
                        Text(L10n.recipesCardTimeFormat(minutes))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.cardPadding)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .animation(Motion.spring, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - The Home tab's card

/// Tonight, once somebody has decided.
///
/// Three shapes from one row: a recipe to cook, a cuisine ordered in, or a
/// cuisine eaten out. Tapping a cooking plan opens the recipe; the other two
/// reopen the decision, because there is nothing else behind them.
struct DinnerPlanCard: View {
    let plan: MealPlan
    let action: () -> Void
    /// Tapping the occasion badge, when the meal belongs to one. `nil` leaves
    /// the badge as a label.
    var onOpenEvent: (() -> Void)? = nil
    /// Turning a meal that is already decided into an occasion. `nil` hides the
    /// offer — it belongs on the Home tab's tonight card and nowhere else.
    var onMakeOccasion: (() -> Void)? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                emblem

                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    // The meal belongs to something in the calendar. Said here
                    // rather than duplicated: the event owns the menu, the
                    // shopping and the budget, and this is the way through to
                    // all three.
                    if let event = plan.event {
                        occasionBadge(event)
                    } else if let onMakeOccasion, plan.kind == .cook {
                        // The offer only makes sense for cooking, and only while
                        // the meal is not already part of something.
                        makeOccasionButton(onMakeOccasion)
                    }
                }

                Spacer(minLength: 0)

                if plan.recipe != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accessory)
                }
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
        .accessibilityElement(children: .combine)
    }

    /// "Make an evening of it" — the way in for a dinner that is already
    /// decided.
    ///
    /// The dinner sheet offers this while a meal is being chosen, which covers
    /// the case where somebody knows in advance. It does not cover the normal
    /// one: the household settles on lasagne, and only then decides to invite
    /// people. Without this there was no way back to that decision short of
    /// re-deciding dinner.
    private func makeOccasionButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "party.popper")
                    .font(.system(size: 9, weight: .bold))
                Text(L10n.dinnerMakeAnEveningOfIt)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(Palette.eventParty)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Palette.eventParty.opacity(0.14), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func occasionBadge(_ event: MealPlan.LinkedEvent) -> some View {
        let label = HStack(spacing: 4) {
            Image(systemName: event.kind.symbol)
                .font(.system(size: 9, weight: .bold))
            Text(L10n.homeTonightPartOf(event.title))
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            if onOpenEvent != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .bold))
            }
        }
        .foregroundStyle(event.kind.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(event.kind.tint.opacity(0.14), in: .capsule)

        if let onOpenEvent {
            // A button inside a button: the card opens the recipe, the badge
            // opens the occasion. `.plain` and a tight content shape so the tap
            // targets do not overlap.
            Button(action: onOpenEvent) { label.contentShape(.capsule) }
                .buttonStyle(.plain)
        } else {
            label
        }
    }

    @ViewBuilder
    private var emblem: some View {
        switch plan.kind {
        case .cook:
            Image(systemName: "frying.pan.fill")
                .font(.title2)
                .foregroundStyle(theme.accent)
                .frame(width: 52, height: 52)
                .background(theme.accent.opacity(0.14), in: .rect(cornerRadius: 14, style: .continuous))
        case .order, .out:
            Text(plan.cuisine?.emoji ?? "🍽️")
                .font(.system(size: 28))
                .frame(width: 52, height: 52)
                .background(theme.support.opacity(0.14), in: .rect(cornerRadius: 14, style: .continuous))
        }
    }

    private var headline: String {
        if let headline = plan.headline { return headline }
        return switch plan.kind {
        case .cook: String(localized: L10n.dinnerKindCook)
        case .order, .out: String(localized: plan.cuisine?.title ?? L10n.cuisineOther)
        }
    }

    /// The second line only says something the first does not.
    private var detail: String? {
        switch plan.kind {
        case .cook:
            return plan.recipe?.totalMinutes
                .map { String(localized: L10n.recipesCardTimeFormat($0)) }
        case .order, .out:
            let manner = String(localized: plan.kind == .order
                ? L10n.dinnerOrderingIn
                : L10n.dinnerGoingOut)
            // The headline already carries the cuisine unless a place took its
            // spot, in which case the cuisine belongs down here.
            guard plan.place?.isEmpty == false, let cuisine = plan.cuisine else { return manner }
            return "\(manner) · \(String(localized: cuisine.title))"
        }
    }
}

/// Tonight, before anybody has decided.
struct UndecidedDinnerCard: View {
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(theme.accent)
                    .frame(width: 52, height: 52)
                    .background(theme.accent.opacity(0.14), in: .rect(cornerRadius: 14, style: .continuous))
                    // The one thing on this tab actually waiting on a person.
                    //
                    // Through `pulse` rather than a `repeatForever` of its own,
                    // which ran unconditionally and ignored Reduce Motion — the
                    // one animation in the app with no end needs the one switch
                    // that can stop it.
                    .pulse()

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.dinnerEmptyTitle).font(.headline)
                    Text(L10n.dinnerEmptySubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
        .accessibilityElement(children: .combine)
    }
}


/// Tonight is already answered — said plainly, without blocking the way to a
/// different answer.
private struct AlreadyDecidedBanner: View {
    let plan: MealPlan

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.callout)
                .foregroundStyle(Palette.success)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.dinnerAlreadyDecided)
                    .font(.footnote.weight(.semibold))
                Text(L10n.dinnerAlreadyDecidedHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)

            Text(summary)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: Metrics.tightRadius)
    }

    private var summary: String {
        if let headline = plan.headline { return headline }
        return switch plan.kind {
        case .cook: String(localized: L10n.dinnerKindCook)
        case .order, .out: String(localized: plan.cuisine?.title ?? L10n.cuisineOther)
        }
    }
}

/// One of the two ways a household reaches a decision.
private struct RouteCard: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accessory)
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
    }
}

/// The round itself: one candidate at a time, yes or no, until the household
/// agrees on something.
private struct RoundView: View {
    @Bindable var store: StoreOf<DinnerFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            if let match = store.matches.first {
                matchCard(match)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let candidate = store.deck.first {
                ballotCard(candidate)
                    .id(candidate.id)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.94).combined(with: .opacity),
                        removal: .push(from: .trailing).combined(with: .opacity)
                    ))
                voteButtons(candidate)
            } else {
                waiting
            }
        }
        .padding(Metrics.screenPadding)
        .frame(maxHeight: .infinity)
        .animation(Motion.spring, value: store.deck.first?.id)
        .animation(Motion.celebrate, value: store.matches.first?.id)
    }

    private func ballotCard(_ candidate: DinnerCandidate) -> some View {
        VStack(spacing: 14) {
            Text(L10n.dinnerRoundTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.accent)
            Text(candidate.label)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .glassCard()
    }

    private func voteButtons(_ candidate: DinnerCandidate) -> some View {
        HStack(spacing: 16) {
            VoteButton(symbol: "hand.thumbsdown.fill", tint: .secondary) {
                store.send(.voted(candidate, isYes: false))
            }
            VoteButton(symbol: "hand.thumbsup.fill", tint: Palette.success) {
                store.send(.voted(candidate, isYes: true))
            }
        }
    }

    private func matchCard(_ candidate: DinnerCandidate) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 44))
                .foregroundStyle(theme.accent)
                .bounces()

            Text(candidate.label)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)

            PrimaryButton(L10n.dinnerSetButton, symbol: "checkmark", isLoading: store.isSaving) {
                store.send(.matchAccepted(candidate))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    /// Everyone else is still voting.
    private var waiting: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: !reduceMotion)
            Text(L10n.dinnerRoundOpen).font(.headline)
            Text(L10n.dinnerRoundOpenHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct VoteButton: View {
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 76, height: 56)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .sensoryFeedback(.impact(weight: .light), trigger: symbol)
    }
}
