import ComposableArchitecture
import PhotosUI
import SwiftUI

/// One house problem, and everything the household has done about it.
///
/// Read top to bottom it is a story: here is the thing, here is how bad it is,
/// here is how far along it has got, here is what has been arranged about it,
/// and here is what everybody has said. The plan card in the middle is the part
/// that makes this more than a note — four buttons that each write a real row in
/// another module rather than a private copy of one.
public struct IssueDetailView: View {
    @Bindable var store: StoreOf<IssueDetailFeature>

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @Namespace private var glass
    @State private var picked: [PhotosPickerItem] = []
    @FocusState private var isComposing: Bool

    public init(store: StoreOf<IssueDetailFeature>) {
        self.store = store
    }

    private var issue: HouseIssue { store.current }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.sectionSpacing) {
                if !issue.photos.isEmpty {
                    IssuePhotoStrip(photos: issue.photos) { storageID in
                        store.send(.removePhotoTapped(storageID))
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .appear(0)
                }

                headline.appear(1)
                statusCard.appear(2)

                if store.awaitsVerdict {
                    verdictPrompt.appear(3)
                }

                planCard.appear(4)

                if issue.vendorName != nil || issue.vendorPhone != nil {
                    vendorCard.appear(5)
                }
                if !store.previously.isEmpty {
                    previouslyCard.appear(6)
                }

                timelineCard.appear(7)
            }
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(issue.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { overflowMenu }
        }
        .safeAreaInset(edge: .bottom) { composer }
        // The problem is fixed. The one thing on this screen worth celebrating.
        .overlay { ConfettiBurst(trigger: store.fixedCelebration) }
        .task { await store.send(.task).finish() }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            // Cleared immediately so the picker is ready for the next set and a
            // re-render cannot re-send the same images.
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
        .alert($store.scope(state: \.alert, action: \.alert))
        .confirmationDialog($store.scope(state: \.confirm, action: \.confirm))
        // `Binding(_:)` on an optional binding is the projection these three
        // want: it hands back a non-optional binding while the value is there
        // and `nil` once it is gone. A sheet keeps its content alive for a frame
        // after its item is cleared, so anything that force-unwrapped would
        // crash on exactly the dismissal it was written to support.
        .sheet(item: $store.statusNote) { _ in
            if let note = Binding($store.statusNote) {
                StatusNoteSheet(
                    note: note.wrappedValue,
                    text: note.text,
                    onConfirm: { store.send(.statusNoteConfirmed) },
                    onCancel: { store.send(.statusNoteDismissed) }
                )
                .presentationDetents([.height(320)])
            }
        }
        .sheet(item: $store.partsDraft) { _ in
            if let draft = Binding($store.partsDraft) {
                PartsSheet(
                    text: draft.text,
                    isReady: draft.wrappedValue.isReady,
                    onConfirm: { store.send(.partsConfirmed) },
                    onCancel: { store.send(.binding(.set(\.partsDraft, nil))) }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(item: $store.visitDraft) { _ in
            if let draft = Binding($store.visitDraft) {
                VisitSheet(
                    draft: draft,
                    onConfirm: { store.send(.visitConfirmed) },
                    onCancel: { store.send(.binding(.set(\.visitDraft, nil))) }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(item: $store.scope(state: \.expense, action: \.expense)) { store in
            ExpenseComposerSheet(store: store)
        }
        .sheet(item: $store.scope(state: \.edit, action: \.edit)) { store in
            IssueComposerSheet(store: store)
        }
    }

    // MARK: - Headline

    private var headline: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: issue.category.symbol)
                        .font(.title3)
                        .foregroundStyle(issue.severity.tint)
                        .frame(width: 44, height: 44)
                        .background(issue.severity.tint.opacity(0.16), in: .circle)
                        .pulse(issue.severity.demandsAttention && issue.isOpen)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.title)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.issuesReportedBy(
                            store.state.name(for: issue.reportedBy),
                            issue.ageDays
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if let details = issue.details, !details.isEmpty {
                    Text(details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FlowLayout(spacing: 6, lineSpacing: 6) {
                    Badge(
                        String(localized: issue.severity.title),
                        tint: issue.severity.tint,
                        symbol: issue.severity.symbol
                    )
                    Badge(String(localized: issue.area.title), tint: .secondary, symbol: issue.area.symbol)
                    Badge(
                        String(localized: issue.category.title),
                        tint: .secondary,
                        symbol: issue.category.symbol
                    )
                    if issue.isUnderWarranty, let until = issue.warrantyUntil {
                        // The single most valuable fact on this screen when it
                        // is true: a broken appliance under warranty is a phone
                        // call, and one a fortnight out of it is a bill.
                        Badge(
                            String(localized: L10n.issuesWarrantyUntil(
                                until.date.formatted(.dateTime.day().month(.abbreviated).year())
                            )),
                            tint: Palette.success,
                            symbol: "checkmark.shield.fill"
                        )
                    }
                    if let due = issue.dueBy {
                        Badge(
                            String(localized: issue.isOverdue
                                ? L10n.issuesOverdueBy(-(issue.daysUntilDue() ?? 0))
                                : L10n.issuesDueOn(
                                    due.date.formatted(.dateTime.day().month(.abbreviated))
                                )),
                            tint: issue.isOverdue ? Palette.danger : Palette.warning,
                            symbol: "calendar.badge.exclamationmark"
                        )
                    }
                }

                Divider().opacity(0.4)

                HStack(spacing: 10) {
                    MeTooButton(count: issue.affectedCount, isOn: store.isAffected) {
                        store.send(.meTooTapped)
                    }
                    Spacer(minLength: 4)
                    assigneeMenu
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: issue)
    }

    /// Whose job it is.
    ///
    /// A menu on the avatar rather than a row in a form: the question is asked
    /// far more often than the rest of the report is edited, and burying it in
    /// the composer is how a household ends up with nine problems and nobody's
    /// name on any of them.
    private var assigneeMenu: some View {
        Menu {
            ForEach(store.assigneeOptions) { member in
                Button { store.send(.assignTapped(member.id)) } label: {
                    Label {
                        Text(member.id == store.currentUserID
                            ? String(localized: L10n.issuesYou)
                            : member.displayName)
                    } icon: {
                        Image(systemName: issue.assignedTo == member.id
                            ? "checkmark"
                            : "person")
                    }
                }
            }
            if issue.assignedTo != nil {
                Divider()
                Button(role: .destructive) { store.send(.assignTapped(nil)) } label: {
                    Label { Text(L10n.issuesUnassign) } icon: {
                        Image(systemName: "person.slash")
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                if let assignee = store.state.member(issue.assignedTo) {
                    Avatar(
                        initials: assignee.initials,
                        seed: assignee.id.rawValue,
                        size: 24
                    )
                    Text(store.state.name(for: issue.assignedTo))
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                } else {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.caption)
                    Text(L10n.issuesAssign)
                        .font(.caption.weight(.medium))
                }
            }
            .foregroundStyle(issue.assignedTo == nil ? Color.secondary : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(.capsule)
        }
        .accessibilityLabel(Text(L10n.issuesAssign))
    }

    // MARK: - Status

    private var statusCard: some View {
        GlassCard(padding: 18) {
            VStack(spacing: 16) {
                StatusTrack(status: issue.status) { store.send(.statusTapped($0)) }

                if issue.status == .blocked,
                   let reason = issue.blockedReason, !reason.isEmpty {
                    Label { Text(reason) } icon: {
                        Image(systemName: "hand.raised.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(Palette.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }

                if issue.status == .fixed,
                   let resolution = issue.resolution, !resolution.isEmpty {
                    Label { Text(resolution) } icon: {
                        Image(systemName: "checkmark.seal.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(Palette.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }

                if let next = issue.status.next {
                    PrimaryButton(issue.status.advanceTitle, symbol: next.symbol) {
                        store.send(.statusTapped(next))
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: issue.status)
    }

    /// The chore has been done, but nobody has said whether it worked.
    ///
    /// This is the whole reason finishing a chore does not close the problem on
    /// its own: "call the plumber" is a chore somebody can finish while the tap
    /// goes on dripping. The app says what it knows and asks; it does not
    /// decide.
    private var verdictPrompt: some View {
        GlassCard(padding: 16, tint: Palette.success.opacity(0.14)) {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(L10n.issuesVerdictTitle)
                        .font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.success)
                }
                Text(L10n.issuesVerdictMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button { store.send(.statusTapped(.fixed)) } label: {
                        Text(L10n.issuesVerdictFixed)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.success)

                    Button { store.send(.statusTapped(.inProgress)) } label: {
                        Text(L10n.issuesVerdictNotYet)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .transition(.opacity.combined(with: .offset(y: -6)))
    }

    // MARK: - The plan

    /// The four things a household actually does about a broken thing.
    ///
    /// Each one writes a real row in the module that owns it: a chore on the
    /// task list, a visit in the calendar, parts on the shopping list, a receipt
    /// in the ledger. Nothing here is a private copy — which is why the tiles
    /// can show live state (finished, bought, spent) without this screen
    /// subscribing to four more queries.
    private var planCard: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.issuesPlanTitle,
                subtitle: store.hasPlan ? nil : L10n.issuesPlanSubtitle,
                symbol: "list.bullet.clipboard"
            )

            GlassList {
                choreRow
                visitRow
                partsRow
                costRow
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.detail)
    }

    private var choreRow: some View {
        PlanRow(
            symbol: "checklist",
            tint: Palette.statTasks,
            title: L10n.issuesPlanChore,
            detail: store.detail?.task.map { task in
                task.isCompleted
                    ? Text(L10n.issuesChoreDone)
                    : Text(store.state.name(for: task.assignedTo))
            },
            state: store.detail?.task.map { $0.isCompleted ? .done : .active } ?? .empty,
            actionTitle: L10n.issuesPlanMakeChore,
            glass: glass
        ) {
            store.send(.makeChoreTapped)
        }
    }

    private var visitRow: some View {
        // A visit still ahead of the household is moved, not duplicated — so
        // the control says "move it" rather than offering a second appointment
        // nobody would find their way back to cancel.
        let upcoming = store.detail?.event.map { !$0.hasHappened } ?? false
        return PlanRow(
            symbol: "calendar.badge.clock",
            tint: Palette.statEvents,
            title: L10n.issuesPlanVisit,
            detail: store.detail?.event.map { event in
                Text(event.startsAt.date, format: .dateTime.weekday(.abbreviated).day()
                    .month(.abbreviated).hour().minute())
            },
            state: store.detail?.event.map { $0.hasHappened ? .done : .active } ?? .empty,
            actionTitle: upcoming ? L10n.issuesPlanMoveVisit : L10n.issuesPlanBookVisit,
            actionSymbol: upcoming ? "calendar.badge.clock" : nil,
            glass: glass,
            onOpen: store.detail?.event != nil ? { store.send(.openEventTapped) } : nil
        ) {
            store.send(.scheduleVisitTapped)
        }
    }

    private var partsRow: some View {
        let total = store.detail?.partsTotal ?? 0
        let bought = store.detail?.partsPurchased ?? 0
        return PlanRow(
            symbol: "cart.fill",
            tint: Palette.statShopping,
            title: L10n.issuesPlanParts,
            detail: total > 0 ? Text(L10n.issuesPartsProgress(bought, total)) : nil,
            state: total == 0 ? .empty : (bought == total ? .done : .active),
            actionTitle: L10n.issuesPlanAddParts,
            progress: store.detail?.partsProgress,
            glass: glass,
            onOpen: total > 0 ? { store.send(.openShoppingListTapped) } : nil
        ) {
            store.send(.addPartsTapped)
        }
    }

    private var costRow: some View {
        let estimate = issue.costEstimate
        return PlanRow(
            symbol: "creditcard.fill",
            tint: Palette.indigo,
            title: L10n.issuesPlanCost,
            detail: store.spent > 0
                ? Text(estimate.map { limit in
                    String(localized: L10n.issuesCostOfEstimate(
                        Money.text(store.spent, currency: store.currency),
                        Money.compactText(limit, currency: store.currency)
                    ))
                } ?? Money.text(store.spent, currency: store.currency))
                : estimate.map { limit in
                    Text(L10n.issuesEstimateOnly(
                        Money.text(limit, currency: store.currency)
                    ))
                },
            state: store.spent > 0 ? .active : .empty,
            actionTitle: L10n.issuesPlanLogCost,
            progress: store.detail?.estimateProgress,
            isOver: store.detail?.isOverEstimate ?? false,
            glass: glass
        ) {
            store.send(.logCostTapped)
        }
    }

    // MARK: - Who to call

    private var vendorCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(L10n.issuesVendorTitle, symbol: "person.badge.shield.checkmark")

                if let name = issue.vendorName, !name.isEmpty {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                }

                HStack(spacing: 10) {
                    if let call = store.state.callURL {
                        Button { openURL(call) } label: {
                            Label {
                                Text(issue.vendorPhone ?? "")
                            } icon: {
                                Image(systemName: "phone.fill")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Palette.success)
                    }
                    if let web = store.state.vendorWebURL {
                        Button { openURL(web) } label: {
                            Label { Text(L10n.issuesVendorWebsite) } icon: {
                                Image(systemName: "safari")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    // MARK: - Last time

    /// What happened the last time this exact thing went.
    ///
    /// The resolution somebody wrote six months ago is the single most useful
    /// sentence on the screen, and it is the only reason the app asks for one.
    private var previouslyCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    L10n.issuesPreviouslyTitle,
                    subtitle: L10n.issuesPreviouslySubtitle,
                    symbol: "clock.arrow.circlepath"
                )

                VStack(spacing: 10) {
                    ForEach(store.previously) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: entry.status.symbol)
                                    .font(.caption2)
                                    .foregroundStyle(entry.status.tint)
                                Text(entry.title)
                                    .font(.footnote.weight(.medium))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                if let at = entry.resolvedAt {
                                    Text(at.date, format: .dateTime.month(.abbreviated).year())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let resolution = entry.resolution, !resolution.isEmpty {
                                Text(resolution)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    // MARK: - Timeline

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.issuesTimelineTitle, symbol: "text.bubble") {
                if store.uploading > 0 {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini)
                        Text(L10n.issuesUploading(store.uploading))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if store.isLoading && store.timeline.isEmpty {
                SkeletonList(rows: 3, height: 48)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.timeline.enumerated()), id: \.element.id) { index, entry in
                        TimelineRow(
                            entry: entry,
                            authorName: entry.authorID.map { store.state.name(for: $0) },
                            author: store.state.member(entry.authorID),
                            isFirst: index == 0,
                            isLast: index == store.timeline.count - 1,
                            canRemove: entry.isRemovable(by: store.currentUserID)
                        ) {
                            store.send(.deleteEntryTapped(entry.id))
                        }
                    }
                }
                .animation(Motion.spring, value: store.timeline)
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    /// The bar at the bottom: say something, or add a picture.
    ///
    /// Pinned rather than at the end of the scroll, because on a problem with
    /// twenty entries the one thing you came to do would otherwise be twenty
    /// entries away.
    private var composer: some View {
        // Read out here, not inside the picker's label. That closure is
        // `@Sendable`, so reaching into the main-actor environment from within
        // it is a concurrency warning — and a value read once per render is
        // cheaper than one read per rebuild of the label anyway.
        let accent = theme.accent
        return HStack(spacing: 10) {
            PhotosPicker(
                selection: $picked,
                maxSelectionCount: 4,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image(systemName: "camera.fill")
                    .font(.body)
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .contentShape(.circle)
            }
            .accessibilityLabel(Text(L10n.issuesAddPhoto))

            TextField(text: $store.draft, axis: .vertical) {
                Text(L10n.issuesCommentPlaceholder)
            }
            .font(.subheadline)
            .lineLimit(1...4)
            .focused($isComposing)
            .textInputAutocapitalization(.sentences)

            Button { store.send(.postTapped) } label: {
                Group {
                    if store.isPosting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 32, height: 32)
                .background(store.canPost ? theme.accent : Color.secondary.opacity(0.35), in: .circle)
                .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .disabled(!store.canPost)
            .animation(Motion.spring, value: store.canPost)
            .accessibilityLabel(Text(L10n.issuesPostComment))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.bottom, 8)
    }

    // MARK: - Overflow

    private var overflowMenu: some View {
        Menu {
            Button { store.send(.editTapped) } label: {
                Label { Text(L10n.commonEdit) } icon: { Image(systemName: "pencil") }
            }

            Section(String(localized: L10n.issuesMoveTo)) {
                ForEach(store.otherStatuses) { status in
                    Button { store.send(.statusTapped(status)) } label: {
                        Label { Text(status.title) } icon: {
                            Image(systemName: status.symbol)
                        }
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
}

// MARK: - Plan rows

/// One line of the plan: what it is, what has been arranged, and the one button
/// that arranges it.
private struct PlanRow: View {
    enum PlanState {
        /// Nothing arranged yet — the row is an invitation.
        case empty
        /// Arranged and still running.
        case active
        /// Arranged and finished.
        case done
    }

    let symbol: String
    let tint: Color
    let title: LocalizedStringResource
    let detail: Text?
    let state: PlanState
    let actionTitle: LocalizedStringResource
    /// Overrides the `+` when the control does something other than add — a
    /// visit already booked is moved rather than duplicated, and a plus over
    /// that is a promise the server would not keep.
    var actionSymbol: String? = nil
    var progress: Double? = nil
    var isOver: Bool = false
    let glass: Namespace.ID
    /// Present when the arranged thing lives somewhere else worth going to.
    var onOpen: (() -> Void)? = nil
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(state == .empty ? 0.1 : 0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: state == .done ? "checkmark" : symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(state == .empty ? Palette.accessory : tint)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(state == .empty ? .secondary : .primary)
                if let detail {
                    detail
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let progress, progress > 0 {
                    GeometryReader { geo in
                        Capsule()
                            .fill(isOver ? Palette.danger : tint)
                            .frame(width: max(3, geo.size.width * min(1, progress)))
                    }
                    .frame(height: 4)
                    .background(Capsule().fill(.quaternary))
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 4)

            if let onOpen {
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.forward")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accessoryStrong)
                        .frame(width: 32, height: 32)
                        .contentShape(.circle)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(L10n.commonOpen))
            }

            Button(action: action) {
                Image(systemName: actionSymbol ?? (state == .empty ? "plus" : "plus.circle"))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(actionTitle))
        }
        .glassRow()
        .glassEffectID("plan-\(symbol)", in: glass)
        .animation(Motion.spring, value: state)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Timeline rows

/// One entry in the history, on a continuous rail.
///
/// The rail is what makes it read as a sequence rather than as a stack of cards:
/// a problem's history is one thing that happened after another, and losing that
/// is losing most of what the timeline is for.
private struct TimelineRow: View {
    let entry: IssueEntry
    let authorName: String?
    let author: User?
    let isFirst: Bool
    let isLast: Bool
    let canRemove: Bool
    let onRemove: () -> Void

    private var tint: Color {
        entry.toStatus?.tint ?? (entry.kind == .comment ? Palette.accessory : Palette.indigo)
    }

    private var symbol: String {
        switch entry.kind {
        case .comment: "text.bubble.fill"
        case .status: entry.toStatus?.symbol ?? "arrow.right.circle.fill"
        case .link: "link"
        case .system: "sparkles"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                // The rail runs behind every marker but stops at the ends, so
                // the first and last entries do not trail a line into nothing.
                Rectangle()
                    .fill(isFirst ? Color.clear : Color.secondary.opacity(0.22))
                    .frame(width: 2, height: 10)
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 26, height: 26)
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tint)
                }
                Rectangle()
                    .fill(isLast ? Color.clear : Color.secondary.opacity(0.22))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let author {
                        Avatar(initials: author.initials, seed: author.id.rawValue, size: 18)
                    }
                    Text(authorName ?? String(localized: L10n.issuesTheApp))
                        .font(.caption.weight(.semibold))
                    Text(verbatim: "·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    RelativeTimeText(entry.created)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }

                if entry.kind == .status, let to = entry.toStatus {
                    // Said as a sentence rather than as two chips: "moved it to
                    // Fixed" is what happened, and a pair of pills makes the
                    // reader assemble that themselves.
                    Text(entry.fromStatus.map { from in
                        String(localized: L10n.issuesMovedFromTo(
                            String(localized: from.title),
                            String(localized: to.title)
                        ))
                    } ?? String(localized: L10n.issuesMovedTo(String(localized: to.title))))
                    .font(.footnote)
                    .foregroundStyle(to.tint)
                }

                if let body = entry.body, !body.isEmpty {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(entry.kind == .comment ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .contextMenu {
                if canRemove {
                    Button(role: .destructive, action: onRemove) {
                        Label { Text(L10n.commonDelete) } icon: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
