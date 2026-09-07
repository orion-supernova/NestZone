import ComposableArchitecture
import SwiftUI

public struct MovieNightView: View {
    @Bindable var store: StoreOf<MovieNightFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<MovieNightFeature>) {
        self.store = store
    }

    /// True while the deck is the screen.
    ///
    /// A swipe round is one big card, and it used to be squeezed into the
    /// middle third of the display: the tab bar drew an opaque slab across the
    /// bottom, the navigation bar drew one across the top, and the deck then
    /// sized itself inside whatever was left. Both bars stand down for the
    /// duration — the card runs full-bleed and its controls hover over it —
    /// and come straight back for the idle and results screens, which are
    /// ordinary pages and want their navigation.
    private var isImmersive: Bool {
        store.hasActivePoll && !store.isDeckFinished && !store.isLoading
            && !store.isStarting && !store.isAwaitingDeck
    }

    public var body: some View {
        content
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(L10n.movienightTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isImmersive ? .hidden : .automatic, for: .tabBar)
            .toolbarBackgroundVisibility(isImmersive ? .hidden : .automatic, for: .navigationBar)
            .toolbar {
                if !store.hasActivePoll && !store.history.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button { store.send(.historyTapped) } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .accessibilityLabel(Text(L10n.previousPollsTitle))
                    }
                }
                if store.hasActivePoll {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button { store.send(.summaryTapped) } label: {
                                Label { Text(L10n.movienightMatchesTitle) } icon: {
                                    Image(systemName: "chart.bar")
                                }
                            }
                            Button { store.send(.historyTapped) } label: {
                                Label { Text(L10n.previousPollsTitle) } icon: {
                                    Image(systemName: "clock.arrow.circlepath")
                                }
                            }
                            if store.canEndRound {
                                Button(role: .destructive) { store.send(.endRoundTapped) } label: {
                                    Label { Text(L10n.movienightClosePoll) } icon: {
                                        Image(systemName: "stop.circle")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .task { await store.send(.task).finish() }
            .sheet(item: $store.scope(
                state: \.destination?.pickKind, action: \.destination.pickKind
            )) { PollKindSheet(store: $0, onStart: { query, title in
                store.send(.kindChosen(query, title: title))
            }) }
            .sheet(item: $store.scope(
                state: \.destination?.summary, action: \.destination.summary
            )) { PollSummarySheet(store: $0) }
            .sheet(item: $store.scope(
                state: \.destination?.history, action: \.destination.history
            )) { PollHistorySheet(store: $0) }
            .sheet(item: $store.scope(
                state: \.destination?.movieInfo, action: \.destination.movieInfo
            )) { MovieInfoSheet(store: $0) }
            .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading {
            LoadingView(message: L10n.commonLoading)
        } else if store.isStarting || store.isAwaitingDeck {
            // Building a round means a TMDb round trip and then a write, and
            // joining one means waiting for its candidates. Both used to land
            // on the end-of-round screen or a bare spinner; this is the shape
            // of what is coming.
            DeckSkeleton(message: L10n.movienightBuildingDeck)
        } else if !store.hasActivePoll {
            idle
        } else if store.isDeckFinished {
            finished
        } else {
            SwipeDeck(
                items: store.remaining,
                position: store.position,
                total: store.roundSize,
                canUndo: store.canUndo,
                onSwipe: { item, isYes in store.send(.swiped(item, isYes: isYes)) },
                onOpen: { store.send(.movieTapped($0)) },
                onUndo: { store.send(.undoTapped) }
            )
        }
    }

    private var idle: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            Spacer(minLength: 0)

            Image(systemName: "popcorn.fill")
                .font(.system(size: 46))
                .foregroundStyle(theme.accent)
                .frame(width: 108, height: 108)
                .glassEffect(.regular.tint(theme.accent.opacity(0.18)), in: .circle)
                .bounces()
                .appear(0)

            VStack(spacing: 8) {
                Text(L10n.homeMinigamesWatchTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(L10n.movienightSwipeHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .appear(1)

            PrimaryButton(L10n.movienightStart, symbol: "play.fill") {
                store.send(.startTapped)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .appear(2)

            Spacer(minLength: 0)
        }
        // The tab bar hovers over the content, so the button needs room or it
        // ends up underneath the glass.
        .padding(.bottom, Metrics.scrollBottomInset)
    }

    /// The end of a deck: what everyone agreed on, and the way out.
    ///
    /// Was a fixed `VStack` whose grid competed with the buttons under it for a
    /// height neither could have. It scrolls now, and the actions ride in a
    /// hovering bar rather than taking space from the posters.
    private var finished: some View {
        Group {
            if store.matches.isEmpty {
                EmptyStateView(
                    title: L10n.movienightNoMatches,
                    message: L10n.movienightNoMatchesMessage,
                    symbol: "hourglass"
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 104), spacing: Metrics.stackSpacing)],
                        spacing: Metrics.sectionSpacing
                    ) {
                        ForEach(store.matches) { item in
                            // Agreeing on a film and then having to search for
                            // it again to save it was the gap. The poster opens
                            // it: everything TMDb knows, and the household's
                            // lists to file it into.
                            Button { store.send(.movieTapped(item)) } label: {
                                PosterCard(
                                    title: item.label ?? "",
                                    year: nil,
                                    url: TMDbImageWidth.url(for: item.thumbnailURL, width: .w342),
                                    size: CGSize(width: 104, height: 156),
                                    isSaved: true
                                ) {}
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.top, Metrics.stackSpacing)
                    .padding(.bottom, Metrics.scrollBottomInset)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    SectionHeader(L10n.movienightMatchesTitle, symbol: "sparkles")
                        .padding(.horizontal, Metrics.screenPadding)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.bar)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { finishedFooter }
    }

    /// What happens next at the end of your own deck — which is usually
    /// nothing you have to do.
    ///
    /// This was "That's everything" over an End round button, and the button
    /// was the only thing on the screen to tap, so finishing your deck read as
    /// an instruction to close the round. It is not: closing it stops everyone
    /// else mid-swipe and settles the result on whatever they had reached.
    /// Waiting is the normal ending, so the screen says so and says who it is
    /// still waiting for; ending early is the exception, and the button now
    /// says whose round it ends.
    @ViewBuilder
    private var finishedFooter: some View {
        VStack(spacing: 10) {
            VStack(spacing: 3) {
                Text(store.everyoneFinished ? L10n.movienightEveryoneDone : L10n.movienightWaiting)
                    .font(.subheadline.weight(.semibold))
                Text(L10n.movienightFinishedCount(store.finishedCount, store.memberCount))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .multilineTextAlignment(.center)
            .animation(Motion.spring, value: store.finishedCount)

            if store.canEndRound {
                SecondaryButton(L10n.movienightClosePoll, symbol: "stop.circle") {
                    store.send(.endRoundTapped)
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.bottom, 8)
    }
}

/// The card stack, and the controls that hover over it.
///
/// Only the top three cards are built. The old deck rendered every candidate —
/// up to thirty full-size posters — behind the visible one.
struct SwipeDeck: View {
    let items: [PollItem]
    /// Which card is on top, counting from one.
    let position: Int
    /// Every candidate in the round.
    let total: Int
    /// Whether there is a swipe to take back.
    let canUndo: Bool
    let onSwipe: (PollItem, Bool) -> Void
    /// Opening a card rather than answering it. A yes or a no is a decision made
    /// on a poster and a title alone; this is the way to the plot, the cast and
    /// the rating before committing to either.
    let onOpen: (PollItem) -> Void
    let onUndo: () -> Void

    /// Set by the hovering buttons. A tap has to leave the deck exactly the way
    /// a drag does — the card owns its own offset, so the instruction is passed
    /// down rather than the position being reached into.
    @State private var command: Command?

    struct Command: Equatable {
        let id: String
        let isYes: Bool
    }

    fileprivate static let visibleCards = 3
    /// Height kept clear at the bottom for the floating controls.
    fileprivate static let controlsRoom: CGFloat = 92

    var body: some View {
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets
            // Only the safe area itself, plus a hair. The counter hovers over
            // the poster rather than being given a band of its own — reserving
            // one costs about ninety points of card on a phone, which is most
            // of the difference between a full-bleed deck and a stamp.
            let topRoom = insets.top + 8
            let bottomRoom = max(insets.bottom, 12) + Self.controlsRoom
            let size = Self.poster(fitting: CGSize(
                width: geometry.size.width - 32,
                height: geometry.size.height - topRoom - bottomRoom
            ))

            ZStack {
                ForEach(
                    Array(items.prefix(Self.visibleCards).enumerated().reversed()),
                    id: \.element.id
                ) { index, item in
                    SwipeCard(
                        item: item,
                        size: size,
                        command: $command,
                        onSwipe: { isYes in onSwipe(item, isYes) },
                        onOpen: { onOpen(item) }
                    )
                    // Cards behind peek out slightly, so the stack reads as a deck.
                    .scaleEffect(1 - CGFloat(index) * 0.04)
                    .offset(y: CGFloat(index) * 12)
                    .zIndex(Double(Self.visibleCards - index))
                    .allowsHitTesting(index == 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, topRoom)
            .padding(.bottom, bottomRoom)
            .animation(Motion.spring, value: items.map(\.id))
            .overlay(alignment: .top) {
                counter.padding(.top, insets.top + 6)
            }
            .overlay(alignment: .bottom) {
                controls.padding(.bottom, max(insets.bottom, 12) + 12)
            }
        }
        .ignoresSafeArea()
    }

    /// Where you are in the round. A deck with no end in sight is the thing
    /// that makes people stop swiping.
    ///
    /// Position over total, not what is left over what is left: the deck holds
    /// only unanswered cards and shrinks as votes confirm, so counting down
    /// with it moved both numbers at once. This one climbs to a total that
    /// stays put.
    private var counter: some View {
        Text(L10n.movienightPosition(position, total))
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .contentTransition(.numericText())
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)
            .animation(Motion.spring, value: position)
            .accessibilityLabel(Text(L10n.movienightPositionLabel(position, total)))
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// Tap targets for the same two answers the swipe gives.
    ///
    /// Not everyone discovers a drag gesture, and nobody should have to make
    /// one to say no thirty times.
    private var controls: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 22) {
                // Smaller, and first: taking a card back is the rarer thing to
                // want, and it must not compete with the two answers for the
                // thumb that is about to give one.
                SwipeButton(
                    symbol: "arrow.uturn.backward",
                    tint: Palette.warning,
                    label: L10n.movienightUndo,
                    diameter: 52,
                    isEnabled: canUndo
                ) { onUndo() }

                SwipeButton(
                    symbol: "hand.thumbsdown.fill",
                    tint: Palette.danger,
                    label: L10n.movienightPass,
                    isEnabled: !items.isEmpty
                ) { fling(isYes: false) }

                SwipeButton(
                    symbol: "hand.thumbsup.fill",
                    tint: Palette.success,
                    label: L10n.movienightWouldWatch,
                    isEnabled: !items.isEmpty
                ) { fling(isYes: true) }
            }
        }
    }

    private func fling(isYes: Bool) {
        guard let top = items.first else { return }
        command = Command(id: top.id, isYes: isYes)
    }

    /// Fits a 2:3 poster into the space available, so a small phone gets a
    /// shorter card rather than a cropped one.
    fileprivate static func poster(fitting available: CGSize) -> CGSize {
        let width = max(available.width, 0)
        let height = max(available.height, 0)
        let ratio: CGFloat = 3.0 / 2.0
        return width * ratio <= height
            ? CGSize(width: width, height: width * ratio)
            : CGSize(width: min(height / ratio, width), height: height)
    }
}

/// The deck before it has any cards.
///
/// A spinner in the middle of an empty screen says "wait" without saying what
/// for, and the screen this replaces was worse than that: an empty round read
/// as a finished one, so building a deck showed "No match yet" and offered to
/// close the round. This is the shape of what is coming, sized by the same
/// maths the real stack uses, so the cards arrive into the space already held
/// for them.
private struct DeckSkeleton: View {
    let message: LocalizedStringResource

    var body: some View {
        GeometryReader { geometry in
            let size = SwipeDeck.poster(fitting: CGSize(
                width: geometry.size.width - 32,
                height: geometry.size.height - SwipeDeck.controlsRoom
            ))

            VStack(spacing: Metrics.sectionSpacing) {
                ZStack {
                    ForEach((0..<SwipeDeck.visibleCards).reversed(), id: \.self) { index in
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.quaternary)
                            .frame(width: size.width, height: size.height)
                            // The same peek as the real deck, so the stack reads
                            // as a stack rather than as one blank panel.
                            .scaleEffect(1 - CGFloat(index) * 0.04)
                            .offset(y: CGFloat(index) * 12)
                            .opacity(1 - Double(index) * 0.28)
                    }
                }
                .redacted(reason: .placeholder)

                HStack(spacing: 10) {
                    ProgressView()
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message))
    }
}

/// One of the two answers, as a floating glass button.
private struct SwipeButton: View {
    let symbol: String
    let tint: Color
    let label: LocalizedStringResource
    var diameter: CGFloat = 68
    /// Whether the button has anything to do. It owns how that looks rather
    /// than leaving the caller to dim it, so every control in the row goes
    /// inert the same way.
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.38, weight: .semibold))
                // Grey, not a pale version of the tint. A washed-out orange
                // still reads as orange — as the same button, rendered badly —
                // where grey reads as a button with nothing behind it.
                .foregroundStyle(isEnabled ? AnyShapeStyle(tint) : AnyShapeStyle(.tertiary))
                .frame(width: diameter, height: diameter)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        // The glass stops responding to touch as well as to taps: an
        // interactive surface that lights up under a finger and then does
        // nothing is worse than one that never offered.
        .glassEffect(isEnabled ? .regular.interactive() : .regular, in: .circle)
        .opacity(isEnabled ? 1 : 0.55)
        .disabled(!isEnabled)
        // Undo empties itself the moment it is used, so the change of state is
        // the feedback for the tap. It should fade, not blink.
        .animation(Motion.spring, value: isEnabled)
        .accessibilityLabel(Text(label))
    }
}

private struct SwipeCard: View {
    let item: PollItem
    let size: CGSize
    @Binding var command: SwipeDeck.Command?
    let onSwipe: (Bool) -> Void
    let onOpen: () -> Void

    @State private var offset: CGSize = .zero
    @State private var isGone = false

    /// How far the card must travel before the swipe counts.
    private let threshold: CGFloat = 110

    private var rotation: Angle { .degrees(Double(offset.width / 18)) }
    private var yesOpacity: Double { Double(max(0, offset.width) / threshold) }
    private var noOpacity: Double { Double(max(0, -offset.width) / threshold) }

    var body: some View {
        ZStack(alignment: .bottom) {
            RemoteImage(
                url: TMDbImageWidth.url(for: item.thumbnailURL, width: .w500),
                targetSize: size
            )
            .frame(width: size.width, height: size.height)
            .clipped()

            caption
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
        .overlay(alignment: .topLeading) { stamp(yes: true).opacity(yesOpacity) }
        .overlay(alignment: .topTrailing) { stamp(yes: false).opacity(noOpacity) }
        .offset(offset)
        .rotationEffect(rotation)
        .gesture(
            DragGesture()
                .onChanged { offset = $0.translation }
                .onEnded { value in
                    if abs(value.translation.width) > threshold {
                        depart(
                            isYes: value.translation.width > 0,
                            lift: value.translation.height
                        )
                    } else {
                        withAnimation(Motion.spring) { offset = .zero }
                    }
                }
        )
        // A tap is not a swipe: the drag only engages once the finger has
        // travelled, so lifting where you landed opens the film instead of
        // answering for it.
        .onTapGesture {
            guard !isGone else { return }
            onOpen()
        }
        // The hovering buttons speak to the top card through this, so a tap and
        // a drag leave the deck by exactly the same path.
        .onChange(of: command) { _, new in
            guard let new, new.id == item.id, !isGone else { return }
            command = nil
            depart(isYes: new.isYes, lift: -40)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isGone)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(item.label ?? ""))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text(L10n.moviesDetailTitle))
        // Activating the card does what tapping it does; the two answers stay
        // on the rotor, where a drag cannot reach.
        .accessibilityAction { onOpen() }
        .accessibilityAction(named: Text(L10n.movienightWouldWatch)) { onSwipe(true) }
        .accessibilityAction(named: Text(L10n.movienightPass)) { onSwipe(false) }
    }

    /// The title, and the sign that the poster itself opens.
    ///
    /// A full-bleed card gives nothing away about being tappable, so the glyph
    /// says it. The bar is drawn whether or not the candidate carries a title —
    /// a card with no name is exactly the one worth opening.
    private var caption: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(item.label ?? "")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .padding(.top, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A gradient rather than a flat black bar: the title stays readable
        // over a bright poster without cutting a hard edge across the artwork.
        .background(Palette.posterScrim)
    }

    /// Flings the card off in the direction of travel, then reports — so it
    /// never snaps back before leaving.
    private func depart(isYes: Bool, lift: CGFloat) {
        withAnimation(.easeOut(duration: 0.24)) {
            offset = CGSize(width: isYes ? 700 : -700, height: lift)
            isGone = true
        }
        onSwipe(isYes)
    }

    private func stamp(yes: Bool) -> some View {
        Image(systemName: yes ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
            .contentTransition(.symbolEffect(.replace))
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.white)
            .padding(14)
            .background(yes ? Palette.success : Palette.danger, in: .circle)
            .padding(20)
    }
}

struct PollKindSheet: View {
    @Bindable var store: StoreOf<PollKindFeature>
    let onStart: (CatalogQuery, String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(PollKindFeature.State.Kind.allCases, id: \.self) { kind in
                        Button { store.kind = kind } label: {
                            HStack {
                                Label { Text(kind.title) } icon: {
                                    Image(systemName: kind.symbol)
                                }
                                .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                if store.kind == kind {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                } header: {
                    Text(L10n.pollTypeSelectionTitle)
                } footer: {
                    Text(L10n.pollTypeSelectionSubtitle)
                }

                if store.kind.needsInput {
                    Section {
                        input
                    } header: {
                        Text(store.kind.title)
                    }
                }
            }
            .animation(Motion.spring, value: store.kind)
            .navigationTitle(Text(L10n.movienightStart))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: { Text(L10n.commonCancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { onStart(store.query, store.title) } label: {
                        Text(L10n.movienightStart).bold()
                    }
                    .disabled(!store.canStart)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var input: some View {
        switch store.kind {
        case .genre:
            Picker(selection: $store.genre) {
                ForEach(MovieGenre.allCases) { genre in
                    Label { Text(genre.title) } icon: { Image(systemName: genre.symbol) }
                        .tag(genre)
                }
            } label: {
                Text(L10n.movienightPickGenre)
            }
            .pickerStyle(.navigationLink)

        case .actor, .director:
            TextField(text: $store.personName) { Text(store.kind.title) }
                .textInputAutocapitalization(.words)

        case .year:
            Stepper(value: $store.year, in: 1950...Calendar.current.component(.year, from: Date())) {
                LabeledContent {
                    Text(store.year, format: .number.grouping(.never))
                } label: {
                    Text(store.kind.title)
                }
            }

        case .decade:
            Stepper(value: $store.decade, in: 1950...2020, step: 10) {
                LabeledContent {
                    Text("\(store.decade)s")
                } label: {
                    Text(store.kind.title)
                }
            }

        case .popular, .topRated, .nowPlaying, .upcoming:
            EmptyView()
        }
    }
}

struct PollSummarySheet: View {
    @Bindable var store: StoreOf<PollSummaryFeature>

    var body: some View {
        NavigationStack {
            List {
                if !store.matches.isEmpty {
                    Section {
                        ForEach(store.matches) { item in
                            Button { store.send(.movieTapped(item)) } label: {
                                Label { Text(item.label ?? "") } icon: {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(Palette.success)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    } header: {
                        Text(L10n.movienightMatchesTitle)
                    }
                }

                Section {
                    ForEach(store.scoreboard, id: \.item.id) { entry in
                        Button { store.send(.movieTapped(entry.item)) } label: {
                            LabeledContent {
                                // Votes land live from the other people in the
                                // house; a tally that jumps is the one thing
                                // worth watching on this screen.
                                Text(entry.yes, format: .number)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .contentTransition(.numericText(value: Double(entry.yes)))
                                    .animation(Motion.spring, value: entry.yes)
                            } label: {
                                Text(entry.item.label ?? "").foregroundStyle(.primary)
                            }
                        }
                    }
                } header: {
                    Text(L10n.movienightPreviousRounds)
                }
            }
            .navigationTitle(Text(L10n.movienightMatchesTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { store.send(.doneTapped) } label: { Text(L10n.commonDone) }
                }
            }
            .sheet(item: $store.scope(state: \.movieInfo, action: \.movieInfo)) {
                MovieInfoSheet(store: $0)
            }
        }
        .presentationDetents([.medium, .large])
    }
}


/// Rounds that have already finished, with what won each one.
struct PollHistorySheet: View {
    @Bindable var store: StoreOf<PollHistoryFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Group {
                if store.polls.isEmpty {
                    EmptyStateView(
                        title: L10n.previousPollsEmpty,
                        message: L10n.previousPollsEmptyDescription,
                        symbol: "clock.arrow.circlepath"
                    )
                } else {
                    ScrollView {
                        GlassGroup {
                            VStack(spacing: Metrics.stackSpacing) {
                                ForEach(Array(store.polls.enumerated()), id: \.element.id) { index, poll in
                                    PollHistoryRow(
                                        poll: poll,
                                        outcome: store.outcomes[poll.id],
                                        isExpanded: store.expanded == poll.id,
                                        canDelete: store.state.canDelete(poll),
                                        onMovieTapped: { store.send(.movieTapped($0)) }
                                    ) {
                                        store.send(.pollTapped(poll.id))
                                    } onDelete: {
                                        store.send(.deleteTapped(poll.id))
                                    }
                                    .appear(index)
                                }
                            }
                            .padding(.horizontal, Metrics.screenPadding)
                            .padding(.bottom, Metrics.sectionSpacing)
                        }
                    }
                }
            }
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(L10n.previousPollsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text(L10n.commonDone) }
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .sheet(item: $store.scope(state: \.movieInfo, action: \.movieInfo)) {
                MovieInfoSheet(store: $0)
            }
            .animation(Motion.spring, value: store.polls)
            .animation(Motion.spring, value: store.expanded)
        }
        .presentationDetents([.medium, .large])
    }
}

/// How a finished round ended, said accurately.
///
/// Replaces a single "Winner" line that was wrong in two ways at once: it showed
/// only the first agreement when a household had agreed on several, and when
/// there was no agreement at all it crowned whatever topped the scoreboard —
/// so one person's lone swipe, in a home of three, was reported as the winner.
private struct PollOutcomeView: View {
    let outcome: PollOutcome
    let onMovieTapped: (PollItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label { Text(headline) } icon: { Image(systemName: symbol) }
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            if !outcome.items.isEmpty {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(outcome.items) { item in
                            Button { onMovieTapped(item) } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    RemoteImage(
                                        url: TMDbImageWidth.url(for: item.thumbnailURL, width: .w185),
                                        targetSize: CGSize(width: 64, height: 96)
                                    )
                                    .frame(width: 64, height: 96)
                                    .clipShape(.rect(cornerRadius: 8, style: .continuous))

                                    Text(item.label ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(width: 64)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            // Why a round can end with nothing agreed, said rather than left
            // for the reader to work out.
            if outcome.isPartialTurnout {
                Text(L10n.previousPollsTurnout(outcome.voters, outcome.memberCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headline: LocalizedStringResource {
        switch outcome.result {
        case .agreed: L10n.movienightMatchesTitle
        case let .closest(_, yes): L10n.previousPollsClosest(yes, outcome.memberCount)
        case .nothing: L10n.previousPollsNothing
        }
    }

    private var symbol: String {
        switch outcome.result {
        case .agreed: "checkmark.seal.fill"
        case .closest: "chart.bar.fill"
        case .nothing: "hand.thumbsdown"
        }
    }

    private var tint: Color {
        switch outcome.result {
        case .agreed: Palette.success
        case .closest, .nothing: .secondary
        }
    }
}

private struct PollHistoryRow: View {
    let poll: Poll
    /// Nil until the round has been read — which is not the same as a round
    /// that ended in no agreement, though the row used to show both as a
    /// spinner labelled "no winner".
    let outcome: PollOutcome?
    let isExpanded: Bool
    let canDelete: Bool
    let onMovieTapped: (PollItem) -> Void
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "popcorn.fill")
                        .font(.callout)
                        .foregroundStyle(.tint)
                        .frame(width: 38, height: 38)
                        .background(.tint.opacity(0.14), in: .circle)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(poll.title ?? String(localized: L10n.previousPollsMoviePoll))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let created = poll.created {
                            Text(created.date, format: .dateTime.day().month().year())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accessory)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }

                if isExpanded {
                    Divider()
                    if let outcome {
                        PollOutcomeView(outcome: outcome, onMovieTapped: onMovieTapped)
                            .transition(.opacity)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(L10n.commonLoading)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(interactive: true)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                }
            }
        }
        .contextMenu {
            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                }
            }
        }
    }
}
