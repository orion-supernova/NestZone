import ComposableArchitecture
import PhotosUI
import SwiftUI
import UIKit

// The four sheets the Problems module presents.
//
// Three of them are deliberately tiny. A status note, a handful of parts and a
// visit date are each one question, and a full-screen form in front of a
// one-tap act is how a household stops keeping any of it up to date. Only the
// report itself earns a whole sheet — and even that is folded, with the four
// fields that matter above the crease and everything optional below it.

// MARK: - Shared chrome

/// Cancel and save, with the keyboard put away first.
///
/// A focused field writes its binding one last time as it resigns, and
/// dismissing the sheet before that happens means the write lands after the
/// store's presentation state is already `nil` — TCA's "received a presentation
/// action when destination state was absent" runtime warning, on every cancel.
/// Resigning first puts the last write back inside the sheet's own lifetime.
private struct IssueSheetToolbar: ToolbarContent {
    let isSubmitting: Bool
    let canSubmit: Bool
    let title: LocalizedStringResource
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
                    Text(title).bold()
                }
            }
            .disabled(!canSubmit)
            .sensoryFeedback(.impact(weight: .medium), trigger: isSubmitting) { was, now in
                !was && now
            }
        }
    }
}

private struct IssueInlineError: View {
    let message: String

    var body: some View {
        Label { Text(message) } icon: {
            Image(systemName: "exclamationmark.circle.fill")
        }
        .font(.footnote)
        .foregroundStyle(Palette.danger)
        .transition(.opacity.combined(with: .offset(y: -4)))
    }
}

// MARK: - Reporting a problem

/// Reporting something broken, or editing the report.
///
/// The four fields at the top are the ones every count, every grouping and every
/// "this has happened before" is built on, so they are pickers rather than text.
/// Everything else lives behind a disclosure: a report has to be fast enough to
/// make while standing in front of the broken thing, or it does not get made.
struct IssueComposerSheet: View {
    @Bindable var store: StoreOf<IssueComposerFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var picked: [PhotosPickerItem] = []
    @State private var isPickingCurrency = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    whatCard.appear(0)
                    severityPicker.appear(1)
                    roomPicker.appear(2)
                    categoryPicker.appear(3)
                    if !store.isEditing {
                        photosCard.appear(4)
                    }
                    assigneeCard.appear(5)
                    moreCard.appear(6)

                    if let error = store.inlineError {
                        IssueInlineError(message: error)
                    }
                }
                .padding(Metrics.screenPadding)
                .shake(on: store.shakes)
            }
            .background(Backdrop(tint: theme.accent))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(store.isEditing
                ? L10n.issuesEditTitle
                : L10n.issuesReportTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                IssueSheetToolbar(
                    isSubmitting: store.isSubmitting,
                    canSubmit: store.canSubmit,
                    title: store.isEditing ? L10n.commonSave : L10n.issuesReport,
                    onSubmit: { store.send(.submitTapped) },
                    onCancel: { dismiss() }
                )
            }
            .onChange(of: picked) { _, items in
                guard !items.isEmpty else { return }
                picked = []
                Task {
                    var loaded: [Data] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            loaded.append(data)
                        }
                    }
                    store.send(.photosPicked(loaded))
                }
            }
            .animation(Motion.spring, value: store.showsMore)
            .animation(Motion.fade, value: store.inlineError)
        }
    }

    private var whatCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                TextField(text: $store.title) {
                    Text(L10n.issuesTitlePlaceholder)
                }
                .font(.body.weight(.medium))
                .textInputAutocapitalization(.sentences)

                Divider().opacity(0.4)

                TextField(text: $store.details, axis: .vertical) {
                    Text(L10n.issuesDetailsPlaceholder)
                }
                .font(.subheadline)
                .lineLimit(2...6)
                .textInputAutocapitalization(.sentences)
            }
        }
    }

    /// How bad it is, as four cards with a sentence each.
    ///
    /// Explained rather than merely labelled, because "major" is a word two
    /// people in the same house will read differently — and a severity nobody
    /// sets the same way twice is a severity that cannot sort anything.
    private var severityPicker: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.issuesHowBadTitle, symbol: "exclamationmark.triangle")

            HStack(spacing: 8) {
                ForEach(IssueSeverity.allCases) { severity in
                    let isSelected = store.severity == severity
                    Button { store.send(.severityTapped(severity)) } label: {
                        VStack(spacing: 5) {
                            Image(systemName: severity.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected ? Color.white : severity.tint)
                                .bounces(when: isSelected)
                            Text(severity.title)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: Metrics.tightRadius, style: .continuous)
                                    .fill(severity.tint)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.pressable)
                    .glassCard(cornerRadius: Metrics.tightRadius)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }

            Text(store.severity.explainer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
        }
        .animation(Motion.spring, value: store.severity)
    }

    /// Where it is.
    ///
    /// Two shelves rather than one list of fourteen: inside and outside is how
    /// anybody thinks about their own home, and it halves the scanning.
    private var roomPicker: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.issuesWhereTitle, symbol: "map")

            VStack(alignment: .leading, spacing: 10) {
                roomShelf(L10n.issuesRoomsIndoors, areas: IssueArea.indoors)
                roomShelf(L10n.issuesRoomsOutdoors, areas: IssueArea.outdoors)
            }
        }
    }

    private func roomShelf(
        _ title: LocalizedStringResource,
        areas: [IssueArea]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(areas) { area in
                    Chip(
                        String(localized: area.title),
                        symbol: area.symbol,
                        isSelected: store.area == area
                    ) { store.send(.areaTapped(area)) }
                }
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.issuesWhatKindTitle,
                subtitle: L10n.issuesWhatKindSubtitle,
                symbol: "wrench.and.screwdriver"
            )
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(IssueCategory.allCases) { category in
                    Chip(
                        String(localized: category.title),
                        symbol: category.symbol,
                        isSelected: store.category == category
                    ) { store.send(.categoryTapped(category)) }
                }
            }
        }
    }

    /// Pictures of the fault.
    ///
    /// Nothing explains a leak like a photo of it, and a plumber asked over the
    /// phone will ask for one — which is why this sits above the fold rather
    /// than in the optional half.
    private var photosCard: some View {
        // Read out here for the reason the detail screen's composer does it:
        // `PhotosPicker`'s label closure is `@Sendable`, and reaching into the
        // store or the environment from inside one is a concurrency warning.
        let isPreparing = store.isPreparingPhotos
        let accent = theme.accent
        return VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.issuesPhotosTitle,
                subtitle: L10n.issuesPhotosSubtitle,
                symbol: "camera"
            )

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(store.photos.enumerated()), id: \.offset) { index, data in
                        if let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 84, height: 84)
                                .clipShape(.rect(cornerRadius: Metrics.tightRadius, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    Button { store.send(.photoRemoved(index)) } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 20, height: 20)
                                            .background(.black.opacity(0.55), in: .circle)
                                            .contentShape(.circle)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(4)
                                    .accessibilityLabel(Text(L10n.issuesPhotoRemove))
                                }
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    if store.remainingPhotoSlots > 0 {
                        PhotosPicker(
                            selection: $picked,
                            maxSelectionCount: store.remainingPhotoSlots,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            VStack(spacing: 5) {
                                if isPreparing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "camera.fill").font(.body)
                                }
                                Text(L10n.issuesAddPhoto)
                                    .font(.caption2)
                            }
                            .foregroundStyle(accent)
                            .frame(width: 84, height: 84)
                            .contentShape(.rect)
                        }
                        .glassCard(cornerRadius: Metrics.tightRadius)
                        .disabled(isPreparing)
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
        .animation(Motion.spring, value: store.photos.count)
    }

    private var assigneeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.issuesWhoTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(store.orderedMembers) { member in
                        Chip(
                            member.id == store.currentUserID
                                ? String(localized: L10n.issuesYou)
                                : member.displayName,
                            symbol: "person.fill",
                            isSelected: store.assignedTo == member.id
                        ) { store.send(.assigneeTapped(member.id)) }
                    }
                }
            }
        }
    }

    /// Everything optional, folded away.
    private var moreCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: store.showsMore ? 16 : 0) {
                Button { store.send(.moreToggled) } label: {
                    HStack {
                        Text(L10n.issuesMoreTitle)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.accessory)
                            .rotationEffect(.degrees(store.showsMore ? 0 : -90))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                if store.showsMore {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider().opacity(0.4)

                        Toggle(isOn: $store.hasDeadline) {
                            Text(L10n.issuesDeadlineTitle)
                                .font(.subheadline)
                        }
                        if store.hasDeadline {
                            DatePicker(
                                selection: $store.dueBy,
                                displayedComponents: .date
                            ) {
                                Text(L10n.issuesDeadlineBy).font(.caption)
                            }
                            .datePickerStyle(.compact)
                        }

                        Divider().opacity(0.4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.issuesEstimateTitle)
                                .font(.subheadline)
                            HStack(spacing: 10) {
                                TextField(text: $store.estimateText) {
                                    Text(verbatim: "0")
                                }
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .keyboardType(.decimalPad)
                                .monospacedDigit()

                                Button {
                                    isPickingCurrency = true
                                } label: {
                                    HStack(spacing: 3) {
                                        Text(store.currency)
                                            .font(.caption.weight(.semibold))
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .glassEffect(.regular.interactive(), in: .capsule)
                                    .contentShape(.capsule)
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $isPickingCurrency) {
                                    CurrencyPicker(
                                        selected: store.currency,
                                        used: store.currencyOptions
                                    ) { code in
                                        store.send(.binding(.set(\.currency, code)))
                                    }
                                }
                            }
                            Text(L10n.issuesEstimateHint)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Divider().opacity(0.4)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.issuesVendorTitle)
                                .font(.subheadline)
                            TextField(text: $store.vendorName) {
                                Text(L10n.issuesVendorNamePlaceholder)
                            }
                            .font(.subheadline)
                            .textInputAutocapitalization(.words)
                            TextField(text: $store.vendorPhone) {
                                Text(L10n.issuesVendorPhonePlaceholder)
                            }
                            .font(.subheadline)
                            .keyboardType(.phonePad)
                            TextField(text: $store.vendorURL) {
                                Text(L10n.issuesVendorUrlPlaceholder)
                            }
                            .font(.subheadline)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        }

                        Divider().opacity(0.4)

                        Toggle(isOn: $store.hasWarranty) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L10n.issuesWarrantyTitle).font(.subheadline)
                                Text(L10n.issuesWarrantyHint)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if store.hasWarranty {
                            DatePicker(
                                selection: $store.warrantyUntil,
                                displayedComponents: .date
                            ) {
                                Text(L10n.issuesWarrantyUntilLabel).font(.caption)
                            }
                            .datePickerStyle(.compact)
                        }
                    }
                    .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }
        }
    }
}

// MARK: - A sentence before a status moves

/// The little sheet that asks what fixed it, or what it is waiting for.
///
/// Two of the seven moves genuinely want a line — the resolution is the most
/// useful sentence in this module the next time the same thing goes, and being
/// blocked is *entirely* the thing it is blocked on. The other five go straight
/// through: a form in front of every tap is how a status stops being kept up to
/// date.
struct StatusNoteSheet: View {
    let note: IssueDetailFeature.StatusNote
    @Binding var text: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: note.status.symbol)
                        .font(.title3)
                        .foregroundStyle(note.status.tint)
                        .frame(width: 42, height: 42)
                        .background(note.status.tint.opacity(0.16), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.status.title)
                            .font(.headline)
                        Text(note.prompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                TextField(text: $text, axis: .vertical) {
                    Text(note.placeholder)
                }
                .font(.subheadline)
                .lineLimit(3...6)
                .focused($isFocused)
                .textInputAutocapitalization(.sentences)
                .padding(14)
                .glassCard(cornerRadius: Metrics.tightRadius)

                // Optional on purpose. Refusing to record a fix because nobody
                // felt like writing a sentence about it would lose the fact
                // that it was fixed at all, which is the more important half.
                Text(L10n.issuesStatusNoteOptional)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(Metrics.screenPadding)
            .background(Backdrop(tint: theme.accent))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                IssueSheetToolbar(
                    isSubmitting: false,
                    canSubmit: true,
                    title: L10n.commonSave,
                    onSubmit: onConfirm,
                    onCancel: onCancel
                )
            }
            .onAppear { isFocused = true }
        }
    }
}

// MARK: - Parts

/// Parts on their way to the shopping list, one per line.
///
/// A plain text box rather than a row editor: what somebody has in their head
/// standing in front of a dripping tap is "washer, PTFE tape, new trap", and
/// making them press "+" three times to say it is the reason the parts never get
/// added at all.
struct PartsSheet: View {
    @Binding var text: String
    let isReady: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.issuesPartsHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField(text: $text, axis: .vertical) {
                    Text(L10n.issuesPartsPlaceholder)
                }
                .font(.subheadline)
                .lineLimit(6...14)
                .focused($isFocused)
                .textInputAutocapitalization(.sentences)
                .padding(14)
                .glassCard(cornerRadius: Metrics.tightRadius)

                Label {
                    Text(L10n.issuesPartsSkipNote)
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(Metrics.screenPadding)
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(L10n.issuesPartsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                IssueSheetToolbar(
                    isSubmitting: false,
                    canSubmit: isReady,
                    title: L10n.commonAdd,
                    onSubmit: onConfirm,
                    onCancel: onCancel
                )
            }
            .onAppear { isFocused = true }
        }
    }
}

// MARK: - Booking a visit

/// When somebody is coming.
///
/// It writes an ordinary calendar event, so the household's Saturday shows the
/// boiler engineer alongside everything else it is doing — rather than a private
/// appointment only this screen can see.
struct VisitSheet: View {
    @Binding var draft: IssueDetailFeature.VisitDraft
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            DatePicker(
                                selection: $draft.startsAt,
                                displayedComponents: [.date, .hourAndMinute]
                            ) {
                                Text(L10n.issuesVisitWhen).font(.subheadline)
                            }
                            .datePickerStyle(.compact)

                            Divider().opacity(0.4)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.issuesVisitLength)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    ForEach(IssueDetailFeature.VisitDraft.durationChoices, id: \.self) { minutes in
                                        Chip(
                                            String(localized: L10n.issuesVisitMinutes(minutes)),
                                            isSelected: draft.durationMinutes == minutes
                                        ) { draft.durationMinutes = minutes }
                                    }
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField(text: $draft.title) {
                                Text(L10n.issuesVisitWhoPlaceholder)
                            }
                            .font(.subheadline)
                            .textInputAutocapitalization(.words)

                            Divider().opacity(0.4)

                            TextField(text: $draft.location) {
                                Text(L10n.issuesVisitWherePlaceholder)
                            }
                            .font(.subheadline)
                            .textInputAutocapitalization(.sentences)
                        }
                    }

                    VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                        SectionHeader(L10n.issuesVisitRemindTitle, symbol: "bell")
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(IssueDetailFeature.VisitDraft.reminderChoices, id: \.self) { minutes in
                                Chip(
                                    String(localized: reminderTitle(minutes)),
                                    isSelected: draft.reminder == minutes
                                ) { draft.reminder = minutes }
                            }
                        }
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Backdrop(tint: theme.accent))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(L10n.issuesVisitTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                IssueSheetToolbar(
                    isSubmitting: false,
                    canSubmit: true,
                    title: L10n.issuesVisitBook,
                    onSubmit: onConfirm,
                    onCancel: onCancel
                )
            }
        }
    }

    /// Zero is "no reminder", not "as it starts": a notification that fires as
    /// the doorbell goes is not a reminder.
    private func reminderTitle(_ minutes: Int) -> LocalizedStringResource {
        switch minutes {
        case 0: L10n.issuesRemindNone
        case 60: L10n.issuesRemindHour
        case 240: L10n.issuesRemindFourHours
        default: L10n.issuesRemindDayBefore
        }
    }
}
