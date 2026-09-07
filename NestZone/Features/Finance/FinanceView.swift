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
    @Namespace private var glass
    @Namespace private var sectionPill
    /// The row with its delete button showing, if any. Held here rather than in
    /// each row so opening one closes the last, as the system list does.
    @State private var revealedExpenseID: ExpenseID?
    @FocusState private var isSearchFocused: Bool

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
        .toolbar {
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
        .overlay { ConfettiBurst(trigger: store.settledCelebration) }
        .animation(Motion.spring, value: store.pendingDeletion)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(
            state: \.destination?.composeExpense,
            action: \.destination.composeExpense
        )) { store in
            ExpenseComposerSheet(store: store)
        }
        .sheet(item: $store.scope(
            state: \.destination?.composeBill,
            action: \.destination.composeBill
        )) { store in
            BillComposerSheet(store: store)
        }
        .sheet(item: $store.scope(
            state: \.destination?.payBill,
            action: \.destination.payBill
        )) { store in
            PayBillSheet(store: store)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $store.scope(
            state: \.destination?.settleUp,
            action: \.destination.settleUp
        )) { store in
            SettleUpSheet(store: store)
        }
        .sheet(item: $store.scope(
            state: \.destination?.editBudget,
            action: \.destination.editBudget
        )) { store in
            BudgetEditorSheet(store: store)
                .presentationDetents([.medium])
        }
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
                        Image(systemName: section.symbol)
                            .font(.caption2.weight(.semibold))
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
        let isOwed = net > 0
        let isSquare = net == 0
        let tint: Color = isSquare ? Palette.success : (isOwed ? Palette.success : Palette.warning)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text(isSquare
                            ? L10n.financeAllSquareTitle
                            : (isOwed ? L10n.financeYouAreOwed : L10n.financeYouOwe))
                    } icon: {
                        Image(systemName: isSquare
                            ? "checkmark.seal.fill"
                            : (isOwed ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill"))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(tint)

                    MoneyText(abs(net), currency: store.currency)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
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
            } else {
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
        .animation(Motion.spring, value: net)
        .accessibilityElement(children: .contain)
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

                if !store.isLoading, !store.summary.payers.isEmpty {
                    Divider().opacity(0.4)
                    Text(L10n.financePaidThisMonth)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(store.summary.payers) { member in
                        PayerRow(
                            member: member,
                            fraction: Double(member.paidThisMonth) / Double(store.summary.topPayment),
                            currency: store.currency,
                            isYou: member.userID == store.currentUserID
                        )
                    }
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
            GlassGroup {
                VStack(spacing: 8) {
                    ForEach(store.billsNeedingAttention.prefix(3)) { bill in
                        BillRow(
                            bill: bill,
                            payerName: store.state.name(for: bill.responsible),
                            currency: store.currency,
                            isPaying: store.paying.contains(bill.id),
                            glass: glass,
                            onTap: { store.send(.billTapped(bill.id)) },
                            onPay: { store.send(.payBillTapped(bill.id)) },
                            onQuickPay: { store.send(.quickPayTapped(bill.id)) }
                        )
                    }
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

                    GlassGroup {
                        VStack(spacing: 8) {
                            ForEach(group.items) { expense in
                                ExpenseRow(
                                    expense: expense,
                                    payerName: store.state.name(for: expense.paidBy),
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
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(title, symbol: symbol)
            GlassGroup {
                VStack(spacing: 8) {
                    ForEach(bills) { bill in
                        BillRow(
                            bill: bill,
                            payerName: store.state.name(for: bill.responsible),
                            currency: store.currency,
                            isPaying: store.paying.contains(bill.id),
                            glass: glass,
                            onTap: { store.send(.billTapped(bill.id)) },
                            onPay: { store.send(.payBillTapped(bill.id)) },
                            onQuickPay: { store.send(.quickPayTapped(bill.id)) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Budgets

    @ViewBuilder
    private var budgetsPage: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            if store.budgets.isEmpty {
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

            if !store.unbudgetedCategories.isEmpty {
                addBudgetButton
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .animation(Motion.spring, value: store.budgets)
    }

    /// The one way to add a budget. It used to be a menu that picked the
    /// category before the sheet opened, while the toolbar's identically
    /// labelled button jumped straight into whichever category happened to be
    /// free first — two controls with the same name doing different things.
    /// Both now open the same sheet, and the sheet asks.
    private var addBudgetButton: some View {
        Button { store.send(.addBudgetTapped) } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text(L10n.financeAddBudget)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(.rect)
        }
        .buttonStyle(.glass)
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
            Button(action: onTap) { card }
                .buttonStyle(.pressable)
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
                Text(L10n.financePaidBy(payerName))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .glassEffectID(expense.id.rawValue, in: glass)
        .accessibilityElement(children: .combine)
    }
}

/// One bill, with how long is left on it.
private struct BillRow: View {
    let bill: Bill
    let payerName: String
    let currency: String
    let isPaying: Bool
    let glass: Namespace.ID
    let onTap: () -> Void
    let onPay: () -> Void
    let onQuickPay: () -> Void

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
                    }
                    // Only a bill that has already gone wrong is allowed to
                    // move, and there is at most one such group on screen.
                    .pulse(urgency.demandsAttention)

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
        .onAppear { withAnimation(Motion.arrive.delay(0.12)) { grown = true } }
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
            Image(systemName: isFlat ? "equal" : (isUp ? "arrow.up.right" : "arrow.down.right"))
                .font(.caption2.weight(.bold))
            Text(abs(change), format: .percent.precision(.fractionLength(0)))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
        }
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
