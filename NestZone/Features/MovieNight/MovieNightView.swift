import ComposableArchitecture
import SwiftUI

public struct MovieNightView: View {
    @Bindable var store: StoreOf<MovieNightFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<MovieNightFeature>) {
        self.store = store
    }

    public var body: some View {
        content
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(L10n.movienightTitle))
            .navigationBarTitleDisplayMode(.inline)
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
            .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading {
            LoadingView()
        } else if store.isStarting {
            LoadingView(message: L10n.commonLoading)
        } else if !store.hasActivePoll {
            idle
        } else if store.isDeckFinished {
            finished
        } else {
            SwipeDeck(
                items: store.remaining,
                onSwipe: { item, isYes in store.send(.swiped(item, isYes: isYes)) }
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
                .symbolEffect(.bounce, options: .nonRepeating)
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
    }

    private var finished: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            if store.matches.isEmpty {
                EmptyStateView(
                    title: L10n.movienightNoMatches,
                    message: L10n.movienightNoMatchesMessage,
                    symbol: "hourglass"
                )
            } else {
                VStack(spacing: Metrics.stackSpacing) {
                    SectionHeader(L10n.movienightMatchesTitle, symbol: "sparkles")
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 104), spacing: Metrics.stackSpacing)],
                            spacing: Metrics.stackSpacing
                        ) {
                            ForEach(store.matches) { item in
                                PosterCard(
                                    title: item.label ?? "",
                                    year: nil,
                                    url: TMDbImageWidth.url(for: item.thumbnailURL, width: .w342),
                                    size: CGSize(width: 104, height: 156),
                                    isSaved: true
                                ) {}
                            }
                        }
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
            }

            Text(L10n.movienightDeckDone)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if store.canEndRound {
                SecondaryButton(L10n.movienightClosePoll, symbol: "stop.circle") {
                    store.send(.endRoundTapped)
                }
                .padding(.horizontal, Metrics.screenPadding)
            }
        }
        .padding(.vertical, Metrics.sectionSpacing)
    }
}

/// The card stack.
///
/// Only the top three cards are built. The old deck rendered every candidate —
/// up to thirty full-size posters — behind the visible one.
struct SwipeDeck: View {
    let items: [PollItem]
    let onSwipe: (PollItem, Bool) -> Void

    private static let visibleCards = 3

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(items.prefix(Self.visibleCards).enumerated().reversed()), id: \.element.id) { index, item in
                    SwipeCard(
                        item: item,
                        size: CGSize(width: geometry.size.width - 48, height: geometry.size.height - 80),
                        onSwipe: { isYes in onSwipe(item, isYes) }
                    )
                    // Cards behind peek out slightly, so the stack reads as a deck.
                    .scaleEffect(1 - CGFloat(index) * 0.04)
                    .offset(y: CGFloat(index) * 12)
                    .zIndex(Double(Self.visibleCards - index))
                    .allowsHitTesting(index == 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(Motion.spring, value: items.map(\.id))
        }
    }
}

private struct SwipeCard: View {
    let item: PollItem
    let size: CGSize
    let onSwipe: (Bool) -> Void

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
            .clipShape(.rect(cornerRadius: 24, style: .continuous))

            if let label = item.label {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.45))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topLeading) { stamp(yes: true).opacity(yesOpacity) }
        .overlay(alignment: .topTrailing) { stamp(yes: false).opacity(noOpacity) }
        .offset(offset)
        .rotationEffect(rotation)
        .gesture(
            DragGesture()
                .onChanged { offset = $0.translation }
                .onEnded { value in
                    if abs(value.translation.width) > threshold {
                        let isYes = value.translation.width > 0
                        // Fling it off-screen in the direction of travel, then
                        // report — so the card never snaps back before leaving.
                        withAnimation(.easeOut(duration: 0.22)) {
                            offset = CGSize(width: isYes ? 700 : -700, height: value.translation.height)
                            isGone = true
                        }
                        onSwipe(isYes)
                    } else {
                        withAnimation(Motion.spring) { offset = .zero }
                    }
                }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: isGone)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(item.label ?? ""))
        .accessibilityAction(named: Text(L10n.commonAdd)) { onSwipe(true) }
        .accessibilityAction(named: Text(L10n.commonRemove)) { onSwipe(false) }
    }

    private func stamp(yes: Bool) -> some View {
        Image(systemName: yes ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
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
    let store: StoreOf<PollSummaryFeature>

    var body: some View {
        NavigationStack {
            List {
                if !store.matches.isEmpty {
                    Section {
                        ForEach(store.matches) { item in
                            Label { Text(item.label ?? "") } icon: {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Palette.success)
                            }
                        }
                    } header: {
                        Text(L10n.movienightMatchesTitle)
                    }
                }

                Section {
                    ForEach(store.scoreboard, id: \.item.id) { entry in
                        LabeledContent {
                            Text(entry.yes, format: .number)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        } label: {
                            Text(entry.item.label ?? "")
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
                                        winner: store.winners[poll.id],
                                        isExpanded: store.expanded == poll.id,
                                        canDelete: store.state.canDelete(poll)
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
            .animation(Motion.spring, value: store.polls)
            .animation(Motion.spring, value: store.expanded)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PollHistoryRow: View {
    let poll: Poll
    let winner: PollItem?
    let isExpanded: Bool
    let canDelete: Bool
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
                    if let winner {
                        HStack(spacing: 10) {
                            RemoteImage(
                                url: TMDbImageWidth.url(for: winner.thumbnailURL, width: .w185),
                                targetSize: CGSize(width: 44, height: 66)
                            )
                            .frame(width: 44, height: 66)
                            .clipShape(.rect(cornerRadius: 6, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.previousPollsWinner)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(winner.label ?? "")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .transition(.opacity)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(L10n.previousPollsNoWinner)
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
