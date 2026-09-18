import ComposableArchitecture
import SwiftUI
import UIKit

/// The changelog, from the author's side.
///
/// Drafts on top, published below. That order is the point of the screen: the
/// unfinished note is the one that needs a decision, and a list sorted purely
/// by date would file it wherever it happened to be written.
struct InboxAdminView: View {
    @Bindable var store: StoreOf<InboxAdminFeature>

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(tint: theme.accent)

                if store.isLoading {
                    SkeletonList(rows: 4, height: 96)
                        .padding(.horizontal, Metrics.screenPadding)
                } else if store.updates.isEmpty {
                    EmptyStateView(
                        title: L10n.inboxAdminEmptyTitle,
                        message: L10n.inboxAdminEmptyMessage,
                        symbol: "square.and.pencil",
                        action: .init(title: L10n.inboxAdminNew) { store.send(.newTapped) }
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                            if !store.drafts.isEmpty {
                                group(
                                    title: L10n.inboxAdminDrafts,
                                    subtitle: L10n.inboxAdminDraftsNote,
                                    symbol: "pencil.line",
                                    rows: store.drafts
                                )
                            }
                            if !store.published.isEmpty {
                                group(
                                    title: L10n.inboxAdminPublished,
                                    subtitle: nil,
                                    symbol: "checkmark.seal.fill",
                                    rows: store.published
                                )
                            }
                            syncNote
                        }
                        .padding(.horizontal, Metrics.screenPadding)
                        .padding(.bottom, Metrics.screenPadding)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                }
            }
            .navigationTitle(Text(L10n.inboxAdminTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(L10n.commonDone) }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { store.send(.newTapped) } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(L10n.inboxAdminNew))
                }
            }
            .task { await store.send(.task).finish() }
        }
        .sheet(item: $store.scope(state: \.composer, action: \.composer)) {
            InboxComposerSheet(store: $0)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private func group(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource?,
        symbol: String,
        rows: [AppUpdate]
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(title, subtitle: subtitle, symbol: symbol)
            ForEach(rows) { update in
                AdminUpdateRow(
                    update: update,
                    isWorking: store.working.contains(update.id),
                    onEdit: { store.send(.editTapped(update)) },
                    onTogglePublish: { store.send(.publishToggled(update)) },
                    onDelete: { store.send(.deleteTapped(update)) }
                )
            }
        }
    }

    /// Where the changelog actually comes from.
    ///
    /// This panel is the exception, not the rule: the entries that matter are
    /// written into `backend/changelog.json` in the same commit as the work
    /// they describe, and synced on deploy. Saying so here is what stops the
    /// two drifting — an entry typed in the app that is not in the file will be
    /// left behind the next time somebody reads the file to find out what
    /// shipped.
    private var syncNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(L10n.inboxAdminSyncTitle)
                    .font(.footnote.weight(.semibold))
            } icon: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.footnote)
            }
            Text(L10n.inboxAdminSyncNote)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: "npx convex run inbox:syncChangelog \"$(cat changelog.json)\"")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.inset, in: .rect(cornerRadius: 8, style: .continuous))

            if let id = store.currentUserID {
                // The value for `ADMIN_USER_IDS`, which is the setting that
                // makes this screen reachable when an email allowlist cannot
                // work — and a setting whose value lives nowhere somebody can
                // read it is one nobody uses.
                Button {
                    UIPasteboard.general.string = id.rawValue
                } label: {
                    HStack(spacing: 6) {
                        Text(L10n.inboxAdminYourID)
                            .font(.caption2)
                        Text(id.rawValue)
                            .font(.system(.caption2, design: .monospaced))
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - A row on the author's desk

private struct AdminUpdateRow: View {
    let update: AppUpdate
    let isWorking: Bool
    let onEdit: () -> Void
    let onTogglePublish: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Badge(
                        String(localized: update.kind.label),
                        tint: update.kind.tint,
                        symbol: update.kind.symbol
                    )
                    if let version = update.version, !version.isEmpty {
                        Text(L10n.inboxVersionChip(version))
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Palette.inset, in: .capsule)
                    }
                    if update.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    if update.isDraft {
                        Badge(String(localized: L10n.inboxAdminDraft), tint: Palette.spendOther)
                    } else if update.isComingSoon {
                        // Says the same thing the reader's card says, so the
                        // author can see who is actually going to get this.
                        Badge(String(localized: L10n.inboxComingSoon), tint: Palette.amber, symbol: "clock")
                    }
                }

                Text(update.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(update.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                HStack(spacing: 10) {
                    Button(action: onEdit) {
                        Label { Text(L10n.commonEdit) } icon: { Image(systemName: "pencil") }
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)

                    Button(action: onTogglePublish) {
                        Label {
                            Text(update.isDraft ? L10n.inboxAdminPublish : L10n.inboxAdminUnpublish)
                        } icon: {
                            Image(systemName: update.isDraft ? "paperplane.fill" : "eye.slash")
                        }
                        .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(isWorking)

                    Spacer(minLength: 0)

                    if isWorking {
                        ProgressView().controlSize(.small)
                    }

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .tint(Palette.danger)
                    .accessibilityLabel(Text(L10n.commonDelete))
                }
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - The form

/// Writing one release note.
struct InboxComposerSheet: View {
    @Bindable var store: StoreOf<InboxComposerFeature>

    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(tint: theme.accent)

                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                        kindPicker
                        fields
                        highlights
                        ForEach(AppLanguage.translatable) { language in
                            translation(language)
                        }
                        options
                    }
                    .padding(Metrics.screenPadding)
                    .padding(.bottom, Metrics.screenPadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text(store.isEditing ? L10n.inboxAdminEditTitle : L10n.inboxAdminNewTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { store.send(.cancelTapped) } label: { Text(L10n.commonCancel) }
                }
                ToolbarItem(placement: .confirmationAction) { saveMenu }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }

    /// Save as a draft, or save and publish. Two verbs and one form, because
    /// they are the same write with one flag different — and because "publish"
    /// has to be a deliberate act rather than something a Save button does on
    /// somebody's behalf.
    private var saveMenu: some View {
        Menu {
            Button {
                store.send(.saveTapped(publish: true))
            } label: {
                Label { Text(L10n.inboxAdminSavePublish) } icon: {
                    Image(systemName: "paperplane.fill")
                }
            }
            Button {
                store.send(.saveTapped(publish: false))
            } label: {
                Label { Text(L10n.inboxAdminSaveDraft) } icon: {
                    Image(systemName: "tray.and.arrow.down")
                }
            }
        } label: {
            if store.isSaving {
                ProgressView().controlSize(.small)
            } else {
                Text(L10n.commonSave).font(.body.weight(.semibold))
            }
        }
        .disabled(!store.canSave)
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.inboxAdminKind, symbol: "tag.fill")
            GlassGroup(spacing: 8) {
                // Wraps rather than scrolls: four is few enough to show at once,
                // and a picker you have to scroll hides the option you want.
                FlowLayout(spacing: 8) {
                    ForEach(UpdateKind.allCases) { kind in
                        Chip(
                            String(localized: kind.label),
                            symbol: kind.symbol,
                            isSelected: store.draft.kind == kind
                        ) {
                            $store.draft.kind.wrappedValue = kind
                        }
                    }
                }
            }
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            GlassTextField(
                L10n.inboxAdminFieldTitle,
                text: $store.draft.title,
                symbol: "textformat"
            )

            GlassTextField(
                L10n.inboxAdminFieldVersion,
                text: $store.draft.version,
                symbol: "number"
            )

            // The one field whose meaning is not obvious from its label, and
            // the one that decides who sees what.
            Text(L10n.inboxAdminVersionHelp(AppVersion.current.raw))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.inboxAdminFieldBody)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                TextEditor(text: $store.draft.body)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(10)
                    .glassCard(cornerRadius: Metrics.tightRadius)
            }
        }
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.inboxAdminHighlights,
                subtitle: L10n.inboxAdminHighlightsNote,
                symbol: "checklist"
            ) {
                Button { store.send(.highlightAdded) } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .accessibilityLabel(Text(L10n.inboxAdminHighlightAdd))
            }

            ForEach(Array(store.draft.highlights.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(store.draft.kind.tint)
                    TextField(
                        String(localized: L10n.inboxAdminHighlightPlaceholder),
                        text: $store.draft.highlights[index]
                    )
                    .font(.footnote)
                    Button { store.send(.highlightRemoved(index)) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Palette.accessory)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(L10n.commonDelete))
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .glassCard(cornerRadius: Metrics.tightRadius)
            }
        }
    }

    /// The same note in one other language.
    ///
    /// Driven by `AppLanguage.translatable` rather than a hardcoded Turkish
    /// section, so adding a language to the app adds it to this form without
    /// anybody remembering to. Leaving one blank is fine and is the normal
    /// case — an untranslated note falls back to the English above it.
    private func translation(_ language: AppLanguage) -> some View {
        // Built by hand rather than with a defaulted dictionary subscript: the
        // store's dynamic member lookup does not reach through one, and a
        // missing entry has to read as an empty note rather than as nothing to
        // bind to.
        let code = language.rawValue
        let binding = Binding<LocalizedUpdate>(
            get: { store.draft.translations[code] ?? LocalizedUpdate(title: "", body: "") },
            set: { $store.draft.translations.wrappedValue[code] = $0 }
        )
        return VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.inboxAdminTranslation(language.endonym),
                subtitle: L10n.inboxAdminTranslationNote,
                symbol: "character.bubble"
            ) {
                Text(verbatim: language.flag)
            }

            GlassTextField(
                L10n.inboxAdminFieldTitle,
                text: binding.title,
                symbol: "textformat"
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.inboxAdminFieldBody)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                TextEditor(text: binding.body)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(10)
                    .glassCard(cornerRadius: Metrics.tightRadius)
            }

            // Bullets track the English ones by position, so the form shows
            // exactly as many slots as there are bullets to translate — one
            // more would be a bullet with no counterpart, which the card has
            // nowhere to draw.
            ForEach(Array(store.draft.highlights.enumerated()), id: \.offset) { index, english in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(store.draft.kind.tint)
                    TextField(
                        english.isEmpty
                            ? String(localized: L10n.inboxAdminHighlightPlaceholder)
                            : english,
                        text: highlightBinding(binding, index)
                    )
                    .font(.footnote)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .glassCard(cornerRadius: Metrics.tightRadius)
            }
        }
    }

    /// A binding into one bullet of one language, padding the array out to
    /// reach it.
    ///
    /// The translated bullets are a parallel array to the English ones, and a
    /// person may well fill in the third before the first. Writing straight to
    /// `highlights[index]` would trap on an array that is still empty, so the
    /// setter grows it with blanks and the getter treats "not there yet" as "".
    private func highlightBinding(
        _ translation: Binding<LocalizedUpdate>,
        _ index: Int
    ) -> Binding<String> {
        Binding(
            get: {
                let all = translation.wrappedValue.highlights
                return all.indices.contains(index) ? all[index] : ""
            },
            set: { value in
                var all = translation.wrappedValue.highlights
                while all.count <= index { all.append("") }
                all[index] = value
                translation.wrappedValue.highlights = all
            }
        )
    }

    private var options: some View {
        GlassCard {
            Toggle(isOn: $store.draft.isPinned) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.inboxAdminPin).font(.subheadline.weight(.semibold))
                    Text(L10n.inboxAdminPinNote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(theme.accent)
        }
    }
}
