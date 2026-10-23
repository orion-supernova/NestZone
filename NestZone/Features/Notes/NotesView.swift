import ComposableArchitecture
import SwiftUI

/// The noticeboard: a masonry-ish grid of coloured cards.
public struct NotesView: View {
    @Bindable var store: StoreOf<NotesFeature>

    @Environment(\.theme) private var theme

    /// The notes already on the board when it loaded. They are not news, so
    /// they never slap down — not on the first frame, and not when they scroll
    /// back into view. `nil` until the first load lands.
    @State private var baseline: Set<NoteID>?
    /// New notes that have already done their landing, so one that scrolls
    /// away and back is simply there.
    @State private var landed: Set<NoteID> = []
    /// When this person last pressed Save in the composer. A note of theirs
    /// that lands soon after is the one they just wrote, and only that one
    /// thuds — somebody else's note arriving is theirs to feel, not this
    /// phone's.
    @State private var savedAt = Date.distantPast
    @State private var thuds = 0

    public init(store: StoreOf<NotesFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            if store.isLoading {
                grid { SkeletonList(rows: 6, height: 120) }
            } else if store.visibleNotes.isEmpty {
                if store.searchText.isEmpty {
                    EmptyStateView(
                        title: L10n.notesEmptyStateTitle,
                        message: L10n.notesEmptyStateSubtitle,
                        symbol: "note.text",
                        action: .init(title: L10n.commonAdd) { store.send(.composeTapped) }
                    )
                    .padding(.top, 60)
                } else {
                    EmptyStateView(
                        title: L10n.notesSearchEmptyTitle,
                        message: L10n.notesSearchEmptyMessage,
                        symbol: "magnifyingglass"
                    )
                    .padding(.top, 60)
                }
            } else {
                notesGrid
            }
        }
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .segmentSearchable(text: $store.searchText, prompt: Text(L10n.notesSearchPlaceholder))
        .navigationTitle(Text(L10n.notesScreenTitle))
        .segmentToolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.composeTapped) } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(Text(L10n.notesComposeTitle))
            }
        }
        .task { await store.send(.task).finish() }
        .sheet(item: $store.scope(state: \.destination?.compose, action: \.destination.compose)) {
            ComposeNoteSheet(store: $0, onSave: { savedAt = .now })
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .onChange(of: store.isLoading, initial: true) { _, loading in
            if !loading, baseline == nil { baseline = Set(store.notes.ids) }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: thuds)
    }

    /// Arrived after the board loaded and not yet landed.
    private func isNew(_ note: Note) -> Bool {
        guard let baseline else { return false }
        return !baseline.contains(note.id) && !landed.contains(note.id)
    }

    /// Called as a new note first appears, which is when it slaps down.
    private func land(_ note: Note) {
        landed.insert(note.id)
        if store.state.canEdit(note), Date.now.timeIntervalSince(savedAt) < 30 {
            thuds += 1
        }
    }

    private func grid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().padding(.horizontal, Metrics.screenPadding)
    }

    private var notesGrid: some View {
        // No `GlassGroup` here: these are paper, not glass, and merging them
        // would be wrong. The spacing is wider than the app default so a tilted
        // note's corners never touch its neighbour.
        Group {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 18)],
                spacing: 18
            ) {
                ForEach(Array(store.visibleNotes.enumerated()), id: \.element.id) { index, note in
                    let fresh = isNew(note)
                    NoteCard(
                        note: note,
                        author: store.state.authorName(for: note),
                        canEdit: store.state.canEdit(note),
                        isNew: fresh,
                        onEdit: { store.send(.editTapped(note.id)) },
                        onDelete: { store.send(.deleteTapped(note.id)) }
                    )
                    .onAppear { if fresh { land(note) } }
                    // Only the first screenful is choreographed: the grid is
                    // lazy, so a note scrolled to later would otherwise fade in
                    // behind up to a third of a second of delay.
                    .appear(index < 8 ? index : 0)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .animation(Motion.spring, value: store.visibleNotes)
    }
}

private struct NoteCard: View {
    let note: Note
    let author: String
    let canEdit: Bool
    let isNew: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        StickyNote(
            text: note.body,
            color: StickyColor.parse(note.color),
            seed: note.id.rawValue,
            isNew: isNew
        ) {
            HStack(spacing: 4) {
                Text(verbatim: "— \(author)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.black.opacity(0.65))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let created = note.created {
                    RelativeTimeText(created)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.black.opacity(0.45))
                        .lineLimit(1)
                }
            }
        }
        .contextMenu {
            if canEdit {
                Button { onEdit() } label: {
                    Label { Text(L10n.commonEdit) } icon: { Image(systemName: "pencil") }
                }
                Button(role: .destructive) { onDelete() } label: {
                    Label { Text(L10n.commonDelete) } icon: { Image(systemName: "trash") }
                }
            }
        }
        .accessibilityLabel(Text(verbatim: "\(note.body). \(author)"))
        .accessibilityHint(canEdit ? Text(L10n.notesEditHint) : Text(""))
    }
}

struct ComposeNoteSheet: View {
    @Bindable var store: StoreOf<ComposeNoteFeature>
    /// Told about the Save tap itself, so the board can tell the note that
    /// lands next is this person's doing.
    var onSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    private var color: StickyColor { StickyColor.parse(store.color) }

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(tint: color.paper)

                ScrollView {
                    VStack(spacing: Metrics.sectionSpacing) {
                        preview
                        editor
                        colorPicker
                        inlineError
                    }
                    .padding(Metrics.screenPadding)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .animation(Motion.spring, value: store.color)
            }
            .navigationTitle(Text(store.isEditing ? L10n.notesEditTitle : L10n.notesComposeTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: { Text(L10n.commonCancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave()
                        store.send(.submitTapped)
                    } label: {
                        if store.isSubmitting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(L10n.commonSave).bold()
                        }
                    }
                    .disabled(!store.canSubmit)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.regularMaterial)
        .onAppear { isFocused = true }
    }

    /// The actual note, live. Seeing the thing you are making is what made the
    /// old composer feel friendly, and it costs nothing to keep.
    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.notesPreviewLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            StickyNote(
                text: store.body_.isEmpty
                    ? String(localized: L10n.notesPreviewPlaceholder)
                    : store.body_,
                color: color,
                // Stable while composing, so the preview does not re-tilt on
                // every keystroke.
                seed: store.editing?.id.rawValue ?? "compose"
            ) {
                HStack(spacing: 4) {
                    Text(L10n.notesAuthorYou)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.65))
                    Spacer(minLength: 0)
                    Text(L10n.notesPreviewNow)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.black.opacity(0.45))
                }
            }
            .frame(width: 190)
            .opacity(store.body_.isEmpty ? 0.75 : 1)
            .frame(maxWidth: .infinity)
        }
        .animation(Motion.fade, value: store.body_.isEmpty)
    }

    private var editor: some View {
        TextEditor(text: $store.body_)
            .focused($isFocused)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .scrollContentBackground(.hidden)
            .padding(12)
            .frame(minHeight: 130)
            .glassCard(cornerRadius: Metrics.tightRadius)
            .overlay(alignment: .topLeading) {
                if store.body_.isEmpty {
                    Text(L10n.notesComposePlaceholder)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.accessory)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.notesColorLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(StickyColor.allCases) { swatch in
                    let isSelected = swatch == color
                    Button { store.send(.colorSelected(swatch.storedValue)) } label: {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(swatch.paper)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
                            Text(swatch.displayName)
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(.primary)
                        .background {
                            if isSelected {
                                Capsule().fill(swatch.paper.opacity(0.55))
                            }
                        }
                        .glassEffect(isSelected ? .identity : .regular.interactive(), in: .capsule)
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
        .animation(Motion.spring, value: store.color)
    }

    @ViewBuilder
    private var inlineError: some View {
        if let error = store.inlineError {
            Label { Text(error) } icon: {
                Image(systemName: "exclamationmark.circle.fill")
            }
            .font(.caption)
            .foregroundStyle(Palette.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
