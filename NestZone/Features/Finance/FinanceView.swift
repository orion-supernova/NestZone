import ComposableArchitecture
import SwiftUI

/// Bills & Finance.
///
/// One screen with four faces behind a month scrubber. The order is
/// deliberate: what the household owes each other comes first, because that is
/// the question people open a shared finance app to answer — everything else is
/// the evidence for it.
public struct FinanceView: View {
    @Bindable var store: StoreOf<FinanceFeature>

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass
    @Namespace private var sectionPill
    /// The row with its delete button showing, if any. Held here rather than in
    /// each row so opening one closes the last, as the system list does.
    @State private var revealedExpenseID: ExpenseID?
    @FocusState private var isSearchFocused: Bool
    /// The settle-up moment, told on the balance hero. See `SquareUp`.
    @State private var squareUp = SquareUp()

    public init(store: StoreOf<FinanceFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.sectionSpacing) {
                monthScrubber
                if store.hasSeveralCurrencies {
                    currencyPicker
                }
                sectionPicker

                Group {
                    switch store.section {
                    case .overview: overview
                    case .ledger: ledger
                    case .bills: billsPage
                    case .budgets: budgetsPage
                    }
                }
                // Each face is its own view, not four states of one.
                //
                // Without the id, all four branches shared an identity: SwiftUI
                // swapped the content in place, so the transition below never
                // had an insertion to run and none of the `appear` staggers
                // inside ever saw a second `onAppear`. Switching to an empty
                // Bills tab looked like nothing had happened at all. With it,
                // the outgoing face leaves, the incoming one arrives, and its
                // contents stagger in every time — which is the whole point of
                // a picker that swaps a page.
                //
                // It rebuilds the subtree on each switch. That is the price of
                // the effect and it is a fair one: the switch is a deliberate
                // tap, it happens at most a few times a visit, and each face is
                // a handful of cards.
                .id(store.section)
                // Faces cross-dissolve and lift rather than sliding: they are
                // four views of one month, not four places, and a horizontal
                // slide would claim otherwise.
                .transition(.opacity.combined(with: .offset(y: 10)))
            }
            .padding(.bottom, Metrics.scrollBottomInset)
            .animation(Motion.spring, value: store.section)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.managementModuleFinanceTitle))
        .navigationBarTitleDisplayMode(.inline)
        .segmentToolbar {
            ToolbarItem(placement: .primaryAction) { addMenu }
        }
        .safeAreaInset(edge: .bottom) {
            if let pending = store.pendingDeletion {
                UndoToast(L10n.financeExpenseDeleted(pending.title)) {
                    store.send(.undoDeleteTapped)
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // The one genuinely playful moment: the household reaches square.
        // Told on the balance itself rather than thrown over the screen — the
        // figure counts down, is swallowed, and a stamp lands where it was.
        //
        // The figure the house squared *from* has to survive the push that
        // squared it, so it is only copied while nothing is waiting to be
        // told.
        .onChange(of: store.yourNet, initial: true) { _, net in
            if !isTellingSquareUp { squareUp.lastNet = net }
        }
        .onAppear {
            // Whatever was celebrated before this screen was drawn has been
            // celebrated. Without this, a view rebuilt over a store that had
            // already squared up once would play it again.
            if squareUp.played == nil { squareUp.played = store.settledCelebration }
        }
        // Held while a sheet covers the card — usually the settle-up sheet
        // whose save caused it — and while another face is showing, so the
        // moment is seen rather than merely felt.
        .segmentTask(id: isSquareUpDue) {
            guard isSquareUpDue else { return }
            // A sheet that has just been put away is still sliding off.
            guard await Self.pause(0.45) else { return }
            playSquareUp()
        }
        // The beats the keyframes land on. Every wait checks it was not cut
        // short: a cancelled sleep returns at once, and four haptics in a row
        // is worse than none. Switching the segment away is such a cut: the
        // task is cancelled the moment the segment stops being the one chosen,
        // and the stamp lands at once (`abandonSquareUp`) instead of slamming
        // and buzzing behind another screen.
        .segmentTask(id: squareUp.stamps) {
            guard squareUp.isStamping else { return }
            guard await Self.pause(0.72) else { return abandonSquareUp() }
            squareUp.gulps += 1
            guard await Self.pause(0.13) else { return abandonSquareUp() }
            squareUp.slams += 1
            withAnimation(Motion.pop) { squareUp.inked = true }
            guard await Self.pause(0.1) else { return abandonSquareUp() }
            squareUp.successes += 1
            guard await Self.pause(0.3) else { return abandonSquareUp() }
            finishSquareUp()
            // The stamp has faded into the title by now; its ink is put away
            // for next time.
            _ = await Self.pause(0.25)
            squareUp.inked = false
        }
        // The house's shared moment, so these follow the moment wherever it
        // came from rather than a tap of this person's — the one exception to
        // that rule in the app.
        .sensoryFeedback(.impact(weight: .light), trigger: squareUp.gulps)
        .sensoryFeedback(.impact(weight: .heavy), trigger: squareUp.slams)
        .sensoryFeedback(.success, trigger: squareUp.successes)
        .animation(Motion.spring, value: store.pendingDeletion)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .modifier(FinanceDestinations(store: store))
    }

    private var addMenu: some View {
        Menu {
            Button { store.send(.addExpenseTapped) } label: {
                Label { Text(L10n.financeAddExpense) } icon: {
                    Image(systemName: "creditcard")
                }
            }
            Button { store.send(.addBillTapped) } label: {
                Label { Text(L10n.financeAddBill) } icon: {
                    Image(systemName: "calendar.badge.plus")
                }
            }
            if !store.unbudgetedCategories.isEmpty {
                Button { store.send(.addBudgetTapped) } label: {
                    Label { Text(L10n.financeAddBudget) } icon: {
                        Image(systemName: "target")
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel(Text(L10n.commonAdd))
    }

    // MARK: - Chrome

    /// The month everything on this screen is about.
    ///
    /// Tapping the name jumps back to the current month, which is the only
    /// destination anybody scrubs *to* — and the forward arrow stops at it,
    /// because a ledger has no future and an empty October in September looks
    /// like data loss.
    private var monthScrubber: some View {
        HStack(spacing: 4) {
            stepper(-1, symbol: "chevron.left", label: L10n.financePreviousMonth)

            Button { store.send(.monthSelected(.current)) } label: {
                VStack(spacing: 1) {
                    Text(store.month.date, format: .dateTime.month(.wide).year())
                        .font(.headline)
                        .contentTransition(.numericText())
                    if !store.month.isCurrent {
                        Text(L10n.financeBackToThisMonth)
                            .font(.caption2)
                            .foregroundStyle(theme.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)
            .disabled(store.month.isCurrent)

            stepper(1, symbol: "chevron.right", label: L10n.financeNextMonth)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.month)
    }

    /// Which currency the totals are about.
    ///
    /// Only on screen when the household actually writes in more than one.
    /// Nothing here is converted: 500 lira and 20 dollars are two sets of
    /// figures, and inventing a rate on somebody's behalf would be worse than
    /// asking them which one they meant.
    private var currencyPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(store.currencies, id: \.self) { code in
                    Chip(code, isSelected: store.currency == code) {
                        store.send(.currencySelected(code))
                    }
                    .accessibilityLabel(Text(Money.name(for: code)))
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
        .scrollIndicators(.hidden)
        .animation(Motion.spring, value: store.currency)
    }

    private func stepper(
        _ step: Int,
        symbol: String,
        label: LocalizedStringResource
    ) -> some View {
        let blocked = step > 0 && store.month.advanced(by: 1).isInFuture
        return Button { store.send(.monthStepped(by: step)) } label: {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(blocked ? Palette.accessory : Palette.accessoryStrong)
                .frame(width: Metrics.minTapTarget, height: 34)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .disabled(blocked)
        .accessibilityLabel(Text(label))
    }

    /// The four faces, as a sliding pill.
    ///
    /// Hand-rolled rather than a `.segmented` picker: the pill has to carry the
    /// theme accent and glide between slots, and a system segmented control on
    /// glass draws its own opaque track underneath the blur.
    private var sectionPicker: some View {
        HStack(spacing: 2) {
            ForEach(FinanceFeature.State.Section.allCases) { section in
                let isSelected = store.section == section
                Button { store.send(.sectionSelected(section)) } label: {
                    HStack(spacing: 5) {
                        // The icon you just chose acknowledges the tap; the one
                        // you left goes quiet without a fuss.
                        Image(systemName: section.symbol)
                            .font(.caption2.weight(.semibold))
                            .bounces(when: isSelected)
                        Text(section.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(theme.accent)
                                .matchedGeometryEffect(id: "financeSection", in: sectionPill)
                        }
                    }
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.section)
    }

    // MARK: - Overview

    @ViewBuilder
    private var overview: some View {
        if store.isLoading && !store.hasSummary {
            overviewSkeleton
        } else if store.isBlank {
            EmptyStateView(
                title: L10n.financeEmptyTitle,
                message: L10n.financeEmptyMessage,
                symbol: "wallet.bifold",
                action: .init(title: L10n.financeAddFirstExpense) {
                    store.send(.addExpenseTapped)
                },
                isCompact: true
            )
            .padding(.top, 24)
        } else {
            // Every card stays mounted, always.
            //
            // Scrubbing a month used to swap the month-scoped cards out for
            // placeholders, which tore them from the view tree: the layout
            // collapsed to the two all-time cards — the balance hero and the
            // balance bars — and then the rest faded back in with `appear`
            // restarting its stagger. That reads as a different screen
            // flashing past, and it is worse than whatever it was hiding.
            //
            // So nothing is added or removed here. While a month is in flight
            // the two cards it invalidates are redacted in place, which leaves
            // the layout untouched, keeps every view's identity, and makes a
            // stale figure unreadable rather than merely wrong. When the
            // figures land they roll to their new values, which is a change a
            // person can actually follow.
            VStack(spacing: Metrics.sectionSpacing) {
                balanceHero.appear(0)

                spendCard
                    .redacted(reason: store.isLoading ? .placeholder : [])
                    .appear(1)
                categoriesCard
                    .redacted(reason: store.isLoading ? .placeholder : [])
                    .appear(2)

                if store.summary.members.count > 1 {
                    balancesCard.appear(3)
                }
                if !store.billsNeedingAttention.isEmpty {
                    billsPreview.appear(4)
                }
                if !store.budgetRows.isEmpty {
                    budgetsPreview.appear(5)
                }
                if store.hasEventSpend {
                    eventsPreview.appear(6)
                }
                if store.hasRepairSpend {
                    repairsPreview.appear(7)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .animation(Motion.fade, value: store.isLoading)
        }
    }

    private var overviewSkeleton: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(.quaternary)
                .frame(height: 168)
            SkeletonList(rows: 3, height: 96)
        }
        .padding(.horizontal, Metrics.screenPadding)
        .redacted(reason: .placeholder)
    }

    /// What the household owes you, or you it. The reason this screen exists.
    private var balanceHero: some View {
        let net = store.yourNet
        // While the settle-up moment is being told, the card is still on the
        // story it started from: the title and colour of the balance the house
        // squared *from* until the stamp has landed, and — until the moment
        // starts — that figure too.
        let told = isTellingSquareUp ? squareUp.lastNet : net
        let figure = isSquareUpHeld ? squareUp.lastNet : net
        let isOwed = told > 0
        let isSquare = told == 0
        let tint: Color = isSquare ? Palette.success : (isOwed ? Palette.success : Palette.warning)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        // A different sentence, not the same one edited: it
                        // blurs across rather than retyping in place. Stacked,
                        // so the two overlap for the moment they both exist
                        // instead of standing side by side.
                        ZStack(alignment: .leading) {
                            Text(isSquare
                                ? L10n.financeAllSquareTitle
                                : (isOwed ? L10n.financeYouAreOwed : L10n.financeYouOwe))
                                .id(isSquare ? 0 : (isOwed ? 1 : -1))
                                .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
                        }
                    } icon: {
                        Image(systemName: isSquare
                            ? "checkmark.seal.fill"
                            : (isOwed ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill"))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(tint)

                    SquareUpFigure(
                        amount: abs(figure),
                        currency: store.currency,
                        stamps: squareUp.stamps,
                        inked: squareUp.inked
                    )
                }

                Spacer(minLength: 8)

                if !store.summary.outstanding.isEmpty {
                    AvatarStack(
                        members: store.summary.outstanding.prefix(4).map {
                            AvatarStack.Member(id: $0.userID.rawValue, initials: $0.initials)
                        },
                        size: 30
                    )
                }
            }

            if isSquare {
                Text(L10n.financeAllSquareMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if !isTellingSquareUp {
                // Named, not just counted: "you owe €40" is an amount, "you owe
                // Bea €40" is something a person can act on.
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(store.yourTransfers.prefix(3)) { transfer in
                        HStack(spacing: 6) {
                            Image(systemName: transfer.from == store.currentUserID
                                ? "arrow.up.right"
                                : "arrow.down.left")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(transfer.from == store.currentUserID
                                    ? Palette.warning
                                    : Palette.success)
                            Text(transfer.from == store.currentUserID
                                ? L10n.financeYouOwePerson(store.state.name(for: transfer.to))
                                : L10n.financePersonOwesYou(store.state.name(for: transfer.from)))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(Money.text(transfer.amount, currency: store.currency))
                                .font(.footnote.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }

                PrimaryButton(L10n.financeSettleUp, symbol: "checkmark.circle") {
                    store.send(.settleUpTapped)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tinted: tint.opacity(0.12))
        // The card breathes in while the figure counts down and wobbles when
        // the stamp lands — the same timeline the figure plays, on the same
        // trigger. Never bumped under Reduce Motion.
        .keyframeAnimator(initialValue: SquareUpFrame(), trigger: squareUp.stamps) { card, frame in
            card.scaleEffect(x: frame.cardX, y: frame.cardY, anchor: .bottom)
        } keyframes: { _ in
            SquareUpFrame.timeline
        }
        .animation(Motion.spring, value: net)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Squaring up

    /// A settle-up moment this screen has not told yet.
    private var isSquareUpHeld: Bool {
        guard let played = squareUp.played else { return false }
        return store.settledCelebration > played
    }

    /// From the push that squared the house until the stamp has landed.
    private var isTellingSquareUp: Bool { isSquareUpHeld || squareUp.isStamping }

    /// Whether the held moment can be told now: nothing over the card, and the
    /// card on screen. (The segment being on screen is `segmentTask`'s to
    /// check, so that this view's body never reads the phase.)
    private var isSquareUpDue: Bool {
        isSquareUpHeld && store.destination == nil && store.section == .overview
    }

    private func playSquareUp() {
        let count = store.settledCelebration
        // A later push may have unsquared the house while the moment waited,
        // and then there is nothing left to tell.
        guard store.summary.isSquare else {
            withAnimation(Motion.settle) {
                squareUp.played = count
                squareUp.lastNet = store.yourNet
            }
            return
        }
        if reduceMotion {
            // The figure fades to nought, the seal fades in beside the title,
            // and the haptic is the moment. Nothing travels or scales.
            withAnimation(.easeOut(duration: 0.3)) {
                squareUp.played = count
                squareUp.lastNet = store.yourNet
            }
            squareUp.successes += 1
        } else {
            // The figure counts down to nought as money does; the keyframes
            // and the beats take it from there.
            withAnimation(Motion.settle) {
                squareUp.played = count
                squareUp.isStamping = true
            }
            squareUp.stamps += 1
        }
    }

    /// The stamp has landed: the title catches up with the figure.
    private func finishSquareUp() {
        withAnimation(Motion.spring) {
            squareUp.isStamping = false
            squareUp.lastNet = store.yourNet
        }
    }

    /// Cut short — the screen went away mid-moment. Lands it at once.
    private func abandonSquareUp() {
        finishSquareUp()
        squareUp.inked = false
    }

    /// Sleeps, and says whether the sleep ran its course.
    private static func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    /// The month's spend, its trend, and six months of shape behind it.
    private var spendCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.financeSpentThisMonth)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        MoneyText(store.summary.monthTotal, currency: store.currency)
                            .font(.system(.title, design: .rounded, weight: .bold))
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        if let change = store.summary.monthChange {
                            TrendChip(change: change)
                        }
                        Sparkline(
                            values: store.summary.series.map(\.total),
                            tint: theme.accent
                        )
                        .frame(width: 64, height: 22)
                    }
                }

                SpendBars(
                    points: store.summary.series,
                    currency: store.currency,
                    selected: store.month
                ) { month in
                    store.send(.monthSelected(month))
                }

                if store.summary.expenseCount > 0 {
                    Text(L10n.financeExpenseCount(store.summary.expenseCount))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Where the month went.
    ///
    /// Drawn for a month with nothing in it too — an empty ring reading zero,
    /// rather than a card that vanishes. A household that scrubs from a busy
    /// month to a quiet one should see the number fall to zero, not watch a
    /// section disappear from under its finger.
    private var categoriesCard: some View {
        GlassCard(padding: 18) {
            VStack(spacing: 16) {
                SectionHeader(L10n.financeCategoriesTitle, symbol: "chart.pie")

                SpendDonut(
                    categories: store.summary.categories,
                    total: store.summary.monthTotal,
                    currency: store.currency,
                    selection: $store.selectedSlice.sending(\.sliceSelected)
                )

                SpendLegend(
                    categories: store.summary.categories,
                    total: store.summary.monthTotal,
                    currency: store.currency,
                    selection: $store.selectedSlice.sending(\.sliceSelected)
                )
            }
        }
    }

    /// Who is up and who is down.
    private var balancesCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    L10n.financeBalancesTitle,
                    subtitle: L10n.financeBalancesSubtitle,
                    symbol: "arrow.left.arrow.right"
                )

                BalanceBars(
                    members: store.summary.members.filter { $0.isMember || !$0.isSettled },
                    currency: store.currency,
                    currentUserID: store.currentUserID
                )

                // The bars above are all-time and survive a month change; the
                // payer list under them is the one month-scoped thing on this
                // card. Gating it on `isLoading` tore it out of the tree on
                // every step — the card lost a divider, a caption and a row per
                // payer, so it collapsed, everything under it jumped up, and
                // then it all grew back a moment later. That is two layout
                // changes to report one, and it is the flicker.
                //
                // So it stays mounted on the same terms as the spend and
                // category cards: redacted in place while the figures it is
                // showing belong to the month being left, unreadable rather
                // than merely stale, and holding its own height throughout.
                if !store.summary.payers.isEmpty {
                    Group {
                        Divider().opacity(0.4)
                        Text(L10n.financePaidThisMonth)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(store.summary.payers) { member in
                            PayerRow(
                                member: member,
                                fraction: Double(member.paidThisMonth)
                                    / Double(store.summary.topPayment),
                                currency: store.currency,
                                isYou: member.userID == store.currentUserID
                            )
                        }
                    }
                    .redacted(reason: store.isLoading ? .placeholder : [])
                }
            }
        }
    }

    private var billsPreview: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.financeBillsDueTitle, symbol: "calendar.badge.clock") {
                Button { store.send(.sectionSelected(.bills)) } label: {
                    Text(L10n.commonSeeAll).font(.footnote.weight(.medium))
                }
            }
            GlassList {
                let shown = Array(store.billsNeedingAttention.prefix(3))
                let lead = Self.leadOverdue(in: shown)
                ForEach(shown) { bill in
                    BillRow(
                        bill: bill,
                        payerName: store.state.name(for: bill.responsible),
                        currency: store.currency,
                        isPaying: store.paying.contains(bill.id),
                        isLead: bill.id == lead,
                        glass: glass,
                        onTap: { store.send(.billTapped(bill.id)) },
                        onPay: { store.send(.payBillTapped(bill.id)) },
                        onQuickPay: { store.send(.quickPayTapped(bill.id)) }
                    )
                }
            }
        }
    }

    private var budgetsPreview: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.financeBudgetsTitle, symbol: "target") {
                Button { store.send(.sectionSelected(.budgets)) } label: {
                    Text(L10n.commonSeeAll).font(.footnote.weight(.medium))
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: Metrics.stackSpacing) {
                    ForEach(store.budgetRows, id: \.budget.id) { row in
                        BudgetCard(
                            progress: row.progress,
                            currency: row.progress.currency,
                            isCompact: true
                        ) { store.send(.budgetTapped(row.budget.id)) }
                        .frame(width: 148)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    /// What the calendar is costing.
    ///
    /// The half of the app that plans things also spends money, and until this
    /// card existed none of it arrived here: a budget set on a party lives on
    /// the event's own document and never reached Finance at all, while its
    /// expenses landed in the ledger as ordinary rows with nothing saying what
    /// they were for. Both halves were stored correctly the whole time; neither
    /// was ever shown.
    ///
    /// Totals are per event rather than per month on purpose — see
    /// `FinanceSummary.events`.
    private var eventsPreview: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.financeEventsTitle, symbol: "calendar")
            GlassList {
                ForEach(store.eventRows) { event in
                    EventSpendRow(event: event) {
                        store.send(.eventTapped(event.eventID, event.day))
                    }
                }
            }
        }
    }

    /// The ceilings the house set for itself.
    ///
    /// An estimate is a softer thing than a budget — somebody else names the
    /// price and the household only guesses at it — but it is still a number to
    /// come in under, and it belongs on the page about numbers to come in
    /// under. It was stored on the problem's own document and shown nowhere
    /// here, exactly as an event's budget was.
    private var repairEstimates: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.financeRepairEstimatesTitle, symbol: "wrench.and.screwdriver")
            GlassList {
                ForEach(store.estimatedRepairRows) { repair in
                    RepairSpendRow(repair: repair) {
                        store.send(.repairTapped(repair.issueID))
                    }
                }
            }
        }
    }

    /// What the house itself is costing.
    ///
    /// The calendar's twin, and it was missing for the same reason: a problem
    /// carries its estimate on its own document and its receipts land in the
    /// ledger as ordinary rows. The ledger could already say *what* a row was
    /// for; only this card can say whether the boiler has eaten its estimate.
    private var repairsPreview: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.financeRepairsTitle, symbol: "wrench.and.screwdriver")
            GlassList {
                ForEach(store.repairRows) { repair in
                    RepairSpendRow(repair: repair) {
                        store.send(.repairTapped(repair.issueID))
                    }
                }
            }
        }
    }

    // MARK: - Ledger

    @ViewBuilder
    private var ledger: some View {
        VStack(spacing: Metrics.stackSpacing) {
            searchField
            if !store.presentCategories.isEmpty {
                categoryFilters
            }
            ledgerTotal
        }
        .padding(.horizontal, Metrics.screenPadding)

        if store.isLoading && store.expenses.isEmpty {
            SkeletonList(rows: 6, height: 62)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, Metrics.stackSpacing)
        } else if store.filteredExpenses.isEmpty {
            EmptyStateView(
                title: store.isFiltering
                    ? L10n.financeNoMatchesTitle
                    : L10n.financeNoExpensesTitle,
                message: store.isFiltering
                    ? L10n.financeNoMatchesMessage
                    : L10n.financeNoExpensesMessage,
                symbol: store.isFiltering ? "line.3.horizontal.decrease.circle" : "creditcard",
                action: store.isFiltering ? nil : .init(title: L10n.financeAddExpense) {
                    store.send(.addExpenseTapped)
                },
                isCompact: true
            )
            .padding(.top, 24)
        } else {
            ForEach(store.ledgerDays, id: \.day) { group in
                VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                    DayHeader(
                        day: group.day,
                        total: group.items.reduce(0) { $0 + $1.amount },
                        currency: store.currency
                    )
                    .padding(.horizontal, Metrics.screenPadding)

                    GlassList {
                        ForEach(group.items) { expense in
                            ExpenseRow(
                                expense: expense,
                                payerName: store.state.name(for: expense.paidBy),
                                eventName: store.state.eventLabel(for: expense),
                                issueName: store.state.issueLabel(for: expense),
                                yourShare: store.currentUserID.map { expense.impact(on: $0) },
                                revealedID: $revealedExpenseID,
                                glass: glass,
                                onTap: { store.send(.expenseTapped(expense.id)) },
                                onDelete: { store.send(.deleteExpenseTapped(expense.id)) }
                            )
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
            .animation(Motion.spring, value: store.expenses)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(text: $store.search) {
                Text(L10n.financeSearchPlaceholder)
            }
            .focused($isSearchFocused)
            .segmentFocus($isSearchFocused)
            .submitLabel(.search)
            if !store.search.isEmpty {
                Button { store.send(.binding(.set(\.search, ""))) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.accessory)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(Text(L10n.commonCancel))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
        .animation(Motion.fade, value: store.search.isEmpty)
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(store.presentCategories) { category in
                    Chip(
                        String(localized: category.title),
                        symbol: category.symbol,
                        isSelected: store.categoryFilter == category
                    ) {
                        store.send(.categoryFilterTapped(category))
                    }
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }

    /// What the list currently adds up to. Has to move when a filter is
    /// applied, or the filter looks like it did nothing.
    private var ledgerTotal: some View {
        HStack {
            Text(store.isFiltering ? L10n.financeFilteredTotal : L10n.financeMonthTotal)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            MoneyText(store.filteredTotal, currency: store.currency)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
        }
    }

    // MARK: - Bills

    @ViewBuilder
    private var billsPage: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            billsDigest

            if store.bills.isEmpty {
                EmptyStateView(
                    title: L10n.financeNoBillsTitle,
                    message: L10n.financeNoBillsMessage,
                    symbol: "calendar.badge.plus",
                    action: .init(title: L10n.financeAddBill) { store.send(.addBillTapped) },
                    isCompact: true
                )
                .padding(.top, 12)
            } else {
                if !store.billsNeedingAttention.isEmpty {
                    billGroup(
                        L10n.financeBillsDueTitle,
                        symbol: "exclamationmark.circle",
                        bills: store.billsNeedingAttention
                    )
                }
                if !store.upcomingBills.isEmpty {
                    billGroup(
                        L10n.financeBillsUpcomingTitle,
                        symbol: "clock",
                        bills: store.upcomingBills
                    )
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.bills)
    }

    /// What the bills commit the household to, before any of them is due.
    private var billsDigest: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.financeCommittedMonthly)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                MoneyText(store.monthlyCommitted, currency: store.currency)
                    .font(.system(.title2, design: .rounded, weight: .bold))

                HStack(spacing: 8) {
                    if store.overdueCount > 0 {
                        Badge(
                            String(localized: L10n.financeOverdueCount(store.overdueCount)),
                            tint: Palette.danger,
                            symbol: "exclamationmark.triangle.fill"
                        )
                    }
                    if store.dueSoonCount > 0 {
                        Badge(
                            String(localized: L10n.financeDueSoonCount(store.dueSoonCount)),
                            tint: Palette.warning,
                            symbol: "clock.fill"
                        )
                    }
                    if store.overdueCount == 0, store.dueSoonCount == 0, !store.bills.isEmpty {
                        Badge(
                            String(localized: L10n.financeNothingDue),
                            tint: Palette.success,
                            symbol: "checkmark.circle.fill"
                        )
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func billGroup(
        _ title: LocalizedStringResource,
        symbol: String,
        bills: [Bill]
    ) -> some View {
        let lead = Self.leadOverdue(in: bills)
        return VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(title, symbol: symbol)
            GlassList {
                ForEach(bills) { bill in
                    BillRow(
                        bill: bill,
                        payerName: store.state.name(for: bill.responsible),
                        currency: store.currency,
                        isPaying: store.paying.contains(bill.id),
                        isLead: bill.id == lead,
                        glass: glass,
                        onTap: { store.send(.billTapped(bill.id)) },
                        onPay: { store.send(.payBillTapped(bill.id)) },
                        onQuickPay: { store.send(.quickPayTapped(bill.id)) }
                    )
                }
            }
        }
    }

    /// The one overdue bill in a list allowed to keep moving: the first one
    /// listed. Two throbbing rows is a screen shouting.
    private static func leadOverdue(in bills: [Bill]) -> BillID? {
        bills.first { $0.urgency().demandsAttention }?.id
    }

    // MARK: - Budgets

    /// Adding is the toolbar's `+`, exactly as it is on the bills page.
    ///
    /// This page used to carry a full-width glass button under the grid as
    /// well, which on an empty page put it directly beneath the empty state's
    /// own prominent one: two controls, same words, same sheet, stacked. The
    /// empty state asks when there is nothing here, and the toolbar asks the
    /// rest of the time.
    @ViewBuilder
    private var budgetsPage: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            if !store.hasAnyBudget {
                EmptyStateView(
                    title: L10n.financeNoBudgetsTitle,
                    message: L10n.financeNoBudgetsMessage,
                    symbol: "target",
                    action: store.unbudgetedCategories.isEmpty ? nil : .init(
                        title: L10n.financeAddBudget
                    ) { store.send(.addBudgetTapped) },
                    isCompact: true
                )
                .padding(.top, 12)
            } else {
                if !store.budgetRows.isEmpty {
                    // Headed only when the event group is under it. On its own
                    // the grid is the whole page and the tab already names it;
                    // a heading repeating the tab is noise.
                    if store.hasBudgetedEvents || store.hasEstimatedRepairs {
                        SectionHeader(L10n.financeBudgetCeilingsTitle, symbol: "target")
                    }
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 152), spacing: Metrics.stackSpacing)],
                        spacing: Metrics.stackSpacing
                    ) {
                        ForEach(Array(store.budgetRows.enumerated()), id: \.element.budget.id) { index, row in
                            BudgetCard(progress: row.progress, currency: row.progress.currency) {
                                store.send(.budgetTapped(row.budget.id))
                            }
                            .appear(index)
                        }
                    }
                }

                if store.hasBudgetedEvents {
                    eventBudgets
                }

                if store.hasEstimatedRepairs {
                    repairEstimates
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.budgets)
        .animation(Motion.spring, value: store.budgetedEventRows)
        .animation(Motion.spring, value: store.estimatedRepairRows)
    }

    /// The ceilings set in the calendar rather than here.
    ///
    /// A budget typed into the event composer is stored on the event's own
    /// document, not in the `budgets` table, so this page — which reads that
    /// table — showed nothing for it and, with no category budget set, said in
    /// as many words that the household had no budgets at all. It had one; it
    /// was on Saturday's party. The rows are the same ones the overview shows,
    /// narrowed to the events that were actually given a cap.
    private var eventBudgets: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.financeEventBudgetsTitle, symbol: "calendar")
            GlassList {
                ForEach(store.budgetedEventRows) { event in
                    EventSpendRow(event: event) {
                        store.send(.eventTapped(event.eventID, event.day))
                    }
                }
            }
        }
    }
}

// MARK: - Rows

/// A day's heading in the ledger, with what that day cost.
private struct DayHeader: View {
    let day: Date
    let total: Int
    let currency: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(day, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.subheadline.weight(.semibold))
            if Calendar.current.isDateInToday(day) {
                Badge(String(localized: L10n.financeToday), tint: .secondary)
            }
            Spacer(minLength: 8)
            Text(Money.text(total, currency: currency))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One expense.
///
/// Three facts, in the order they are wanted: what it was, who paid, and what
/// it did to *you* — the last is the one a shared ledger is for, and it is the
/// one a plain list of amounts never answers.
private struct ExpenseRow: View {
    let expense: Expense
    let payerName: String
    /// What this was spent on in the calendar, when it was. `nil` for ordinary
    /// money — and for a row whose event has since been deleted, because the
    /// link was never an owner and the money moved regardless.
    let eventName: String?
    /// What this was spent *fixing*, on the same terms. A plumber's invoice is
    /// otherwise an unexplained line with nothing saying that a leak in the
    /// bathroom is the reason for it — the same gap the event label closes one
    /// module over.
    let issueName: String?
    /// The viewer's own position on this expense: positive if they are up on
    /// it, negative if they are down. `nil` when nobody is signed in.
    let yourShare: Int?
    @Binding var revealedID: ExpenseID?
    let glass: Namespace.ID
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        SwipeToDelete(
            isRevealed: Binding(
                get: { revealedID == expense.id },
                set: { revealedID = $0 ? expense.id : nil }
            ),
            onDelete: onDelete
        ) {
            // Not a `Button`: it sits in a ScrollView *and* inside a swipe
            // gesture, and a button holds the touch on the way down while it
            // decides what the press is going to be — so neither the scroll nor
            // the swipe could start under a finger that landed on a row. A
            // `TapGesture` fails the instant the finger moves.
            card
                .contentShape(.rect)
                .onTapGesture(perform: onTap)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default, onTap)
        }
    }

    private var card: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(expense.category.tint)
                .frame(width: 34, height: 34)
                .background(expense.category.tint.opacity(0.16), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(expense.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if expense.isFromBill {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text(L10n.financeFromBill))
                    }
                }
                HStack(spacing: 4) {
                    Text(L10n.financePaidBy(payerName))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let eventName {
                        // Without this the ledger showed a caterer's invoice as
                        // an unexplained line and gave no hint that a party in
                        // the calendar was the reason for it.
                        Text(verbatim: "·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Label {
                            Text(eventName)
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .font(.caption2)
                        .foregroundStyle(Palette.indigo)
                        .lineLimit(1)
                    }
                    if let issueName {
                        Text(verbatim: "·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Label {
                            Text(issueName)
                        } icon: {
                            Image(systemName: "wrench.adjustable.fill")
                        }
                        .font(.caption2)
                        .foregroundStyle(Palette.statIssues)
                        .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.text(expense.amount, currency: expense.currency))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                if let yourShare, yourShare != 0 {
                    Text(yourShare > 0
                        ? L10n.financeYouLent(Money.text(yourShare, currency: expense.currency))
                        : L10n.financeYouBorrowed(Money.text(-yourShare, currency: expense.currency)))
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(yourShare > 0 ? Palette.success : Palette.warning)
                }
            }
        }
        // No lean on this row: interactive glass tracks the finger from
        // touch-down, and this row's finger belongs to `SwipeToDelete`. The two
        // race for the same touch — sometimes the swipe wins, sometimes the
        // glass does, which is worse than either. Tap-only rows keep the lean
        // from `GlassListStyle.default`.
        .glassRow(interactive: false)
        .contentShape(.rect)
        .glassEffectID(expense.id.rawValue, in: glass)
        .accessibilityElement(children: .combine)
    }
}

/// One event, and what it has cost so far.
///
/// A budget when the household set one — filled ring, money left — and a plain
/// total when it did not. Both are money the calendar is responsible for, and
/// this is the only place in Finance that says so.
private struct EventSpendRow: View {
    let event: EventSpend
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.kind.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(event.kind.tint)
                .frame(width: 34, height: 34)
                .background(event.kind.tint.opacity(0.16), in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(event.startsAt.date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let progress = event.progress {
                    GeometryReader { geo in
                        Capsule()
                            .fill(event.isOverBudget ? Palette.danger : Palette.indigo)
                            .frame(width: max(3, geo.size.width * progress))
                    }
                    .frame(height: 4)
                    .background(Capsule().fill(.quaternary))
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.text(event.spent, currency: event.currency))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                if let budget = event.budget {
                    Text(L10n.financeEventOfBudget(
                        Money.compactText(budget, currency: event.currency)
                    ))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(event.isOverBudget ? Palette.danger : .secondary)
                } else if event.expenseCount > 0 {
                    Text(L10n.financeEventExpenses(event.expenseCount))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassRow()
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
    }
}

/// One house problem, and what it has cost so far.
///
/// `EventSpendRow`'s twin, with one difference that is not cosmetic: the bar
/// fills toward an *estimate*, which is a guess at what somebody else will
/// charge rather than a decision the household made. Going over it is worth
/// seeing and is not a failure, so it colours as a warning rather than as
/// danger — the severity beside it is what says whether to worry.
private struct RepairSpendRow: View {
    let repair: RepairSpend
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: repair.severity.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(repair.severity.tint)
                .frame(width: 34, height: 34)
                .background(repair.severity.tint.opacity(0.16), in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(repair.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(repair.severity.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let progress = repair.progress {
                    GeometryReader { geo in
                        Capsule()
                            .fill(repair.isOverEstimate ? Palette.warning : Palette.indigo)
                            .frame(width: max(3, geo.size.width * progress))
                    }
                    .frame(height: 4)
                    .background(Capsule().fill(.quaternary))
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.text(repair.spent, currency: repair.currency))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                if let estimate = repair.estimate {
                    Text(L10n.financeRepairOfEstimate(
                        Money.compactText(estimate, currency: repair.currency)
                    ))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(repair.isOverEstimate ? Palette.warning : .secondary)
                } else if repair.expenseCount > 0 {
                    Text(L10n.financeEventExpenses(repair.expenseCount))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassRow()
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
    }
}

/// One bill, with how long is left on it.
private struct BillRow: View {
    let bill: Bill
    let payerName: String
    let currency: String
    let isPaying: Bool
    /// Whether this is the one overdue bill on screen that keeps breathing.
    let isLead: Bool
    let glass: Namespace.ID
    let onTap: () -> Void
    let onPay: () -> Void
    let onQuickPay: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var urgency: Bill.Urgency { bill.urgency() }
    private var days: Int { bill.daysUntilDue() }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(urgency.tint.opacity(0.16))
                            .frame(width: 38, height: 38)
                        Image(systemName: bill.category.symbol)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(urgency.tint)
                            // Any other overdue bill takes one breath as it
                            // arrives and then keeps still.
                            .symbolEffect(
                                .breathe,
                                options: .nonRepeating,
                                isActive: urgency.demandsAttention && !isLead && !reduceMotion
                            )
                    }
                    // Only a bill that has already gone wrong is allowed to
                    // move, and only the first of them keeps moving.
                    .pulse(urgency.demandsAttention && isLead)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            Text(countdown)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(urgency.tint)
                            Text("·").font(.caption2).foregroundStyle(.secondary)
                            Text(bill.cycle.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if bill.responsible != nil {
                                Text("·").font(.caption2).foregroundStyle(.secondary)
                                Text(payerName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            // Whether anybody will actually be told. A bill with
                            // no reminder is the one that gets missed, and the
                            // row is where that is worth knowing.
                            if !bill.reminders.isEmpty {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(Text(
                                        L10n.financeReminderCount(bill.reminders.count)
                                    ))
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    Text(Money.text(bill.amount, currency: bill.currency))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pressable)

            Button(action: onPay) {
                Group {
                    if isPaying {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.bold))
                    }
                }
                .frame(width: 38, height: 38)
                .contentShape(.circle)
            }
            .buttonStyle(.pressable)
            .glassEffect(.regular.tint(urgency.tint.opacity(0.22)).interactive(), in: .circle)
            .disabled(isPaying)
            .accessibilityLabel(Text(L10n.financeMarkPaid))
            // The fixed bills — rent, the same figure every month — should not
            // need a form. The row already shows the amount, so this is not a
            // blind write.
            .contextMenu {
                Button { onQuickPay() } label: {
                    Label {
                        Text(L10n.financePayNow(Money.text(bill.amount, currency: bill.currency)))
                    } icon: {
                        Image(systemName: "bolt.fill")
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .glassEffectID(bill.id.rawValue, in: glass)
        .animation(Motion.fade, value: isPaying)
        .accessibilityElement(children: .contain)
    }

    /// Days, not hours: "due today" is what a person calls a bill due in nine
    /// hours, and a countdown that flips to overdue at midnight is telling the
    /// truth.
    private var countdown: LocalizedStringResource {
        switch urgency {
        case .overdue: L10n.financeOverdueBy(-days)
        case .dueToday: L10n.financeDueToday
        case .dueSoon, .upcoming: L10n.financeDueIn(days)
        }
    }
}

/// One person's share of what was paid out this month.
private struct PayerRow: View {
    let member: MemberFinance
    let fraction: Double
    let currency: String
    let isYou: Bool

    @State private var grown = false

    var body: some View {
        HStack(spacing: 10) {
            Avatar(initials: member.initials, seed: member.userID.rawValue, size: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(isYou ? String(localized: L10n.financeYou) : member.displayName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                GeometryReader { geo in
                    Capsule()
                        .fill(MemberTint.color(for: member.userID.rawValue))
                        .frame(width: max(3, geo.size.width * (grown ? fraction : 0)))
                }
                .frame(height: 5)
                .background(Capsule().fill(.quaternary))
            }

            Text(Money.text(member.paidThisMonth, currency: currency))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        // Money, so it grows to its share and stops there — no spring past it.
        .drawIn($grown, animation: Motion.dataDraw.delay(0.12))
        .accessibilityElement(children: .combine)
    }
}

/// One budget, as a ring and the two numbers that explain it.
private struct BudgetCard: View {
    let progress: BudgetProgress
    let currency: String
    var isCompact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                BudgetRing(
                    progress: progress,
                    currency: currency,
                    diameter: isCompact ? 68 : 82,
                    thickness: isCompact ? 8 : 9
                )

                VStack(spacing: 2) {
                    Text(progress.category.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(progress.isOver
                        ? L10n.financeBudgetOverBy(
                            Money.compactText(-progress.remaining, currency: currency))
                        : L10n.financeBudgetLeft(
                            Money.compactText(progress.remaining, currency: currency)))
                        .font(.caption2)
                        .foregroundStyle(progress.isOver ? Palette.danger : .secondary)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .animation(Motion.spring, value: progress)
    }
}

/// Month-over-month, as a single chip.
private struct TrendChip: View {
    let change: Double

    /// Below this the two months are the same to any useful precision, and a
    /// chip claiming "+0%" is noise dressed as a finding.
    private static let flat = 0.005

    var body: some View {
        let isFlat = abs(change) < Self.flat
        let isUp = change > 0
        return HStack(spacing: 3) {
            // Spend against last month flips direction as the month fills in.
            Image(systemName: isFlat ? "equal" : (isUp ? "arrow.up.right" : "arrow.down.right"))
                .contentTransition(.symbolEffect(.replace))
                .font(.caption2.weight(.bold))
            Text(abs(change), format: .percent.precision(.fractionLength(0)))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: abs(change)))
        }
        .animation(Motion.spring, value: change)
        // Spending more is not a failure, so this is not red — it is the
        // household's own number moving, and the colour only says which way.
        .foregroundStyle(isFlat ? Color.secondary : (isUp ? Palette.warning : Palette.success))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            (isFlat ? Color.secondary : (isUp ? Palette.warning : Palette.success)).opacity(0.15),
            in: .capsule
        )
        .contentTransition(.numericText(value: change))
        .accessibilityLabel(Text(isUp ? L10n.financeTrendUp : L10n.financeTrendDown))
        .accessibilityValue(Text(abs(change), format: .percent.precision(.fractionLength(0))))
    }
}

// MARK: - Squaring up

/// How far this screen has got in telling the household it is square.
///
/// Local rather than in the reducer: none of it is about the household's money,
/// only about which beat of a short story the card is on — and a view rebuilt
/// halfway through simply lands it.
private struct SquareUp {
    /// The last celebration this screen has told, or `nil` before it has looked.
    /// Anything above it is waiting to be told.
    var played: Int?
    /// Your balance as the card last showed it: the figure the moment counts
    /// down from, and the title it starts on.
    var lastNet = 0
    /// From the start of the count-down until the stamp has landed.
    var isStamping = false
    /// Bumped once per moment. Plays the keyframes.
    var stamps = 0
    /// Whether the checkmark has been drawn into the stamp.
    var inked = false
    /// One counter per beat, for the haptics.
    var gulps = 0
    var slams = 0
    var successes = 0
}

/// One frame of the settle-up moment — every track its keyframes drive.
///
/// About a second and a half, in four beats:
/// - 0–0.6s: the figure counts down to nought while the card breathes in;
/// - 0.6–0.85s: the nought pops, then is swallowed;
/// - 0.85–1.25s: a stamp slams down where it was, the card wobbles like jelly
///   and a ring spreads from the impact;
/// - 1.25–1.5s: the stamp shrinks off into the title, which now says so.
///
/// No `Canvas`, no timeline: transforms on views that are already there, for a
/// second and a half, and then nothing at all.
private struct SquareUpFrame {
    var cardX: CGFloat = 1
    var cardY: CGFloat = 1
    var figureScale: CGFloat = 1
    var figureBlur: CGFloat = 0
    var stampScale: CGFloat = 0
    var stampAngle: Double = 0
    var stampOpacity: Double = 0
    /// 0 on the figure, 1 beside the title.
    var stampHome: CGFloat = 0
    var ringScale: CGFloat = 1
    var ringOpacity: Double = 0

    /// Every track ends at rest or out of sight, and every track that moves
    /// something out of sight snaps back before it is seen again — so the card
    /// is right whether the animator holds the last frame or the first.
    @KeyframesBuilder<SquareUpFrame>
    static var timeline: some Keyframes<SquareUpFrame> {
        // The card: in with the count, then jelly on the slam.
        KeyframeTrack(\.cardX) {
            CubicKeyframe(1.02, duration: 0.6)
            LinearKeyframe(1.02, duration: 0.25)
            CubicKeyframe(1.04, duration: 0.06)
            CubicKeyframe(0.98, duration: 0.14)
            SpringKeyframe(1, duration: 0.4, spring: Spring(duration: 0.4, bounce: 0.3))
        }
        KeyframeTrack(\.cardY) {
            CubicKeyframe(0.97, duration: 0.6)
            LinearKeyframe(0.97, duration: 0.25)
            CubicKeyframe(0.94, duration: 0.06)
            CubicKeyframe(1.04, duration: 0.14)
            SpringKeyframe(1, duration: 0.4, spring: Spring(duration: 0.4, bounce: 0.3))
        }
        // The figure: pops, is swallowed, and comes back as the stamp leaves.
        KeyframeTrack(\.figureScale) {
            LinearKeyframe(1, duration: 0.6)
            CubicKeyframe(1.35, duration: 0.12)
            CubicKeyframe(0, duration: 0.13)
            LinearKeyframe(0, duration: 0.4)
            SpringKeyframe(1, duration: 0.25, spring: Spring(duration: 0.3, bounce: 0.3))
        }
        KeyframeTrack(\.figureBlur) {
            LinearKeyframe(0, duration: 0.72)
            CubicKeyframe(6, duration: 0.13)
            LinearKeyframe(6, duration: 0.4)
            CubicKeyframe(0, duration: 0.25)
        }
        // The stamp: slammed down big and crooked, straightened, then off to
        // the title.
        KeyframeTrack(\.stampScale) {
            MoveKeyframe(0)
            LinearKeyframe(0, duration: 0.85)
            MoveKeyframe(2.2)
            CubicKeyframe(0.9, duration: 0.1)
            CubicKeyframe(1.05, duration: 0.08)
            CubicKeyframe(1, duration: 0.07)
            LinearKeyframe(1, duration: 0.15)
            CubicKeyframe(0.27, duration: 0.25)
        }
        KeyframeTrack(\.stampAngle) {
            LinearKeyframe(0, duration: 0.85)
            MoveKeyframe(-12)
            CubicKeyframe(4, duration: 0.1)
            CubicKeyframe(0, duration: 0.15)
        }
        KeyframeTrack(\.stampOpacity) {
            MoveKeyframe(0)
            LinearKeyframe(0, duration: 0.85)
            MoveKeyframe(1)
            LinearKeyframe(1, duration: 0.4)
            CubicKeyframe(0, duration: 0.25)
        }
        KeyframeTrack(\.stampHome) {
            MoveKeyframe(0)
            LinearKeyframe(0, duration: 1.25)
            CubicKeyframe(1, duration: 0.25)
        }
        // The one ring the slam sends out.
        KeyframeTrack(\.ringScale) {
            MoveKeyframe(1)
            LinearKeyframe(1, duration: 0.85)
            CubicKeyframe(2.6, duration: 0.4)
        }
        KeyframeTrack(\.ringOpacity) {
            MoveKeyframe(0)
            LinearKeyframe(0, duration: 0.85)
            MoveKeyframe(0.55)
            CubicKeyframe(0, duration: 0.4)
        }
    }
}

/// The balance figure, and the stamp that lands on it when the house squares up.
///
/// Its own view so the animator's content reads nothing but what it was handed:
/// it is called once a frame for the length of the moment.
private struct SquareUpFigure: View {
    let amount: Int
    let currency: String
    /// Bumped once per moment — the same trigger the card's squash plays on, so
    /// the two run one timeline.
    let stamps: Int
    /// Whether the checkmark has been drawn into the stamp yet.
    let inked: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let stampSize: CGFloat = 64
    /// From the stamp's centre on the figure to the title's icon, measured off
    /// the hero's own type sizes. The stamp is fading as it arrives, so a point
    /// either way at a larger text size never shows.
    private static let homeOffset = CGSize(width: -23, height: -38)

    var body: some View {
        KeyframeAnimator(initialValue: SquareUpFrame(), trigger: stamps) { frame in
            MoneyText(amount, currency: currency)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                // Reduce Motion: a new figure fades in rather than rolling its
                // digits there.
                .id(reduceMotion ? amount : 0)
                .transition(.opacity)
                // Swallowed toward the stamp's side, which is the leading edge.
                .scaleEffect(frame.figureScale, anchor: .leading)
                .blur(radius: frame.figureBlur)
                .overlay(alignment: .leading) { stamp(frame) }
        } keyframes: { _ in
            SquareUpFrame.timeline
        }
    }

    private func stamp(_ frame: SquareUpFrame) -> some View {
        ZStack {
            Circle()
                .stroke(Palette.success, lineWidth: 3)
                .scaleEffect(frame.ringScale)
                .opacity(frame.ringOpacity)
            ZStack {
                Image(systemName: "seal.fill")
                    .font(.system(size: Self.stampSize))
                    .foregroundStyle(Palette.success)
                if inked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                        .transition(.symbolEffect(.drawOn))
                }
            }
            .scaleEffect(frame.stampScale)
            .rotationEffect(.degrees(frame.stampAngle))
            .opacity(frame.stampOpacity)
        }
        .frame(width: Self.stampSize, height: Self.stampSize)
        .offset(
            x: Self.homeOffset.width * frame.stampHome,
            y: Self.homeOffset.height * frame.stampHome
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
