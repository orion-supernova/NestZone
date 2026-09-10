import ComposableArchitecture
import SwiftUI

/// Picking what an amount is written in.
///
/// This was a `Menu` holding every common ISO code — about 150 rows, no search,
/// no order beyond the alphabet after the household's own. iOS renders that as
/// one enormous scrolling popover, so choosing Turkish lira meant flicking past
/// sixty currencies with no way to type. It is the one control in the app that
/// is genuinely faster with a keyboard.
///
/// So: a sheet with a search field, and the codes worth reaching for hoisted
/// above the alphabet — what this person picked recently, then what the
/// household already writes in. Searching collapses the sections into one
/// ranked list, because once somebody types "tur" the question is no longer
/// "which of my currencies" but "which currency".
///
/// A plain SwiftUI view rather than a feature: it owns one `String`, five
/// composers present it, and giving each of them a reducer, an action and a
/// destination case to route a currency code through would be more plumbing
/// than the value it carries. It records the pick itself, so every site that
/// presents one gets the memory for free.
public struct CurrencyPicker: View {
    /// What is picked now, so the row can be ticked and the list can open on it.
    public let selected: String
    /// The currencies this household already writes in, most-used first. Shown
    /// above the alphabet because they are nearly always the answer.
    public let used: [String]
    public let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var search = ""

    public init(selected: String, used: [String] = [], onPick: @escaping (String) -> Void) {
        self.selected = selected
        self.used = used
        self.onPick = onPick
    }

    public var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    Section {
                        ForEach(matches, id: \.self) { row($0) }
                    } header: {
                        Text(L10n.calendarSearchResults(matches.count))
                    }
                    if matches.isEmpty {
                        // A dead end with no explanation reads as a broken
                        // list. It is nearly always a typo in three letters.
                        ContentUnavailableView.search(text: search)
                            .listRowBackground(Color.clear)
                    }
                } else {
                    if !recent.isEmpty {
                        Section(L10n.currencyRecent) {
                            ForEach(recent, id: \.self) { row($0) }
                        }
                    }
                    if !household.isEmpty {
                        Section(L10n.currencyInThisHome) {
                            ForEach(household, id: \.self) { row($0) }
                        }
                    }
                    Section(L10n.currencyAll) {
                        ForEach(rest, id: \.self) { row($0) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(L10n.currencyPickerTitle))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $search,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(L10n.currencySearchPlaceholder)
            )
            // A three-letter code is never capitalised for you and never
            // autocorrected into a word: "try" is a currency here, not a verb.
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: {
                        Text(L10n.commonCancel)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Rows

    private func row(_ code: String) -> some View {
        Button {
            onPick(code)
            CurrencyDefaults.remember(code)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // The code is the identity — monospaced so a column of them
                // lines up and can be scanned rather than read.
                Text(code)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 46, alignment: .leading)

                Text(Money.name(for: code))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let symbol = Money.symbol(for: code), symbol != code {
                    Text(symbol)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                if code == selected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(theme.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(Money.name(for: code)), \(code)"))
        .accessibilityAddTraits(code == selected ? [.isSelected] : [])
    }

    // MARK: - Sections

    private var isSearching: Bool {
        !search.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Recently picked, minus anything the household section will show anyway —
    /// the same code twice in two sections is not two answers.
    private var recent: [String] {
        CurrencyDefaults.recent.filter { !used.contains($0) }
    }

    private var household: [String] { used }

    /// Everything else. The two sections above are the shortcut; this is the
    /// full list, and it stays complete so nothing is unreachable without
    /// searching for it.
    private var rest: [String] {
        let hoisted = Set(recent + household)
        return Money.pickerCodes(used: []).filter { !hoisted.contains($0) }
    }

    /// Ranked, not merely filtered.
    ///
    /// A prefix on the code comes first — somebody typing "eu" wants EUR, not
    /// every currency whose country name happens to contain those letters — and
    /// a prefix on the name comes next, so "tur" reaches the Turkish lira
    /// without knowing it is spelled TRY.
    private var matches: [String] {
        let needle = search
            .trimmingCharacters(in: .whitespaces)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: L10n.locale)
        guard !needle.isEmpty else { return [] }

        func fold(_ text: String) -> String {
            text.folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: L10n.locale
            )
        }

        // The household's own first within each tier, so a two-currency
        // household still sees its own before the rest of the world.
        let hoisted = recent + household
        let all = hoisted + Money.pickerCodes(used: []).filter { !Set(hoisted).contains($0) }

        var codePrefix: [String] = []
        var namePrefix: [String] = []
        var contains: [String] = []
        for code in all {
            let name = fold(Money.name(for: code))
            if fold(code).hasPrefix(needle) {
                codePrefix.append(code)
            } else if name.hasPrefix(needle) {
                namePrefix.append(code)
            } else if name.contains(needle) || fold(code).contains(needle) {
                contains.append(code)
            }
        }
        return codePrefix + namePrefix + contains
    }
}
