import ComposableArchitecture
import SwiftUI
import UIKit

// The Finance screen's four sheets, plus the amount field they share.

// MARK: - Amount field

/// The one control every one of these sheets is really about.
///
/// A plain text field rather than a `Decimal` binding with a currency format
/// style: that variant opens holding "€0.00", so typing a number begins with
/// deleting one, every single time. This starts empty, shows a placeholder, and
/// hands what was typed to `Money.parse`, which is forgiving about which
/// separator the person's keyboard gave them.
struct AmountField: View {
    let currency: String
    @Binding var text: String
    /// Bumped by the reducer to refuse an amount. A rejection has to be felt.
    var shakes: Int = 0
    var isCompact: Bool = false
    /// The currencies this household already writes in, hoisted to their own
    /// section in the picker. Every other ISO code is still reachable there, so
    /// this being empty costs a new household nothing but the shortcut.
    ///
    /// Sitting on the field rather than in a settings screen because currency
    /// is a property of *this* amount: the rent in lira and the streaming
    /// service in dollars are one household's ordinary week.
    var currencyOptions: [String] = []
    /// Given a handler the code under the amount is a control; given none it is
    /// a label. It used to also require a non-empty `currencyOptions`, which
    /// meant a household that had written down no money yet could not pick a
    /// currency for the first amount it entered.
    var onCurrencyChange: ((String) -> Void)? = nil

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool
    /// Bumped every time a keystroke is thrown away for being past the cap, so
    /// the refusal can be felt as well as read.
    @State private var refusals = 0
    @State private var isPickingCurrency = false

    private var minorUnits: Int { Money.parse(text, currency: currency) }
    private var isSwitchable: Bool { onCurrencyChange != nil }
    private var isAtLimit: Bool { text.count >= Money.maximumInputLength }

    var body: some View {
        VStack(spacing: 8) {
            // Full width and never sized to its content. Hugging the text meant
            // a long number pushed the field — and the row it sits in — past
            // the edge of the screen, taking the layout with it. Given a fixed
            // width the field scrolls its own content instead, which is what a
            // text field is for.
            TextField(text: $text) {
                Text(verbatim: "0")
            }
            .font(.system(size: isCompact ? 28 : 44, weight: .bold, design: .rounded))
            .monospacedDigit()
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .focused($isFocused)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text(L10n.financeAmountLabel))
            // The real stop on an absurd amount is that it cannot be typed.
            // Clamping on save would let somebody enter seventy digits, watch
            // the layout break, and then be handed a different number.
            //
            // Silently dropping the keystroke is its own problem, though: the
            // field simply stops responding and nothing says why, which reads
            // as a broken keyboard. So the cap announces itself — a shake, a
            // warning tap, and a line under the field for as long as the
            // amount is sitting on the limit.
            .onChange(of: text) { _, typed in
                guard typed.count > Money.maximumInputLength else { return }
                text = String(typed.prefix(Money.maximumInputLength))
                refusals += 1
            }

            HStack(spacing: 8) {
                if isSwitchable {
                    currencyMenu
                } else {
                    Text(currency)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                // Says back what was understood, which is the whole reason the
                // field is allowed to be forgiving about separators.
                if minorUnits > 0 {
                    MoneyText(minorUnits, currency: currency)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .transition(.opacity)
                }
            }

            // Tied to the text length rather than to the last refusal, so it
            // stays up while the amount is at the cap and leaves the moment a
            // digit is deleted. No timer to get out of step with.
            if isAtLimit {
                Text(L10n.financeAmountLimit)
                    .font(.caption2)
                    .foregroundStyle(Palette.warning)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, isCompact ? 12 : 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .glassEffect(
            .regular.tint(isFocused ? theme.accent.opacity(0.16) : nil),
            in: .rect(cornerRadius: Metrics.cardRadius, style: .continuous)
        )
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
        .shake(on: shakes + refusals)
        .sensoryFeedback(.warning, trigger: refusals)
        .animation(Motion.spring, value: isFocused)
        .animation(Motion.fade, value: minorUnits > 0)
        .animation(Motion.fade, value: currency)
        .animation(Motion.fade, value: isAtLimit)
    }

    /// A sheet rather than a menu.
    ///
    /// This was a `Menu` over every common ISO code, which iOS draws as one
    /// 150-row popover with no search in it — picking lira meant flicking past
    /// sixty currencies, every time. `CurrencyPicker` hoists what this person
    /// picked recently and what the household already writes in above the
    /// alphabet, and lets them type when neither is the answer.
    private var currencyMenu: some View {
        Button {
            isPickingCurrency = true
        } label: {
            HStack(spacing: 3) {
                Text(currency)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(theme.accent.opacity(0.12), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.financeCurrencyLabel))
        .accessibilityValue(Text(Money.name(for: currency)))
        .sheet(isPresented: $isPickingCurrency) {
            CurrencyPicker(selected: currency, used: currencyOptions) { code in
                onCurrencyChange?(code)
            }
        }
    }
}

/// The sheet toolbar every composer here carries, so Cancel and Save sit in the
/// same place with the same in-flight behaviour on all four.
private struct ComposerToolbar: ToolbarContent {
    let isSubmitting: Bool
    let canSubmit: Bool
    let title: LocalizedStringResource
    let onSubmit: () -> Void
    let onCancel: () -> Void

    /// Ends editing before either button does anything.
    ///
    /// A focused field writes its binding one last time as it resigns, and
    /// dismissing the sheet first meant that write landed after the store's
    /// presentation state was already `nil` — which is TCA's "received a
    /// presentation action when destination state was absent" runtime warning,
    /// twice, on every cancel. Resigning first puts the last write back inside
    /// the sheet's own lifetime, where there is still somewhere to put it.
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

/// A member's name in a row that also has to hold a control.
///
/// The name takes one line and is the first thing in the row to give way. A
/// long one used to push the share, the count and the stepper towards the edge,
/// and in the exact split it squeezed the very field somebody was trying to
/// type in. When the name is long enough for that to bite, an info button
/// appears beside it and hands the whole thing back in a popover — shortened on
/// the row, never lost.
private struct MemberLabel: View {
    let name: String
    let initials: String
    let seed: String
    var isMuted: Bool = false

    @State private var isShowingFullName = false

    /// Past this the row would rather truncate than carry it. A character count
    /// rather than a measured width, because measuring means a `GeometryReader`
    /// per row to answer a question whose answer barely moves.
    private var isLong: Bool { name.count > 14 }

    var body: some View {
        HStack(spacing: 8) {
            Avatar(initials: initials, seed: seed, size: 26)

            Text(name)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(-1)
                .foregroundStyle(isMuted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))

            if isLong {
                Button { isShowingFullName = true } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n.financeFullName))
                .accessibilityValue(Text(name))
                .popover(isPresented: $isShowingFullName) {
                    Text(name)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        // Without this a popover becomes a sheet on iPhone,
                        // which is a lot of ceremony for one name.
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
    }
}

/// An inline failure, styled the same way in every sheet.
private struct InlineError: View {
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

// MARK: - Expense

/// Adding or editing an expense.
///
/// The amount is at the top because it is what somebody came to type; the split
/// is the largest section because it is what the sheet is actually for.
struct ExpenseComposerSheet: View {
    @Bindable var store: StoreOf<ExpenseComposerFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    AmountField(
                        currency: store.currency,
                        text: $store.amountText,
                        shakes: store.shakes,
                        currencyOptions: store.currencyOptions,
                        onCurrencyChange: { store.send(.binding(.set(\.currency, $0))) }
                    )
                    .appear(0)

                    detailsCard.appear(1)
                    categoryPicker.appear(2)
                    splitCard.appear(3)

                    if let error = store.inlineError {
                        InlineError(message: error)
                    }

                    if store.isEditing {
                        Button(role: .destructive) {
                            store.send(.deleteTapped)
                        } label: {
                            Label { Text(L10n.financeDeleteExpense) } icon: {
                                Image(systemName: "trash")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.glass)
                        .tint(Palette.danger)
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Backdrop(tint: theme.accent))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(store.isEditing
                ? L10n.financeEditExpenseTitle
                : L10n.financeAddExpense))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ComposerToolbar(
                    isSubmitting: store.isSubmitting,
                    canSubmit: store.canSubmit,
                    title: L10n.commonSave,
                    onSubmit: { store.send(.submitTapped) },
                    onCancel: { dismiss() }
                )
            }
            .animation(Motion.spring, value: store.mode)
            .animation(Motion.fade, value: store.inlineError)
        }
    }

    private var detailsCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                TextField(text: $store.title) { Text(L10n.financeTitlePlaceholder) }
                    .font(.body.weight(.medium))
                    .textInputAutocapitalization(.sentences)

                Divider().opacity(0.4)

                Picker(selection: $store.paidBy) {
                    ForEach(store.orderedMembers) { member in
                        Text(member.id == store.currentUserID
                            ? String(localized: L10n.financeYou)
                            : member.displayName)
                            .tag(member.id)
                    }
                } label: {
                    Label { Text(L10n.financePaidByLabel) } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                }

                DatePicker(selection: $store.spentAt, displayedComponents: [.date]) {
                    Label { Text(L10n.financeDateLabel) } icon: {
                        Image(systemName: "calendar")
                    }
                }

                Divider().opacity(0.4)

                TextField(text: $store.note, axis: .vertical) {
                    Text(L10n.financeNotePlaceholder)
                }
                .font(.subheadline)
                .lineLimit(1...3)
            }
        }
    }

    /// Ten categories as a wrapping row of chips rather than a picker: the
    /// choice is visual, the colours are the same ones the charts use, and a
    /// menu would hide the palette that makes the ring readable.
    private var categoryPicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.financeCategoryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(SpendCategory.allCases) { category in
                        let isSelected = store.category == category
                        Button { store.send(.binding(.set(\.category, category))) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: category.symbol)
                                    .font(.caption2.weight(.semibold))
                                Text(category.title)
                                    .font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .foregroundStyle(isSelected ? Color.white : category.tint)
                            .background(
                                isSelected ? category.tint : category.tint.opacity(0.14),
                                in: .capsule
                            )
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            .animation(Motion.spring, value: store.category)
        }
    }

    /// The substance of the sheet.
    private var splitCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Picker(selection: $store.mode) {
                    ForEach(SplitMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                } label: { EmptyView() }
                .pickerStyle(.segmented)

                // Same reason as the section picker on the screen behind this
                // one: three branches under one identity swap in place and
                // nothing moves. Given their own identities they hand over.
                Group {
                    switch store.mode {
                    case .equal: equalSplit
                    case .shares: sharesSplit
                    case .exact: exactSplit
                    }
                }
                .id(store.mode)
                .transition(.opacity.combined(with: .offset(y: 8)))

                if store.amountMinor > 0, !store.preview.isEmpty {
                    Divider().opacity(0.4)
                    SplitBar(splits: store.preview, total: store.amountMinor)
                    previewRows
                }
            }
        }
    }

    private var equalSplit: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Two bare words in the accent colour read as a caption, not as
            // controls — nothing about them said they could be tapped, and
            // nothing said which one the split was already on. They are the
            // same capsules the category row above uses, and they carry a
            // selected state, because these are places to be rather than
            // buttons to fire: a split already covering the household should
            // show "Everyone" lit rather than offer it as news.
            //
            // Hidden in a household of one, where the two presets would mean
            // the same thing and both would light up.
            HStack(spacing: 8) {
                Text(L10n.financeSplitBetween)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if store.members.count > 1 {
                    splitPreset(
                        L10n.financeEveryone,
                        symbol: "person.2.fill",
                        isSelected: store.isEveryone
                    ) { store.send(.everyoneTapped) }

                    splitPreset(
                        L10n.financeOnlyMe,
                        symbol: "person.fill",
                        isSelected: store.isOnlyMe
                    ) { store.send(.onlyMeTapped) }
                }
            }

            ForEach(store.orderedMembers) { member in
                let isOn = store.participants.contains(member.id)
                Button { store.send(.participantToggled(member.id)) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .font(.body)
                            .foregroundStyle(isOn ? theme.accent : Color.secondary)
                            .contentTransition(.symbolEffect(.replace))

                        Avatar(initials: member.initials, seed: member.id.rawValue, size: 26)

                        // One line, and the first thing to give way: the row
                        // has an amount to show on the other side of it.
                        Text(member.id == store.currentUserID
                            ? String(localized: L10n.financeYou)
                            : member.displayName)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(-1)
                            .foregroundStyle(isOn ? .primary : .secondary)

                        Spacer(minLength: 4)

                        if isOn, store.amountMinor > 0 {
                            let share = store.state.share(of: member.id)
                            MoneyText(share, currency: store.currency)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .animation(Motion.spring, value: share)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(Motion.spring, value: store.participants)
    }

    /// A shortcut for who an equal split covers, drawn as a chip so it looks
    /// like something to press. Sized to the category capsules rather than to
    /// `Chip`, which is built for a row of its own and would tower over the
    /// caption beside it.
    private func splitPreset(
        _ title: LocalizedStringResource,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.white : theme.accent)
            .background(
                isSelected ? theme.accent : theme.accent.opacity(0.14),
                in: .capsule
            )
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var sharesSplit: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.financeSharesHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(store.orderedMembers) { member in
                let weight = store.weights[member.id] ?? 0
                let share = store.state.share(of: member.id)
                HStack(spacing: 10) {
                    MemberLabel(
                        name: member.id == store.currentUserID
                            ? String(localized: L10n.financeYou)
                            : member.displayName,
                        initials: member.initials,
                        seed: member.id.rawValue,
                        isMuted: weight == 0
                    )

                    Spacer(minLength: 4)

                    // Mounted for everybody the moment there is an amount to
                    // divide, including at zero. Hiding it below a share meant
                    // the first "+" inserted the figure at its final value and
                    // the last "−" deleted it outright, so the one roll worth
                    // watching — money arriving at or leaving a person — was
                    // the only one the row could not do. The animation is keyed
                    // to the share itself rather than to the weights, so it
                    // also follows the total being typed.
                    if store.amountMinor > 0 {
                        MoneyText(share, currency: store.currency)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(weight > 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                            .animation(Motion.spring, value: share)
                    }

                    // The count sits outside the stepper, not in its label:
                    // `labelsHidden()` hides a `Stepper`'s label, so the one
                    // number the control exists to change was invisible and
                    // every tap looked like it did nothing.
                    Text(Int(weight), format: .number)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(weight > 0 ? .primary : .secondary)
                        .frame(minWidth: 20)
                        .contentTransition(.numericText(value: weight))

                    Stepper(
                        value: Binding(
                            get: { weight },
                            set: { store.send(.weightChanged(member.id, $0)) }
                        ),
                        in: 0...12,
                        step: 1
                    ) {
                        Text(member.displayName)
                    }
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel(Text(L10n.financeSharesFor(member.displayName)))
                    .accessibilityValue(Text(Int(weight), format: .number))
                }
            }
        }
        .animation(Motion.spring, value: store.weights)
    }

    private var exactSplit: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(store.orderedMembers) { member in
                HStack(spacing: 10) {
                    MemberLabel(
                        name: member.id == store.currentUserID
                            ? String(localized: L10n.financeYou)
                            : member.displayName,
                        initials: member.initials,
                        seed: member.id.rawValue
                    )

                    Spacer(minLength: 8)

                    TextField(
                        text: Binding(
                            get: { store.exact[member.id] ?? "" },
                            // Capped in the setter, the same way the big field
                            // is: a per-person share long enough to break the
                            // row is no more welcome than a total that does.
                            set: {
                                store.send(.binding(.set(
                                    \.exact,
                                    mutating(
                                        store.exact,
                                        member.id,
                                        String($0.prefix(Money.maximumInputLength))
                                    )
                                )))
                            }
                        )
                    ) {
                        Text(verbatim: "0")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 96)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10, style: .continuous))
                }
            }

            exactRemainderRow
        }
        .animation(Motion.spring, value: store.exactRemainder)
    }

    /// The running difference, which is the only thing standing between this
    /// mode and a save button that goes grey without saying why.
    ///
    /// Three named states rather than one signed number. "Left to assign
    /// −₺50,00" is a label that contradicts its own value, and it leaves the
    /// reader to work out from a minus sign that they have gone *over* — which
    /// is precisely the case that needs saying plainly, since it is the one
    /// they have to undo rather than finish. Each state names itself and shows
    /// an amount that needs no interpreting.
    @ViewBuilder
    private var exactRemainderRow: some View {
        let remainder = store.exactRemainder
        let isOver = remainder < 0
        let isSettled = remainder == 0

        HStack(spacing: 6) {
            Image(systemName: isSettled
                ? "checkmark.circle.fill"
                : (isOver ? "exclamationmark.circle.fill" : "circle.dotted"))
                .font(.caption)
            Text(isSettled
                ? L10n.financeExactBalanced
                : (isOver ? L10n.financeExactOver : L10n.financeExactRemaining))
                .font(.caption.weight(.medium))

            Spacer(minLength: 8)

            // Zero is already said by the label; printing it too invites the
            // reader to check the arithmetic of a row that is done.
            if !isSettled {
                Text(Money.text(abs(remainder), currency: store.currency))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(abs(remainder))))
            }
        }
        // Short of the total is unfinished; past it is wrong. They are
        // different problems and they do not get the same colour.
        .foregroundStyle(isSettled
            ? Palette.success
            : (isOver ? Palette.danger : Palette.warning))
        .padding(.top, 2)
    }

    /// What each person ends up carrying — the same arithmetic the server will
    /// run, so the preview and the saved ledger cannot disagree by a cent.
    private var previewRows: some View {
        FlowLayout(spacing: 8, lineSpacing: 6) {
            ForEach(store.preview) { split in
                HStack(spacing: 5) {
                    Circle()
                        .fill(MemberTint.color(for: split.userID.rawValue))
                        .frame(width: 7, height: 7)
                    Text(split.userID == store.currentUserID
                        ? String(localized: L10n.financeYou)
                        : (store.members[id: split.userID]?.displayName ?? ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Money.text(split.amount, currency: store.currency))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
    }
}

/// Replaces one key in a dictionary without the call site needing a `var`.
///
/// A binding's setter cannot mutate the store's state in place, so an exact
/// split's per-member field has to hand the reducer a whole new dictionary.
private func mutating<Key: Hashable, Value>(
    _ dictionary: [Key: Value],
    _ key: Key,
    _ value: Value
) -> [Key: Value] {
    var copy = dictionary
    copy[key] = value
    return copy
}

// MARK: - Bill

struct BillComposerSheet: View {
    @Bindable var store: StoreOf<BillComposerFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    AmountField(
                        currency: store.currency,
                        text: $store.amountText,
                        shakes: store.shakes,
                        currencyOptions: store.currencyOptions,
                        onCurrencyChange: { store.send(.binding(.set(\.currency, $0))) }
                    )

                    GlassCard {
                        VStack(spacing: 14) {
                            TextField(text: $store.title) { Text(L10n.financeBillTitlePlaceholder) }
                                .font(.body.weight(.medium))
                                .textInputAutocapitalization(.words)

                            Divider().opacity(0.4)

                            Picker(selection: $store.cycle) {
                                ForEach(BillCycle.allCases) { cycle in
                                    Label { Text(cycle.title) } icon: {
                                        Image(systemName: cycle.symbol)
                                    }
                                    .tag(cycle)
                                }
                            } label: {
                                Label { Text(L10n.financeCycleLabel) } icon: {
                                    Image(systemName: "repeat")
                                }
                            }

                            DatePicker(selection: $store.dueDate, displayedComponents: [.date]) {
                                Label { Text(L10n.financeDueDateLabel) } icon: {
                                    Image(systemName: "calendar.badge.clock")
                                }
                            }

                            Picker(selection: $store.responsible) {
                                Text(L10n.financeNobody).tag(UserID?.none)
                                ForEach(store.members) { member in
                                    Text(member.displayName).tag(UserID?.some(member.id))
                                }
                            } label: {
                                Label { Text(L10n.financeResponsibleLabel) } icon: {
                                    Image(systemName: "person.crop.circle")
                                }
                            }

                            Divider().opacity(0.4)

                            Toggle(isOn: $store.autoSplit) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.financeAutoSplitLabel)
                                    Text(store.autoSplit
                                        ? L10n.financeAutoSplitOn
                                        : L10n.financeAutoSplitOff)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    categoryRow
                    remindersCard

                    // A yearly subscription and the rent are not comparable
                    // until both are said per month. This is the line that
                    // makes them so.
                    if store.amountMinor > 0, store.cycle != .once {
                        HStack {
                            Label { Text(L10n.financeCommittedMonthly) } icon: {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            MoneyText(store.monthlyCost, currency: store.currency)
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                    }

                    if let error = store.inlineError {
                        InlineError(message: error)
                    }

                    if store.isEditing {
                        Button(role: .destructive) { store.send(.deleteTapped) } label: {
                            Label { Text(L10n.financeDeleteBill) } icon: {
                                Image(systemName: "trash")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.glass)
                        .tint(Palette.danger)
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Backdrop(tint: theme.accent))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(store.isEditing
                ? L10n.financeEditBillTitle
                : L10n.financeAddBill))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ComposerToolbar(
                    isSubmitting: store.isSubmitting,
                    canSubmit: store.canSubmit,
                    title: L10n.commonSave,
                    onSubmit: { store.send(.submitTapped) },
                    onCancel: { dismiss() }
                )
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .animation(Motion.spring, value: store.cycle)
            .animation(Motion.fade, value: store.inlineError)
        }
    }

    /// When the household hears about it.
    ///
    /// Three at most, and the rest go dim rather than refusing a tap with an
    /// explanation — the limit is visible, so it needs no words.
    private var remindersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label { Text(L10n.financeRemindersLabel) } icon: {
                        Image(systemName: store.reminders.isEmpty ? "bell.slash" : "bell.badge")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .font(.subheadline.weight(.medium))
                    Spacer(minLength: 8)
                    Text(store.reminders.isEmpty
                        ? L10n.financeRemindersOff
                        : L10n.financeReminderCount(store.reminders.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }

                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(Bill.reminderChoices, id: \.self) { days in
                        let isOn = store.reminders.contains(days)
                        let isReachable = isOn || store.canAddReminder
                        Button { store.send(.reminderToggled(days)) } label: {
                            Text(Bill.reminderTitle(days))
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .foregroundStyle(isOn ? Color.white : Color.primary)
                                .background(
                                    isOn ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.quaternary),
                                    in: .capsule
                                )
                                .contentShape(.capsule)
                        }
                        .buttonStyle(.pressable)
                        .disabled(!isReachable)
                        .opacity(isReachable ? 1 : 0.4)
                        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                    }
                }

                Text(L10n.financeRemindersHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .animation(Motion.spring, value: store.reminders)
        }
    }

    private var categoryRow: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.financeCategoryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(SpendCategory.allCases) { category in
                        let isSelected = store.category == category
                        Button { store.send(.binding(.set(\.category, category))) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: category.symbol)
                                    .font(.caption2.weight(.semibold))
                                Text(category.title).font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .foregroundStyle(isSelected ? Color.white : category.tint)
                            .background(
                                isSelected ? category.tint : category.tint.opacity(0.14),
                                in: .capsule
                            )
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            .animation(Motion.spring, value: store.category)
        }
    }
}

// MARK: - Paying a bill

/// Recording a payment. Short on purpose: it exists because half a household's
/// bills are variable, not because paying one should be a form.
struct PayBillSheet: View {
    @Bindable var store: StoreOf<PayBillFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    VStack(spacing: 6) {
                        Image(systemName: store.bill.category.symbol)
                            .font(.title2)
                            .foregroundStyle(store.bill.category.tint)
                            .frame(width: 52, height: 52)
                            .background(store.bill.category.tint.opacity(0.16), in: .circle)
                        Text(store.bill.title)
                            .font(.headline)
                        Text(store.bill.cycle.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    AmountField(currency: store.bill.currency, text: $store.amountText)

                    if let difference = store.difference {
                        // Says how far off the usual figure this is, which is
                        // the whole reason a variable bill gets a sheet.
                        Label {
                            Text(difference > 0
                                ? L10n.financeMoreThanUsual(
                                    Money.text(difference, currency: store.bill.currency))
                                : L10n.financeLessThanUsual(
                                    Money.text(-difference, currency: store.bill.currency)))
                        } icon: {
                            Image(systemName: difference > 0 ? "arrow.up.right" : "arrow.down.right")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .font(.caption)
                        .foregroundStyle(difference > 0 ? Palette.warning : Palette.success)
                        .transition(.opacity)
                    }

                    GlassCard {
                        VStack(spacing: 12) {
                            Picker(selection: $store.paidBy) {
                                ForEach(store.members) { member in
                                    Text(member.id == store.currentUserID
                                        ? String(localized: L10n.financeYou)
                                        : member.displayName)
                                        .tag(member.id)
                                }
                            } label: {
                                Label { Text(L10n.financePaidByLabel) } icon: {
                                    Image(systemName: "person.crop.circle")
                                }
                            }

                            if store.bill.autoSplit, store.memberCount > 1 {
                                Divider().opacity(0.4)
                                HStack {
                                    Label { Text(L10n.financeEachPays) } icon: {
                                        Image(systemName: "person.2")
                                    }
                                    .font(.subheadline)
                                    Spacer(minLength: 8)
                                    MoneyText(store.perPerson, currency: store.bill.currency)
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                    }

                    if let error = store.inlineError {
                        InlineError(message: error)
                    }

                    // Says what the button will do to the schedule, because a
                    // bill that silently moves its own due date is alarming the
                    // first time it happens.
                    Text(store.bill.cycle == .once
                        ? L10n.financePayOnceHint
                        : L10n.financePayRecurringHint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Metrics.screenPadding)
            }
            .background(Backdrop(tint: theme.accent))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(L10n.financeMarkPaid))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ComposerToolbar(
                    isSubmitting: store.isSubmitting,
                    canSubmit: store.canSubmit,
                    title: L10n.financePayAction,
                    onSubmit: { store.send(.payTapped) },
                    onCancel: { dismiss() }
                )
            }
            .animation(Motion.fade, value: store.inlineError)
            .animation(Motion.spring, value: store.difference)
        }
    }
}

// MARK: - Budget

struct BudgetEditorSheet: View {
    @Bindable var store: StoreOf<BudgetEditorFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    VStack(spacing: 6) {
                        Image(systemName: store.category.symbol)
                            .font(.title2)
                            .foregroundStyle(store.category.tint)
                            .frame(width: 52, height: 52)
                            .background(store.category.tint.opacity(0.16), in: .circle)
                            .contentTransition(.symbolEffect(.replace))
                        Text(store.category.title)
                            .font(.headline)
                        Text(L10n.financeBudgetHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    .animation(Motion.spring, value: store.category)

                    // Asked here rather than before the sheet opens, so every
                    // way in — the toolbar, the empty state, the grid's own
                    // button — lands on the same question.
                    if store.canChooseCategory {
                        GlassCard {
                            FlowLayout(spacing: 8, lineSpacing: 8) {
                                ForEach(store.choosableCategories) { category in
                                    let isSelected = store.category == category
                                    Button {
                                        store.send(.binding(.set(\.category, category)))
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: category.symbol)
                                                .font(.caption2.weight(.semibold))
                                            Text(category.title).font(.caption.weight(.medium))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .foregroundStyle(isSelected ? Color.white : category.tint)
                                        .background(
                                            isSelected ? category.tint : category.tint.opacity(0.14),
                                            in: .capsule
                                        )
                                        .contentShape(.capsule)
                                    }
                                    .buttonStyle(.pressable)
                                    .accessibilityAddTraits(
                                        isSelected ? [.isButton, .isSelected] : .isButton
                                    )
                                }
                            }
                        }
                    }

                    AmountField(
                        currency: store.currency,
                        text: $store.limitText,
                        currencyOptions: store.currencyOptions,
                        onCurrencyChange: { store.send(.binding(.set(\.currency, $0))) }
                    )

                    // Round numbers, so a first budget is a tap rather than a
                    // decision about the exact number of cents.
                    HStack(spacing: 8) {
                        ForEach(store.suggestions, id: \.self) { amount in
                            Button { store.send(.suggestionTapped(amount)) } label: {
                                Text(Money.compactText(amount, currency: store.currency))
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.glass)
                        }
                    }

                    if let error = store.inlineError {
                        InlineError(message: error)
                    }

                    if store.isEditing {
                        Button(role: .destructive) { store.send(.deleteTapped) } label: {
                            Label { Text(L10n.financeRemoveBudget) } icon: {
                                Image(systemName: "trash")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.glass)
                        .tint(Palette.danger)
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Backdrop(tint: theme.accent))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(store.isEditing
                ? L10n.financeEditBudgetTitle
                : L10n.financeAddBudget))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ComposerToolbar(
                    isSubmitting: store.isSubmitting,
                    canSubmit: store.canSubmit,
                    title: L10n.commonSave,
                    onSubmit: { store.send(.submitTapped) },
                    onCancel: { dismiss() }
                )
            }
            .animation(Motion.fade, value: store.inlineError)
        }
    }
}

// MARK: - Settling up

/// Squaring up.
///
/// Opens on the plan the server worked out — the fewest payments that clear
/// every balance — because "who pays whom" is the question, and a blank form is
/// asking a person to do the arithmetic the app was for.
struct SettleUpSheet: View {
    @Bindable var store: StoreOf<SettleUpFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    if store.isSquare {
                        EmptyStateView(
                            title: L10n.financeAllSquareTitle,
                            message: L10n.financeAllSquareMessage,
                            symbol: "checkmark.seal",
                            isCompact: true
                        )
                    } else {
                        if !store.openTransfers.isEmpty {
                            suggestions
                        }
                        manualEntry
                    }

                    if let error = store.inlineError {
                        InlineError(message: error)
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Backdrop(tint: theme.accent))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(L10n.financeSettleUp))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: { Text(L10n.commonClose) }
                }
            }
            .animation(Motion.spring, value: store.openTransfers)
            .animation(Motion.fade, value: store.inlineError)
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.financeSuggestedTitle,
                subtitle: L10n.financeSuggestedSubtitle,
                symbol: "sparkles"
            )

            GlassGroup {
                VStack(spacing: 8) {
                    ForEach(store.openTransfers) { transfer in
                        Button { store.send(.suggestionTapped(transfer)) } label: {
                            HStack(spacing: 10) {
                                Avatar(
                                    initials: initials(transfer.from),
                                    seed: transfer.from.rawValue,
                                    size: 30
                                )
                                Image(systemName: "arrow.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Palette.accessory)
                                Avatar(
                                    initials: initials(transfer.to),
                                    seed: transfer.to.rawValue,
                                    size: 30
                                )

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L10n.financeTransferLine(
                                        store.state.name(for: transfer.from),
                                        store.state.name(for: transfer.to)
                                    ))
                                    .font(.subheadline)
                                    .lineLimit(1)
                                }

                                Spacer(minLength: 4)

                                Text(Money.text(transfer.amount, currency: store.currency))
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, Metrics.cardPadding)
                            .padding(.vertical, 10)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.pressable)
                        .glassCard(cornerRadius: Metrics.tightRadius)
                    }
                }
            }
        }
    }

    private var manualEntry: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Picker(selection: $store.from) {
                        Text(L10n.financeNobody).tag(UserID?.none)
                        ForEach(store.members) { member in
                            Text(store.state.name(for: member.id)).tag(UserID?.some(member.id))
                        }
                    } label: { Text(L10n.financeFromLabel) }
                    .frame(maxWidth: .infinity)

                    Button { store.send(.swapTapped) } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.footnote.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(L10n.financeSwapDirection))

                    Picker(selection: $store.to) {
                        Text(L10n.financeNobody).tag(UserID?.none)
                        ForEach(store.members) { member in
                            Text(store.state.name(for: member.id)).tag(UserID?.some(member.id))
                        }
                    } label: { Text(L10n.financeToLabel) }
                    .frame(maxWidth: .infinity)
                }

                AmountField(currency: store.currency, text: $store.amountText, isCompact: true)

                TextField(text: $store.note) { Text(L10n.financeNotePlaceholder) }
                    .font(.subheadline)

                PrimaryButton(
                    L10n.financeRecordPayment,
                    symbol: "checkmark.circle",
                    isLoading: store.isSubmitting
                ) {
                    store.send(.recordTapped)
                }
                .disabled(!store.canSubmit)
            }
        }
    }

    private func initials(_ id: UserID) -> String {
        User.initials(from: store.state.name(for: id))
    }
}
