import ComposableArchitecture
import SwiftUI

public struct MoviesView: View {
    @Bindable var store: StoreOf<MoviesFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<MoviesFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                if store.isLoading {
                    SkeletonList(rows: 3, height: 76)
                        .padding(.horizontal, Metrics.screenPadding)
                } else {
                    presetSection
                    customSection
                }
            }
            .padding(.top, Metrics.stackSpacing)
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.movieListsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.createListTapped) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(L10n.moviesNewListTitle))
            }
        }
        .task { await store.send(.task).finish() }
        .navigationDestination(item: $store.scope(
            state: \.destination?.list, action: \.destination.list
        )) { MovieListView(store: $0) }
        .sheet(item: $store.scope(
            state: \.destination?.createList, action: \.destination.createList
        )) { CreateMovieListSheet(store: $0) }
        .alert($store.scope(state: \.alert, action: \.alert))
        .animation(Motion.spring, value: store.lists)
    }

    @ViewBuilder
    private var presetSection: some View {
        if !store.presets.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                SectionHeader(L10n.movieListsQuickCollections, symbol: "sparkles")
                    .padding(.horizontal, Metrics.screenPadding)
                GlassGroup {
                    VStack(spacing: Metrics.stackSpacing) {
                        ForEach(Array(store.presets.enumerated()), id: \.element.id) { index, list in
                            ListRow(list: list, canDelete: false) {
                                store.send(.listTapped(list))
                            } onDelete: {}
                                .appear(index)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.movieListsCustomLists, symbol: "list.star")
                .padding(.horizontal, Metrics.screenPadding)

            if store.customLists.isEmpty {
                EmptyStateView(
                    title: L10n.movieListsNoCustomLists,
                    message: L10n.movieListsNoCustomListsSubtitle,
                    symbol: "list.star",
                    action: .init(title: L10n.movieListsCreateFirstList) {
                        store.send(.createListTapped)
                    }
                )
                .padding(.vertical, 24)
            } else {
                GlassGroup {
                    VStack(spacing: Metrics.stackSpacing) {
                        ForEach(Array(store.customLists.enumerated()), id: \.element.id) { index, list in
                            ListRow(list: list, canDelete: true) {
                                store.send(.listTapped(list))
                            } onDelete: {
                                store.send(.deleteListTapped(list.id))
                            }
                            .appear(index)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
        }
    }
}

private struct ListRow: View {
    let list: MovieList
    let canDelete: Bool
    let action: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: list.kind.symbol)
                    .font(.title3)
                    .foregroundStyle(list.kind.tint)
                    .frame(width: 44, height: 44)
                    .background(list.kind.tint.opacity(0.14), in: .rect(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name).font(.headline).foregroundStyle(.primary)
                    if let summary = list.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                }
            }
        }
    }
}

struct MovieListView: View {
    @Bindable var store: StoreOf<MovieListFeature>

    @Environment(\.theme) private var theme

    private let poster = CGSize(width: 104, height: 156)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                header
                savedMovies
            }
            .padding(.top, Metrics.stackSpacing)
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(store.list.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.addMoviesTapped) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(L10n.movieListDetailAddMovies))
            }
        }
        .task { await store.send(.task).finish() }
        .sheet(isPresented: Binding(
            get: { store.isSearchPresented },
            set: { if !$0 { store.send(.searchDismissed) } }
        )) {
            AddMoviesSheet(store: store, poster: poster)
        }
        .sheet(item: $store.scope(state: \.detail, action: \.detail)) {
            MovieInfoSheet(store: $0)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .animation(Motion.spring, value: store.movies)
    }

    /// What the list is and how big it is — the old detail screen led with this.
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: store.list.kind.symbol)
                .font(.title2)
                .foregroundStyle(store.list.kind.tint)
                .frame(width: 52, height: 52)
                .background(
                    store.list.kind.tint.opacity(0.14),
                    in: .rect(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(store.list.name).font(.headline)
                if let summary = store.list.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                AnimatedNumber(store.movies.count)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(store.list.kind.tint)
                Text(L10n.movieListsMoviesCount)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Metrics.cardPadding)
        .glassCard()
        .padding(.horizontal, Metrics.screenPadding)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var savedMovies: some View {
        if store.isLoading {
            SkeletonList(rows: 3, height: 84)
                .padding(.horizontal, Metrics.screenPadding)
        } else if store.movies.isEmpty {
            EmptyStateView(
                title: L10n.movieListDetailNoMovies,
                message: L10n.moviesEmptyListMessage,
                symbol: "film",
                action: .init(title: L10n.movieListDetailAddMovies) {
                    store.send(.addMoviesTapped)
                }
            )
            .padding(.top, 40)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: poster.width), spacing: Metrics.stackSpacing)],
                spacing: Metrics.sectionSpacing
            ) {
                ForEach(Array(store.movies.enumerated()), id: \.element.id) { index, stored in
                    PosterCard(
                        title: stored.title,
                        year: stored.year,
                        url: stored.posterURL(width: .w342),
                        size: poster,
                        isSaved: true
                    ) {}
                    .onTapGesture { store.send(.movieTapped(stored)) }
                    .contextMenu {
                        Button(role: .destructive) {
                            store.send(.removeTapped(stored.id))
                        } label: {
                            Label { Text(L10n.commonRemove) } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    .appear(index)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }
}

/// Search, in its own sheet, so the list screen stays a collection.
struct AddMoviesSheet: View {
    @Bindable var store: StoreOf<MovieListFeature>
    let poster: CGSize

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.isSearching && store.results.isEmpty {
                    SkeletonList(rows: 3, height: poster.height)
                        .padding(.horizontal, Metrics.screenPadding)
                } else if store.results.isEmpty {
                    EmptyStateView(
                        title: L10n.moviesSearchPrompt,
                        symbol: "magnifyingglass"
                    )
                    .padding(.top, 60)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: poster.width), spacing: Metrics.stackSpacing)],
                        spacing: Metrics.sectionSpacing
                    ) {
                        ForEach(store.results) { movie in
                            PosterCard(
                                title: movie.title,
                                year: movie.year,
                                url: movie.posterURL(width: .w342),
                                size: poster,
                                isSaved: store.savedIDs.contains(movie.id)
                            ) { store.send(.addTapped(movie)) }
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, Metrics.sectionSpacing)
                }
            }
            .background(Backdrop(tint: theme.accent))
            .searchable(
                text: Binding(
                    get: { store.searchText },
                    set: { store.send(.searchChanged($0)) }
                ),
                prompt: Text(L10n.moviesSearchPlaceholder)
            )
            .navigationTitle(Text(L10n.movieListDetailAddMovies))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text(L10n.commonDone) }
                }
            }
        }
        .presentationDetents([.large])
    }
}

/// Poster, plot, cast — fetched when the sheet opens.
struct MovieInfoSheet: View {
    let store: StoreOf<MovieInfoFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    RemoteImage(
                        url: store.movie.posterURL(width: .w500),
                        targetSize: CGSize(width: 200, height: 300)
                    )
                    .frame(width: 200, height: 300)
                    .clipShape(.rect(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: .infinity)
                    .appear(0)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.movie.title)
                            .font(.title2.weight(.bold))
                        if let year = store.movie.year {
                            Text(year, format: .number.grouping(.never))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .appear(1)

                    if let extras = store.extras {
                        facts(extras).appear(2)
                        if let plot = extras.plot, !plot.isEmpty {
                            Text(plot).font(.callout).appear(3)
                        }
                        if !extras.cast.isEmpty {
                            castRow(extras).appear(4)
                        }
                    } else if store.isLoading {
                        SkeletonList(rows: 2, height: 56)
                    }
                }
                .padding(Metrics.screenPadding)
                .padding(.bottom, Metrics.sectionSpacing)
            }
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(L10n.moviesDetailTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text(L10n.commonDone) }
                }
            }
            .task { await store.send(.task).finish() }
        }
        .presentationDetents([.large])
    }

    private func facts(_ extras: MovieExtras) -> some View {
        GlassGroup {
            HStack(spacing: Metrics.stackSpacing) {
                if let rating = extras.rating {
                    fact("star.fill", String(format: "%.1f", rating), L10n.moviesDetailRating)
                }
                if let runtime = extras.runtimeMinutes {
                    fact("clock", "\(runtime)m", L10n.moviesDetailRuntime)
                }
                if let director = extras.directors.first {
                    fact("megaphone", director, L10n.moviesDetailDirector)
                }
            }
        }
    }

    private func fact(_ symbol: String, _ value: String, _ label: LocalizedStringResource) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.callout).foregroundStyle(.tint)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: Metrics.tightRadius)
    }

    private func castRow(_ extras: MovieExtras) -> some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.moviesDetailCast, symbol: "person.2")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(extras.cast) { member in
                        VStack(spacing: 6) {
                            RemoteImage(
                                url: member.profileURL,
                                targetSize: CGSize(width: 62, height: 62)
                            )
                            .frame(width: 62, height: 62)
                            .clipShape(.circle)
                            Text(member.name)
                                .font(.caption2)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 72)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// A poster with its title underneath. Requests the poster at the size it is
/// actually drawn, rather than TMDb's `w500` for every thumbnail.
struct PosterCard: View {
    let title: String
    let year: Int?
    let url: URL?
    let size: CGSize
    let isSaved: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: url, targetSize: size)
                .frame(width: size.width, height: size.height)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if isSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.white, Palette.success)
                            .padding(6)
                    } else {
                        Button(action: onAdd) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .buttonStyle(.pressable)
                        .padding(6)
                        .accessibilityLabel(Text(L10n.moviesAddToList))
                    }
                }

            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let year {
                Text(year, format: .number.grouping(.never))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size.width, alignment: .leading)
    }
}

struct CreateMovieListSheet: View {
    @Bindable var store: StoreOf<CreateMovieListFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(tint: theme.accent)
                VStack(spacing: Metrics.stackSpacing) {
                    GlassTextField(
                        L10n.moviesListNameLabel,
                        text: $store.name,
                        symbol: "list.star",
                        error: store.inlineError.map { LocalizedStringResource(stringLiteral: $0) }
                    )
                    GlassTextField(
                        L10n.recipesComposeSummaryLabel,
                        text: $store.summary,
                        symbol: "text.alignleft"
                    )
                    PrimaryButton(L10n.commonSave, isLoading: store.isSubmitting) {
                        store.send(.submitTapped)
                    }
                    .disabled(!store.canSubmit)
                    Spacer(minLength: 0)
                }
                .padding(Metrics.screenPadding)
            }
            .navigationTitle(Text(L10n.moviesNewListTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: { Text(L10n.commonCancel) }
                }
            }
        }
        .presentationDetents([.height(320)])
        .presentationBackground(.regularMaterial)
    }
}
