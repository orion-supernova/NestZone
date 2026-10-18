import Foundation

// Reading one line typed into Add anything — "süt, yumurta, ekmek", "take the
// bins out tomorrow", "Ali paid 300 for internet" — the way a flatmate would.
//
// Pure and deterministic: text in, a draft out, no I/O and no model. That is
// the point of it. It runs on every keystroke, so it has to be instant; it is
// the half of the guess that can be unit-tested; and it is the only half that
// is ever allowed to produce *content* — a title, a date, an amount, a name.
// The on-device model (`CaptureClassifierClient`) is consulted for the chip
// alone, because in testing it invented a payer nobody had typed, and a
// classifier that writes into the ledger is a liability, not a feature.
//
// Bilingual regardless of the phone's language. A household types in whichever
// language it speaks, and a Turkish house with English phones still writes
// "süt bitti".

// MARK: - What the parser hands back

/// The six places a line can land.
public enum CaptureKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case shopping, chore, note, problem, event, expense

    public var id: String { rawValue }

    /// Whether adding one opens that module's full form rather than writing
    /// straight away.
    ///
    /// A problem needs a room and a severity, an event a time and a guest list,
    /// an expense a split — none of which a sentence carries reliably enough to
    /// write behind somebody's back. The form opens already filled in with
    /// whatever was understood, so the sentence still saved the typing.
    public var continuesInComposer: Bool {
        switch self {
        case .shopping, .chore, .note: false
        case .problem, .event, .expense: true
        }
    }
}

/// How sure the rules are about the kind.
///
/// `strong` is a keyword that leaves no real doubt — "fix", "ödedi" with an
/// amount, a comma list. `weak` is a lean — a bare date, a single word. `none`
/// is silence, which is when the model and then habit get a say.
public enum CaptureConfidence: Int, Comparable, Sendable {
    case none, weak, strong

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A moment somebody named.
public struct CaptureDate: Equatable, Sendable {
    public var date: Date
    /// False when only a day was said — "tomorrow", "Cuma" — and the clock time
    /// in `date` is a placeholder the caller should replace with its own idea
    /// of a sensible hour, not show as though somebody had said noon.
    public var hasTime: Bool

    public init(date: Date, hasTime: Bool) {
        self.date = date
        self.hasTime = hasTime
    }
}

/// Money somebody named, already in the only form the server takes.
public struct CaptureAmount: Equatable, Sendable {
    public var minorUnits: Int
    /// `nil` when no currency was written — "Ali paid 300". The minor units
    /// were then counted in the fallback currency the parser was given, which
    /// is the one the composer will open on, so the two agree.
    public var currency: String?

    public init(minorUnits: Int, currency: String?) {
        self.minorUnits = minorUnits
        self.currency = currency
    }
}

/// Everything understood from one line.
public struct CaptureDraft: Equatable, Sendable {
    /// The rules' pick, or `nil` when they have no opinion at all.
    public var kind: CaptureKind?
    public var confidence: CaptureConfidence
    /// What was typed, trimmed. Empty means there is nothing to add.
    public var text: String
    /// The shopping reading: the line split into items, with "buy" and "al"
    /// taken off. Always computed, so a person who overrides the chip to
    /// Shopping gets a list rather than one long item.
    public var items: [String]
    public var date: CaptureDate?
    public var amount: CaptureAmount?
    /// The one household member the line names, if it names exactly one. Two
    /// different members is an ambiguity, and an ambiguity is reported as
    /// nobody rather than as whichever was first.
    public var member: UserID?
    /// The member the line says paid — "Ali paid", "Ali … ödedi" — which is
    /// narrower than `member`: in "I paid Ali 300" Ali is named, but did not pay.
    public var payer: UserID?
    /// Hints for the composers, from the same words that picked the kind.
    public var eventKind: EventKind?
    public var issueArea: IssueArea?

    /// The line without the date phrase, for a chore or an event: "take the
    /// bins out tomorrow" is a chore called "take the bins out", due tomorrow.
    var undated: String
    /// The line without the amount, for an expense.
    var unpriced: String
    /// The line without a "note:" / "not:" prefix.
    var noteBody: String

    public static let empty = CaptureDraft(
        kind: nil, confidence: .none, text: "", items: [],
        undated: "", unpriced: "", noteBody: ""
    )

    public init(
        kind: CaptureKind?,
        confidence: CaptureConfidence,
        text: String,
        items: [String],
        date: CaptureDate? = nil,
        amount: CaptureAmount? = nil,
        member: UserID? = nil,
        payer: UserID? = nil,
        eventKind: EventKind? = nil,
        issueArea: IssueArea? = nil,
        undated: String,
        unpriced: String,
        noteBody: String
    ) {
        self.kind = kind
        self.confidence = confidence
        self.text = text
        self.items = items
        self.date = date
        self.amount = amount
        self.member = member
        self.payer = payer
        self.eventKind = eventKind
        self.issueArea = issueArea
        self.undated = undated
        self.unpriced = unpriced
        self.noteBody = noteBody
    }

    public var isEmpty: Bool { text.isEmpty }

    /// The title the line becomes in `kind` — the person's own words, minus
    /// only what has a field of its own over there.
    ///
    /// Can be empty, and that is an answer rather than a gap: "yarın" alone is
    /// a date with no chore attached, and "300 TL" alone is an expense still
    /// waiting for its name. Falling back to the whole line would write a
    /// chore called "yarın" or an expense called "300 TL".
    public func title(for kind: CaptureKind) -> String {
        func flat(_ string: String) -> String {
            string.replacingOccurrences(of: "\n", with: " ")
        }
        switch kind {
        case .chore, .event: return flat(undated)
        case .expense: return flat(unpriced)
        case .note: return noteBody
        case .problem: return flat(text)
        case .shopping: return items.joined(separator: ", ")
        }
    }
}

// MARK: - The parser

public enum CaptureParser {
    /// The most items one line may add. Mirrors `MANY_LIMIT` in
    /// `backend/convex/shopping.ts`, which refuses anything longer.
    public static let itemLimit = 50

    /// Reads `raw`.
    ///
    /// - Parameters:
    ///   - members: the household, for "Ali" and "Ayşe'ye".
    ///   - now: what "tomorrow" and "Friday" are counted from.
    ///   - locale: the app's language. The keyword lists are read in both
    ///     languages whatever it is; it only sets the calendar's conventions.
    ///   - calendar: the calendar dates are built in. Injected for tests.
    ///   - fallbackCurrency: what an amount with no currency written next to
    ///     it is counted in — the currency the expense composer will open on.
    public static func parse(
        _ raw: String,
        members: [User],
        now: Date,
        locale: Locale,
        calendar: Calendar = .current,
        fallbackCurrency: String
    ) -> CaptureDraft {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .empty }

        var calendar = calendar
        calendar.locale = locale

        let tokens = Token.split(text)
        let noteBody = stripNotePrefix(text)
        let isNotePrefixed = noteBody != text
        let hits = Vocabulary.hits(in: tokens)

        // Money with its currency written next to it is read before dates, so
        // "25.10 TL" stays twenty-five lira rather than becoming the 25th of
        // October. A bare number is read after, and only after a paying word,
        // so "Friday 8pm" never becomes eight of anything.
        let priced = AmountReader.explicit(text, fallbackCurrency: fallbackCurrency)
        let date = DateReader(
            text: text,
            tokens: tokens,
            blocked: priced.map { [$0.range] } ?? [],
            now: now,
            calendar: calendar
        ).read()
        let dateRanges = date?.ranges ?? []
        let hasPaidWord = hits.contains { $0.kind == .expense && $0.role == .signal }
        let amount = priced ?? (hasPaidWord
            ? AmountReader.bare(text, excluding: dateRanges, fallbackCurrency: fallbackCurrency)
            : nil)

        let undated = tidy(text, removing: dateRanges)
        let unpriced = tidy(text, removing: amount.map { [$0.range] } ?? [])
        let items = shoppingItems(from: undated)

        let (member, payer) = mentionedMembers(
            in: tokens,
            skipping: Set(date?.tokens ?? []),
            members: members,
            hits: hits
        )

        let verdict = Scorer(
            tokens: tokens,
            hits: hits,
            isNotePrefixed: isNotePrefixed,
            hasDate: date != nil,
            amount: amount?.amount,
            items: items
        ).verdict()

        return CaptureDraft(
            kind: verdict.kind,
            confidence: verdict.confidence,
            text: text,
            items: items,
            date: date.map { CaptureDate(date: $0.date, hasTime: $0.hasTime) },
            amount: amount?.amount,
            member: member,
            payer: payer,
            eventKind: hits.lazy.compactMap(\.eventKind).first,
            issueArea: hits.lazy.compactMap(\.issueArea).first,
            undated: undated,
            unpriced: unpriced,
            noteBody: noteBody
        )
    }

    // MARK: Text helpers

    /// Case- and accent-blind, Turkish-aware: "YARIN", "yarın" and "yarin" all
    /// read "yarin"; "İ" and "I" both fold to "i".
    ///
    /// Lowercased in Turkish first, so the dotted capital becomes a plain "i"
    /// rather than an "i" with a combining dot, and the dotless "ı" is then
    /// flattened by hand — it has no decomposition for diacritic folding to
    /// remove. An English "INTERNET" goes through "ınternet" and comes out the
    /// same as it went in.
    static func fold<S: StringProtocol>(_ string: S) -> String {
        String(string)
            .replacingOccurrences(of: "’", with: "'")
            .lowercased(with: turkish)
            .replacingOccurrences(of: "ı", with: "i")
            .folding(options: [.diacriticInsensitive], locale: nil)
    }

    private static let turkish = Locale(identifier: "tr_TR")

    /// "note: wifi is on the router" → "wifi is on the router".
    static func stripNotePrefix(_ text: String) -> String {
        let folded = fold(text.prefix(6))
        for prefix in Vocabulary.notePrefixes where folded.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    /// `text` with `ranges` cut out and the seams closed up — doubled spaces,
    /// a comma left hanging, an "at" or "saat" that only introduced the date.
    /// Line breaks survive, because on a shopping list they are separators.
    static func tidy(_ text: String, removing ranges: [Range<String.Index>]) -> String {
        var kept = ""
        var cursor = text.startIndex
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) where range.lowerBound >= cursor {
            kept += text[cursor..<range.lowerBound]
            kept += " "
            cursor = range.upperBound
        }
        kept += text[cursor...]
        return kept
            .components(separatedBy: .newlines)
            .map(tidyLine)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func tidyLine(_ line: String) -> String {
        var words = line
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        // A connector only reads as one with something after it; left at the
        // end of the title it is the ghost of the phrase that was removed.
        while let last = words.last, Vocabulary.danglers.contains(fold(last)) {
            words.removeLast()
        }
        while let first = words.first, Vocabulary.leadingDanglers.contains(fold(first)), words.count > 1 {
            words.removeFirst()
        }
        return words
            .joined(separator: " ")
            .replacingOccurrences(of: " ,", with: ",")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-–—").union(.whitespacesAndNewlines))
    }

    // MARK: Shopping

    /// "buy milk, eggs and bread" → ["milk", "eggs", "bread"].
    ///
    /// Commas, semicolons and new lines always separate. "and", "ve", "&"
    /// separate the whole line when there are no commas, but only the *last*
    /// segment when there are — "mac and cheese, milk" is two things and "milk,
    /// eggs and bread" is three. "mac and cheese" on its own still splits; the
    /// preview shows it, and a comma is how to say otherwise.
    static func shoppingItems(from text: String) -> [String] {
        var segments = separate(stripShoppingTriggers(text))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let last = segments.popLast() {
            segments += splitOnConjunctions(last)
        }

        var seen: Set<String> = []
        var items: [String] = []
        for segment in segments {
            let item = segment
                .trimmingCharacters(in: CharacterSet(charactersIn: "-–•*·.").union(.whitespaces))
            guard !item.isEmpty else { continue }
            guard seen.insert(fold(item)).inserted else { continue }
            items.append(item)
            if items.count == itemLimit { break }
        }
        return items
    }

    /// Splits on commas, semicolons and line breaks — except a comma between
    /// two digits, which is "2,5 kg", not two things.
    private static func separate(_ text: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var previous: Character?
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            let isDecimalComma = character == ","
                && previous?.isNumber == true
                && next < text.endIndex && text[next].isNumber
            if (character == "," || character == ";" || character.isNewline) && !isDecimalComma {
                segments.append(current)
                current = ""
            } else {
                current.append(character)
            }
            previous = character
            index = next
        }
        segments.append(current)
        return segments
    }

    /// "and" and "ve" as whole words, in any case, and "&". A whole word only:
    /// "kavun" and "brandy" are one thing each.
    private static func splitOnConjunctions(_ segment: String) -> [String] {
        segment
            .split(separator: #/\s+(?i:and|ve)\s+|\s*&\s*/#)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Takes "buy", "we need", "shopping:" off the front and "al", "lazım",
    /// "bitti" off the back — the words that said *where* the line goes rather
    /// than *what* goes there.
    static func stripShoppingTriggers(_ text: String) -> String {
        var words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var changed = true
        while changed, !words.isEmpty {
            changed = false
            for phrase in Vocabulary.shoppingLeads {
                let count = phrase.count
                guard words.count > count else { continue }
                let head = words.prefix(count).map { fold($0).trimmingCharacters(in: .punctuationCharacters) }
                if head == phrase {
                    words.removeFirst(count)
                    changed = true
                    break
                }
            }
        }
        changed = true
        while changed, !words.isEmpty {
            changed = false
            for phrase in Vocabulary.shoppingTails {
                let count = phrase.count
                guard words.count > count else { continue }
                let tail = words.suffix(count).map { fold($0).trimmingCharacters(in: .punctuationCharacters) }
                if tail == phrase {
                    words.removeLast(count)
                    changed = true
                    break
                }
            }
        }
        return words.joined(separator: " ")
    }

    // MARK: Members

    /// The member named, and the member named *as the payer*.
    ///
    /// Matched on first names, Turkish-folded, with an apostrophe suffix taken
    /// off — "Ayşe's", "Ali'ye", "Ali’nin" all name the person. The payer is
    /// stricter: a bare name (no suffix — "Ali'ye" is who was paid, not who
    /// paid) standing before the paying word, which is where the subject sits
    /// in both "Ali paid 300" and "Ali internete 300 TL ödedi".
    static func mentionedMembers(
        in tokens: [Token],
        skipping skipped: Set<Int>,
        members: [User],
        hits: [Vocabulary.Hit]
    ) -> (member: UserID?, payer: UserID?) {
        var byName: [String: [UserID]] = [:]
        for member in members {
            guard let first = member.displayName.split(separator: " ").first else { continue }
            let key = fold(first)
            guard key.count >= 2 else { continue }
            byName[key, default: []].append(member.id)
        }
        // Two members with the same first name can never be told apart by it.
        let unique = byName.compactMapValues { $0.count == 1 ? $0[0] : nil }

        let paidAt = hits.first { $0.kind == .expense && $0.role == .signal }?.tokens.lowerBound
        var named: Set<UserID> = []
        var payers: Set<UserID> = []
        for (index, token) in tokens.enumerated() where !skipped.contains(index) {
            guard let id = unique[token.stem] else { continue }
            named.insert(id)
            if let paidAt, index < paidAt, token.suffix.isEmpty {
                payers.insert(id)
            }
        }
        return (
            named.count == 1 ? named.first : nil,
            payers.count == 1 ? payers.first : nil
        )
    }
}

// MARK: - Tokens

/// One word of the line, with where it sits in the original text.
struct Token: Equatable {
    let range: Range<String.Index>
    /// Folded, whole: "ayse's", "20:00'de".
    let word: String
    /// Folded, before any apostrophe: "ayse", "20:00".
    let stem: String
    /// Folded, after the apostrophe: "s", "de". Empty when there is none.
    let suffix: String

    var isNumeric: Bool { stem.first?.isNumber == true }

    /// Splits on anything that is not a letter or a digit, except that a
    /// separator between two digits ("19:30", "25.10.2026") and an apostrophe
    /// before letters ("Ayşe's", "Ali'ye", "20:00'de") stay inside the word.
    static func split(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var index = text.startIndex
        while index < text.endIndex {
            guard text[index].isLetter || text[index].isNumber else {
                index = text.index(after: index)
                continue
            }
            let start = index
            var end = text.index(after: index)
            while end < text.endIndex {
                let character = text[end]
                if character.isLetter || character.isNumber {
                    end = text.index(after: end)
                    continue
                }
                let next = text.index(after: end)
                guard next < text.endIndex else { break }
                if ":./".contains(character),
                   text[text.index(before: end)].isNumber,
                   text[next].isNumber {
                    end = next
                    continue
                }
                if character == "'" || character == "’", text[next].isLetter {
                    end = next
                    continue
                }
                break
            }
            tokens.append(Token(text: text, range: start..<end))
            index = end
        }
        return tokens
    }

    init(text: String, range: Range<String.Index>) {
        self.range = range
        let folded = CaptureParser.fold(text[range])
        word = folded
        if let apostrophe = folded.firstIndex(of: "'") {
            stem = String(folded[..<apostrophe])
            suffix = String(folded[folded.index(after: apostrophe)...])
        } else {
            stem = folded
            suffix = ""
        }
    }
}

// MARK: - Dates

/// Reads "tomorrow", "Friday 8pm", "yarın 19:30", "Cuma akşamı", "12 Kasım".
///
/// Two halves, and the split is the result of testing rather than taste.
/// `NSDataDetector` reads English well and Turkish only some of the time: it
/// takes "yarın 19:30" and "Cuma 20:00", but not "yarın" or "Perşembe" on their
/// own, nor "YARIN 19:30" in capitals; it reads a bare "11:00" typed on a
/// Sunday afternoon as eleven at *night*; it swallows "yemek" into "yemek cuma"
/// as though the meal were part of the date; and it has no reference date at
/// all — it always counts from the device clock. So the everyday phrases — a
/// day word, a weekday, a clock time — are read here, by rules, from `now`. The
/// detector is kept for what it reads reliably and what does not depend on
/// today: a written-out date, "12 Kasım", "Nov 12", "25.10".
struct DateReader {
    let text: String
    let tokens: [Token]
    /// Stretches already spoken for — an amount with its currency — that no
    /// date may claim.
    let blocked: [Range<String.Index>]
    let now: Date
    let calendar: Calendar

    struct Reading {
        var date: Date
        var hasTime: Bool
        /// Indices into `tokens` that were part of the phrase.
        var tokens: [Int]
        var ranges: [Range<String.Index>]
    }

    private struct Anchor {
        var day: Date
        var tokens: [Int]
        /// "tonight", "Cuma akşamı": the part of day said with it, as an hour.
        var partOfDay: Int?
    }

    private struct Clock {
        var hour: Int
        var minute: Int
        var tokens: [Int]
        /// Whether am/pm was spelled out, which settles the hour outright.
        var meridiemSaid: Bool
    }

    func read() -> Reading? {
        var used: Set<Int> = []
        let anchor = readAnchor(used: &used)
        let clock = readClock(used: &used, anchorPart: anchor?.partOfDay)

        if let anchor {
            let base = calendar.startOfDay(for: anchor.day)
            if let clock {
                let date = at(base, hour: clock.hour, minute: clock.minute)
                return reading(date, hasTime: true, tokens: anchor.tokens + clock.tokens)
            }
            if let part = anchor.partOfDay {
                return reading(at(base, hour: part, minute: 0), hasTime: true, tokens: anchor.tokens)
            }
            return reading(at(base, hour: 12, minute: 0), hasTime: false, tokens: anchor.tokens)
        }

        if var written = detectWrittenDate() {
            if let clock, !clock.tokens.contains(where: written.tokens.contains) {
                written.date = at(
                    calendar.startOfDay(for: written.date),
                    hour: clock.hour,
                    minute: clock.minute
                )
                written.hasTime = true
                written.tokens += clock.tokens
                written.ranges += clock.tokens.map { tokens[$0].range }
            }
            return written
        }

        if let clock {
            // A time with no day is the next time the clock says it: "saat 20:00"
            // typed at nine in the evening means tomorrow, not an hour ago.
            var date = at(calendar.startOfDay(for: now), hour: clock.hour, minute: clock.minute)
            if date <= now, let next = calendar.date(byAdding: .day, value: 1, to: date) {
                date = next
            }
            return reading(date, hasTime: true, tokens: clock.tokens)
        }
        return nil
    }

    private func reading(_ date: Date, hasTime: Bool, tokens indices: [Int]) -> Reading {
        let sorted = Array(Set(indices)).sorted()
        return Reading(
            date: date,
            hasTime: hasTime,
            tokens: sorted,
            ranges: sorted.map { tokens[$0].range }
        )
    }

    private func at(_ day: Date, hour: Int, minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
    }

    private func isBlocked(_ index: Int) -> Bool {
        blocked.contains { $0.overlaps(tokens[index].range) }
    }

    private func stem(_ index: Int) -> String {
        tokens.indices.contains(index) ? tokens[index].stem : ""
    }

    // MARK: Day

    private func readAnchor(used: inout Set<Int>) -> Anchor? {
        for index in tokens.indices where !isBlocked(index) {
            // Multi-word relative days first, so "the day after tomorrow" is
            // never read as "tomorrow".
            for phrase in DateWords.relativePhrases where matches(phrase.words, at: index) {
                var anchor = Anchor(
                    day: day(phrase.offset),
                    tokens: Array(index..<(index + phrase.words.count)),
                    partOfDay: phrase.partOfDay
                )
                extend(&anchor, after: index + phrase.words.count - 1)
                used.formUnion(anchor.tokens)
                return anchor
            }

            if let relative = DateWords.relativeDays[tokens[index].stem] {
                var anchor = Anchor(day: day(relative.offset), tokens: [index], partOfDay: relative.partOfDay)
                extend(&anchor, after: index)
                used.formUnion(anchor.tokens)
                return anchor
            }

            if let weekday = weekday(at: index) {
                var span = [index]
                var weeksAhead = 0
                if DateWords.nextWeek.contains(stem(index - 1)) {
                    weeksAhead = 1
                    span.append(index - 1)
                } else if DateWords.weekdayLeads.contains(stem(index - 1)) {
                    span.append(index - 1)
                }
                var anchor = Anchor(
                    day: upcoming(weekday, weeksAhead: weeksAhead),
                    tokens: span,
                    partOfDay: nil
                )
                extend(&anchor, after: index)
                used.formUnion(anchor.tokens)
                return anchor
            }
        }
        return nil
    }

    /// "Cuma günü", "yarın akşam", "Friday evening", "on Friday": takes in what
    /// sits next to a day and only makes sense attached to it.
    private func extend(_ anchor: inout Anchor, after index: Int) {
        var next = index + 1
        while tokens.indices.contains(next), !isBlocked(next) {
            let word = tokens[next].stem
            if DateWords.dayTrailers.contains(word) {
                anchor.tokens.append(next)
            } else if let hour = DateWords.partsOfDay[word] {
                anchor.partOfDay = anchor.partOfDay ?? hour
                // "Cuma akşam yemeği": the evening is when, but "akşam yemeği"
                // is also what — dinner — so the word stays in the title.
                guard !DateWords.mealWords.contains(stem(next + 1)) else { break }
                anchor.tokens.append(next)
                // "öğleden sonra": the second word belongs to the first.
                if stem(next + 1) == "sonra" {
                    anchor.tokens.append(next + 1)
                    next += 1
                }
            } else {
                break
            }
            next += 1
        }
        if let first = anchor.tokens.min(), DateWords.dayLeads.contains(stem(first - 1)) {
            anchor.tokens.append(first - 1)
        }
    }

    /// The weekday a token names, if it names one *as a day*.
    ///
    /// Turkish weekdays take case endings — "cumaya", "salıdan", "Cuma'ya" — so
    /// a weekday is a name plus one of a short list of endings, longest names
    /// first so "cumartesi" is never read as "cuma". "Pazar" is also the word
    /// for a market, so on its own it only counts with "günü", a time, or a
    /// "bu"/"haftaya" in front: "pazardan domates al" is shopping, not Sunday.
    private func weekday(at index: Int) -> Int? {
        let token = tokens[index]
        if let english = DateWords.englishWeekdays[token.stem] { return english }

        for (name, weekday) in DateWords.turkishWeekdays where token.stem.hasPrefix(name) {
            let rest = String(token.stem.dropFirst(name.count))
            let ending = rest.isEmpty ? token.suffix : rest
            guard DateWords.caseEndings.contains(ending) else { continue }
            if name == "pazar" {
                let before = stem(index - 1)
                let after = tokens.indices.contains(index + 1) ? tokens[index + 1] : nil
                let anchored = DateWords.nextWeek.contains(before)
                    || DateWords.weekdayLeads.contains(before)
                    || after.map { DateWords.dayTrailers.contains($0.stem) || $0.isNumeric } == true
                guard anchored, ending.isEmpty else { return nil }
            }
            return weekday
        }
        return nil
    }

    /// The next `weekday` after today — a week out when it *is* today, because
    /// "Sunday" said on a Sunday nearly always means the next one, and the same
    /// evening is "tonight" — plus `weeksAhead` for "next Friday", "haftaya
    /// Cuma". The same reading `NSDataDetector` gives both.
    private func upcoming(_ weekday: Int, weeksAhead: Int) -> Date {
        let today = calendar.component(.weekday, from: now)
        var offset = (weekday - today + 7) % 7
        if offset == 0 { offset = 7 }
        return day(offset + 7 * weeksAhead)
    }

    private func matches(_ phrase: [String], at index: Int) -> Bool {
        guard index + phrase.count <= tokens.count else { return false }
        return phrase.indices.allSatisfy { tokens[index + $0].stem == phrase[$0] && !isBlocked(index + $0) }
    }

    // MARK: Time

    /// "8pm", "19:30", "saat 9", "at 8", "8'de", "akşam 8", "20:00'de".
    private func readClock(used: inout Set<Int>, anchorPart: Int?) -> Clock? {
        for index in tokens.indices where !used.contains(index) && !isBlocked(index) {
            guard var clock = clock(at: index) else { continue }

            // What the words around it say about the half of the day.
            var part = anchorPart
            if let before = DateWords.partsOfDay[stem(index - 1)] {
                part = before
                if !used.contains(index - 1) { clock.tokens.insert(index - 1, at: 0) }
            } else if stem(index - 1) == "sonra", stem(index - 2) == "ogleden" {
                // "öğleden sonra 3": the afternoon, said in two words.
                part = 15
                for lead in [index - 2, index - 1] where !used.contains(lead) {
                    clock.tokens.insert(lead, at: 0)
                }
            }
            if DateWords.timeLeads.contains(stem(index - 1)), !used.contains(index - 1) {
                clock.tokens.insert(index - 1, at: 0)
            }
            if !clock.meridiemSaid, (1...11).contains(clock.hour) {
                clock.hour = resolveMeridiem(clock.hour, part: part)
            }
            used.formUnion(clock.tokens)
            return clock
        }
        return nil
    }

    private func clock(at index: Int) -> Clock? {
        let token = tokens[index]
        let word = token.stem
        let after = stem(index + 1)
        let introduced = DateWords.timeLeads.contains(stem(index - 1))

        // "8pm", "7:30am".
        for meridiem in ["am", "pm"] where word.hasSuffix(meridiem) {
            guard let time = hourMinute(String(word.dropLast(2)), allowDot: true),
                  (1...12).contains(time.hour) else { continue }
            return Clock(
                hour: twentyFour(time.hour, meridiem),
                minute: time.minute,
                tokens: [index],
                meridiemSaid: true
            )
        }
        // "8 pm".
        if after == "am" || after == "pm",
           let time = hourMinute(word, allowDot: true), (1...12).contains(time.hour) {
            return Clock(
                hour: twentyFour(time.hour, after),
                minute: time.minute,
                tokens: [index, index + 1],
                meridiemSaid: true
            )
        }
        // "19:30", "20:00'de" — a colon is a time wherever it stands. A dot
        // only after "saat" or "at": "12.50" on its own is far more often a
        // price than half past noon.
        if word.contains(":") || (word.contains(".") && introduced),
           token.suffix.isEmpty || DateWords.locativeEndings.contains(token.suffix),
           let time = hourMinute(word, allowDot: introduced) {
            return Clock(hour: time.hour, minute: time.minute, tokens: [index], meridiemSaid: false)
        }
        // "8'de", "10'da": the Turkish "at eight".
        if DateWords.locativeEndings.contains(token.suffix), let hour = Int(word), (0...23).contains(hour) {
            return Clock(hour: hour, minute: 0, tokens: [index], meridiemSaid: false)
        }
        // "saat 9", "at 8", "akşam 8", "öğleden sonra 3".
        let afterPart = DateWords.partsOfDay[stem(index - 1)] != nil
            || (stem(index - 1) == "sonra" && stem(index - 2) == "ogleden")
        if introduced || afterPart,
           token.suffix.isEmpty, let hour = Int(word), (0...23).contains(hour) {
            return Clock(hour: hour, minute: 0, tokens: [index], meridiemSaid: false)
        }
        return nil
    }

    /// "19:30" → 19:30; "8" → 8:00. `nil` for anything that is not a reading
    /// off a clock.
    private func hourMinute(_ text: String, allowDot: Bool) -> (hour: Int, minute: Int)? {
        let parts = text.split(whereSeparator: { $0 == ":" || (allowDot && $0 == ".") })
        guard (1...2).contains(parts.count), let hour = Int(parts[0]), (0...23).contains(hour) else {
            return nil
        }
        guard parts.count == 2 else { return (hour, 0) }
        guard parts[1].count == 2, let minute = Int(parts[1]), (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func twentyFour(_ hour: Int, _ meridiem: String) -> Int {
        switch (meridiem, hour) {
        case ("am", 12): 0
        case ("pm", 12): 12
        case ("pm", _): hour + 12
        default: hour
        }
    }

    /// An hour said without am/pm. Turkish writes the 24-hour clock, so "19:30"
    /// never gets here; "8" does, and is read by what is around it.
    ///
    /// A part of day settles it ("akşam 8", "Friday evening at 8"). Otherwise an
    /// evening word anywhere in the line makes it evening ("dinner at 8"); and
    /// with nothing to go on, one to six is afternoon — nobody books the
    /// plumber for four in the morning — while seven to eleven stays morning.
    private func resolveMeridiem(_ hour: Int, part: Int?) -> Int {
        if let part {
            return part >= 12 ? hour + 12 : hour
        }
        let folded = CaptureParser.fold(text)
        let evening = DateWords.eveningHints.contains { folded.contains($0) }
        return evening || hour <= 6 ? hour + 12 : hour
    }

    // MARK: Written dates

    /// "12 Kasım", "Nov 12", "25.10.2026" — via `NSDataDetector`, and only
    /// when what it matched holds a month name or a numeric date. Anything
    /// else it finds is a relative phrase the rules above own and read from
    /// `now` rather than from the device clock.
    private func detectWrittenDate() -> Reading? {
        guard text.contains(where: \.isNumber) else { return nil }
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.date.rawValue
        ) else { return nil }

        let whole = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, options: [], range: whole) {
            guard let date = match.date, let range = Range(match.range, in: text) else { continue }
            guard !blocked.contains(where: { $0.overlaps(range) }) else { continue }

            let phrase = CaptureParser.fold(text[range])
            let words = phrase
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "." && $0 != "/" && $0 != ":" })
                .map(String.init)
            let hasMonth = words.contains { DateWords.months.contains($0) }
            let hasNumericDate = words.contains { word in
                let parts = word.split(whereSeparator: { $0 == "." || $0 == "/" })
                return !word.contains(":")
                    && (2...3).contains(parts.count)
                    && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
            }
            guard hasMonth || hasNumericDate else { continue }

            // Only date words and numbers come out of the title: the detector
            // sometimes takes a neighbouring word along, and that word is the
            // person's, not the date's.
            let inside = tokens.indices.filter { index in
                let token = tokens[index]
                return token.range.overlaps(range)
                    && (token.isNumeric
                        || DateWords.months.contains(token.stem)
                        || DateWords.dayLeads.contains(token.stem)
                        || DateWords.timeLeads.contains(token.stem))
            }
            let hasTime = words.contains { $0.contains(":") }
                || words.contains("am") || words.contains("pm") || words.contains("saat")
            return Reading(
                date: date,
                hasTime: hasTime,
                tokens: inside,
                ranges: inside.map { tokens[$0].range }
            )
        }
        return nil
    }
}

/// The date words, both languages, folded.
enum DateWords {
    /// Single words that name a day relative to today, with a part of day if
    /// they carry one ("tonight").
    static let relativeDays: [String: (offset: Int, partOfDay: Int?)] = [
        "today": (0, nil), "tonight": (0, 19), "tomorrow": (1, nil), "tmrw": (1, nil),
        "bugun": (0, nil), "yarin": (1, nil), "yarina": (1, nil), "yarinki": (1, nil),
    ]

    static let relativePhrases: [(words: [String], offset: Int, partOfDay: Int?)] = [
        (["the", "day", "after", "tomorrow"], 2, nil),
        (["day", "after", "tomorrow"], 2, nil),
        (["yarindan", "sonra"], 2, nil),
        (["obur", "gun"], 2, nil),
        (["obur", "gune"], 2, nil),
        (["this", "morning"], 0, 9),
        (["this", "afternoon"], 0, 15),
        (["this", "evening"], 0, 19),
        (["bu", "sabah"], 0, 9),
        (["bu", "ogleden", "sonra"], 0, 15),
        (["bu", "aksam"], 0, 19),
        (["bu", "gece"], 0, 21),
    ]

    /// Calendar weekday numbers: 1 is Sunday.
    static let englishWeekdays: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
        "thursday": 5, "friday": 6, "saturday": 7,
    ]

    /// Longest first, so a prefix match never stops at "cuma" in "cumartesi".
    static let turkishWeekdays: [(String, Int)] = [
        ("pazartesi", 2), ("cumartesi", 7), ("carsamba", 4), ("persembe", 5),
        ("pazar", 1), ("cuma", 6), ("sali", 3),
    ]

    /// What a Turkish weekday can carry and still be the day: "cumaya",
    /// "salıdan", "pazartesiki".
    static let caseEndings: Set<String> = [
        "", "ya", "ye", "a", "e", "yi", "yu", "da", "de", "ta", "te",
        "dan", "den", "ki", "nin",
    ]

    /// "8'de", "20:00'da": the Turkish "at".
    static let locativeEndings: Set<String> = ["de", "da", "te", "ta"]

    /// "next Friday", "haftaya Cuma": a week further out.
    static let nextWeek: Set<String> = ["next", "haftaya", "gelecek", "onumuzdeki"]
    /// "this Friday", "bu Cuma", "on Friday": no change, but part of the phrase.
    static let weekdayLeads: Set<String> = ["this", "bu", "on", "by", "until", "till"]
    /// Prepositions that belong to the day they introduce.
    static let dayLeads: Set<String> = ["on", "by", "for", "until", "till"]
    /// Words that ride along after a day.
    static let dayTrailers: Set<String> = ["gunu", "gunune", "kadar"]
    /// Words that introduce a clock time.
    static let timeLeads: Set<String> = ["saat", "at", "around", "civari"]
    /// After a part of day, these make it a meal rather than a time.
    static let mealWords: Set<String> = ["yemegi", "yemek", "yemegine", "yemeginde"]

    /// Parts of the day, as the hour they stand for.
    static let partsOfDay: [String: Int] = [
        "morning": 9, "afternoon": 15, "evening": 19, "night": 21, "noon": 12,
        "sabah": 9, "sabahi": 9, "ogle": 12, "oglen": 12, "ogleden": 15,
        "aksam": 19, "aksami": 19, "gece": 21, "gecesi": 21,
    ]

    /// Words that put an unqualified "at 8" in the evening.
    static let eveningHints: [String] = [
        "dinner", "party", "drinks", "tonight", "evening", "night",
        "yemek", "parti", "aksam", "gece",
    ]

    static let months: Set<String> = [
        "january", "february", "march", "april", "may", "june", "july", "august",
        "september", "october", "november", "december",
        "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "sept", "oct", "nov", "dec",
        "ocak", "subat", "mart", "nisan", "mayis", "haziran", "temmuz", "agustos",
        "eylul", "ekim", "kasim", "aralik",
    ]
}

// MARK: - Amounts

/// Reads "₺300", "300 TL", "$20", "15€", "12,50 lira" — and, only after a
/// paying word, a bare "300".
enum AmountReader {
    struct Reading {
        var amount: CaptureAmount
        var range: Range<String.Index>
    }

    /// The first amount with its currency written next to it.
    static func explicit(_ text: String, fallbackCurrency: String) -> Reading? {
        var best: (range: Range<String.Index>, number: Substring, currency: String)?
        func consider(_ range: Range<String.Index>, _ number: Substring, _ currency: String?) {
            guard let currency else { return }
            if let current = best, current.range.lowerBound <= range.lowerBound { return }
            best = (range, number, currency)
        }

        for match in text.matches(of: #/([₺$€£])\s?(\d[\d.,]*)/#) {
            consider(match.range, match.output.2, symbols[match.output.1.first ?? " "])
        }
        for match in text.matches(of: #/(\d[\d.,]*)\s?([₺$€£])/#) {
            consider(match.range, match.output.1, symbols[match.output.2.first ?? " "])
        }
        for match in text.matches(of: #/(\d[\d.,]*)\s?([A-Za-z]+)/#) {
            consider(match.range, match.output.1, words[match.output.2.lowercased()])
        }

        guard let best else { return nil }
        return reading(
            withEnding(best.range, in: text),
            best.number,
            currency: best.currency,
            fallbackCurrency: fallbackCurrency
        )
    }

    /// "300 TL'yi", "50₺'ye": the case ending belongs to the amount, and left
    /// behind it would open the title with a stray "'yi".
    private static func withEnding(_ range: Range<String.Index>, in text: String) -> Range<String.Index> {
        var end = range.upperBound
        guard end < text.endIndex, text[end] == "'" || text[end] == "’" else { return range }
        var cursor = text.index(after: end)
        while cursor < text.endIndex, text[cursor].isLetter {
            cursor = text.index(after: cursor)
            end = cursor
        }
        return range.lowerBound..<end
    }

    /// The first plain number outside the date phrase — "Ali paid 300". Only
    /// asked for when a paying word is present.
    static func bare(
        _ text: String,
        excluding dateRanges: [Range<String.Index>],
        fallbackCurrency: String
    ) -> Reading? {
        for match in text.matches(of: #/\d[\d.,]*/#) {
            guard !dateRanges.contains(where: { $0.overlaps(match.range) }) else { continue }
            // A number glued to letters ("2x", "3rd") is not money.
            if match.range.upperBound < text.endIndex, text[match.range.upperBound].isLetter { continue }
            if let reading = reading(match.range, match.output, currency: nil, fallbackCurrency: fallbackCurrency) {
                return reading
            }
        }
        return nil
    }

    private static func reading(
        _ range: Range<String.Index>,
        _ digits: Substring,
        currency: String?,
        fallbackCurrency: String
    ) -> Reading? {
        guard let value = number(digits) else { return nil }
        let minor = Money.minorUnits(value, currency: currency ?? fallbackCurrency)
        guard minor > 0 else { return nil }
        return Reading(amount: CaptureAmount(minorUnits: minor, currency: currency), range: range)
    }

    private static let symbols: [Character: String] = ["₺": "TRY", "$": "USD", "€": "EUR", "£": "GBP"]

    /// Currency words, as written after the number. No "pound": "2 pounds of
    /// potatoes" is shopping, not sterling.
    private static let words: [String: String] = [
        "tl": "TRY", "try": "TRY", "lira": "TRY", "liras": "TRY",
        "usd": "USD", "dollar": "USD", "dollars": "USD", "dolar": "USD", "bucks": "USD",
        "eur": "EUR", "euro": "EUR", "euros": "EUR", "avro": "EUR",
        "gbp": "GBP", "sterlin": "GBP",
    ]

    /// A typed number, whichever separators the keyboard gave.
    ///
    /// Both kinds present: the last one is the decimal point ("1.250,50",
    /// "1,250.50"). One kind, repeated: grouping ("1.250.000"). One kind, once,
    /// with exactly three digits after it: grouping too — "1.250 TL" is twelve
    /// hundred and fifty lira, and nobody prices a thing to a tenth of a kuruş.
    /// Otherwise it is the decimal point ("12,50", "12.5"). `Money.parse` takes
    /// the last separator as the point unconditionally, which is right for a
    /// number pad — nobody types grouping there — and wrong for a sentence.
    static func number(_ raw: Substring) -> Decimal? {
        var text = String(raw)
        while let last = text.last, last == "." || last == "," { text.removeLast() }
        let posix = Locale(identifier: "en_US_POSIX")
        let separators = text.filter { $0 == "." || $0 == "," }
        guard !separators.isEmpty else { return Decimal(string: text, locale: posix) }

        if Set(separators).count == 2, let last = text.lastIndex(where: { $0 == "." || $0 == "," }) {
            let whole = text[..<last].filter(\.isNumber)
            let fraction = text[text.index(after: last)...].filter(\.isNumber)
            return Decimal(string: "\(whole).\(fraction)", locale: posix)
        }
        if separators.count > 1 {
            return Decimal(string: text.filter(\.isNumber), locale: posix)
        }
        let parts = text.split(whereSeparator: { $0 == "." || $0 == "," })
        guard parts.count == 2 else { return Decimal(string: text.filter(\.isNumber), locale: posix) }
        if parts[1].count == 3, parts[0] != "0" {
            return Decimal(string: "\(parts[0])\(parts[1])", locale: posix)
        }
        return Decimal(string: "\(parts[0]).\(parts[1])", locale: posix)
    }
}

// MARK: - Keywords

/// Every word the rules listen for, in one place, so teaching the parser a new
/// one is a one-line change.
///
/// All folded (lowercase, Turkish letters flattened): "çıkar" is written
/// "cikar", "ödedi" is "odedi". Three shapes:
/// - `phrases`: several words in a row, checked first and claimed, so "toz al"
///   (dust) never also counts as "al" (buy).
/// - `words`: a whole word.
/// - `stems`: the start of a word, for Turkish, which builds "temizle",
///   "temizlenecek", "temizlensin" on one root. Four letters at least — a
///   shorter stem matches half the dictionary.
enum Vocabulary {
    enum Role: Equatable {
        /// Says what kind of thing this is.
        case signal
        /// Leans that way without settling it — "get", "need", "market".
        case lean
        /// Carries a detail but no vote: a money word ("bill", "kira") that
        /// only counts alongside an amount, or a room ("banyo") that says
        /// where a problem is without saying there is one.
        case hint
    }

    struct Entry {
        let kind: CaptureKind
        let role: Role
        var eventKind: EventKind? = nil
        var issueArea: IssueArea? = nil
    }

    struct Hit {
        let kind: CaptureKind?
        let role: Role
        let tokens: Range<Int>
        let eventKind: EventKind?
        let issueArea: IssueArea?
    }

    static let notePrefixes = ["note:", "note -", "not:", "not -", "nb:"]

    /// What a shopping line may start with — taken off the items.
    static let shoppingLeads: [[String]] = [
        ["we", "need"], ["we're", "out", "of"], ["were", "out", "of"], ["out", "of"],
        ["ran", "out", "of"], ["pick", "up"], ["to", "buy"], ["buy"], ["get"], ["grab"],
        ["need"], ["shopping"], ["market"], ["alisveris"],
    ]

    /// What a Turkish shopping line may end with — taken off the items.
    static let shoppingTails: [[String]] = [
        ["almak", "lazim"], ["almayi", "unutma"], ["alinmasi", "lazim"],
        ["al"], ["alin"], ["alinsin"], ["alalim"], ["alinacak"], ["lazim"], ["gerek"],
        ["bitti"], ["bitmis"], ["kalmadi"], ["almak"],
    ]

    /// Left over at the end of a title once its date or amount is cut out.
    ///
    /// English prepositions and "saat" only. "bu", "haftaya" and "gelecek"
    /// are taken with the weekday they qualify, and "gelecek" on its own is a
    /// verb — "tesisatçı gelecek", the plumber is coming — that has to stay.
    static let danglers: Set<String> = [
        "at", "on", "by", "for", "from", "until", "till", "around", "saat",
    ]
    static let leadingDanglers: Set<String> = ["on", "at", "by", "saat"]

    /// Longest first when matched (see `hits`), so "out of order" is a
    /// problem before "out of" can make it shopping.
    static let phrases: [([String], Entry)] = [
        // Chores that would otherwise read as something else.
        (["toz", "al"], Entry(kind: .chore, role: .signal)),
        (["take", "out"], Entry(kind: .chore, role: .signal)),
        (["water", "the", "plants"], Entry(kind: .chore, role: .signal)),
        (["water", "plants"], Entry(kind: .chore, role: .signal)),
        (["make", "the", "bed"], Entry(kind: .chore, role: .signal)),
        (["walk", "the", "dog"], Entry(kind: .chore, role: .signal)),
        (["feed", "the", "cat"], Entry(kind: .chore, role: .signal)),
        (["cicekleri", "sula"], Entry(kind: .chore, role: .signal)),
        // Shopping.
        (["we", "need"], Entry(kind: .shopping, role: .signal)),
        (["out", "of"], Entry(kind: .shopping, role: .signal)),
        (["run", "out"], Entry(kind: .shopping, role: .signal)),
        (["ran", "out"], Entry(kind: .shopping, role: .signal)),
        (["pick", "up"], Entry(kind: .shopping, role: .signal)),
        (["almak", "lazim"], Entry(kind: .shopping, role: .signal)),
        // Problems.
        (["not", "working"], Entry(kind: .problem, role: .signal)),
        (["doesn't", "work"], Entry(kind: .problem, role: .signal)),
        (["doesnt", "work"], Entry(kind: .problem, role: .signal)),
        (["stopped", "working"], Entry(kind: .problem, role: .signal)),
        (["out", "of", "order"], Entry(kind: .problem, role: .signal)),
        (["no", "hot", "water"], Entry(kind: .problem, role: .signal, issueArea: .bathroom)),
        (["sicak", "su", "yok"], Entry(kind: .problem, role: .signal, issueArea: .bathroom)),
        // Expenses.
        (["paid", "for"], Entry(kind: .expense, role: .signal)),
        // Events.
        (["coming", "over"], Entry(kind: .event, role: .signal, eventKind: .visit)),
        (["movie", "night"], Entry(kind: .event, role: .signal, eventKind: .movieNight)),
        (["film", "gecesi"], Entry(kind: .event, role: .signal, eventKind: .movieNight)),
        (["game", "night"], Entry(kind: .event, role: .signal, eventKind: .gameNight)),
        (["oyun", "gecesi"], Entry(kind: .event, role: .signal, eventKind: .gameNight)),
        (["dogum", "gunu"], Entry(kind: .event, role: .signal, eventKind: .birthday)),
        (["aksam", "yemegi"], Entry(kind: .event, role: .signal, eventKind: .dinnerParty)),
        // Notes.
        (["door", "code"], Entry(kind: .note, role: .signal)),
        (["wi", "fi"], Entry(kind: .note, role: .signal)),
        // Rooms, for a problem's area. Kind-less: they say where, not what.
        (["living", "room"], Entry(kind: .problem, role: .hint, issueArea: .living)),
        (["yatak", "odasi"], Entry(kind: .problem, role: .hint, issueArea: .bedroom)),
        (["oturma", "odasi"], Entry(kind: .problem, role: .hint, issueArea: .living)),
        (["washing", "machine"], Entry(kind: .problem, role: .hint, issueArea: .laundry)),
        // "bulaşık makinesi" is the dishwasher, not the dishes: a machine is
        // where a problem happens, never a chore.
        (["bulasik", "makinesi"], Entry(kind: .problem, role: .hint, issueArea: .kitchen)),
        (["camasir", "makinesi"], Entry(kind: .problem, role: .hint, issueArea: .laundry)),
    ]

    static let words: [String: Entry] = {
        var table: [String: Entry] = [:]
        func add(_ kind: CaptureKind, _ role: Role, _ list: [String]) {
            for word in list { table[word] = Entry(kind: kind, role: role) }
        }
        add(.shopping, .signal, [
            "buy", "groceries", "grocery",
            "al", "alin", "alinsin", "alalim", "alinacak", "almak", "lazim",
            "bitti", "bitmis", "kalmadi", "alisveris",
        ])
        add(.shopping, .lean, ["get", "grab", "need", "gerek", "market"])

        add(.chore, .signal, [
            "clean", "tidy", "vacuum", "hoover", "mop", "sweep", "dust", "wash",
            "iron", "laundry", "dishes", "bins", "bin", "trash", "rubbish",
            "garbage", "recycling", "empty", "declutter", "cook", "fold",
            "sil", "silin", "cop", "copu", "copleri", "copler", "utu", "topla",
            "toplayin", "toplanacak", "toplansin", "sula", "bulasik", "bulasiklari",
        ])
        add(.chore, .lean, [
            "dishwasher", "organise", "organize", "degistir", "duzenle",
            // "pay the rent", "faturayı öde": something to do. "paid" and
            // "ödedi" — something done — are the expense words.
            "pay", "ode", "odeyin", "odensin",
        ])

        add(.problem, .signal, [
            "fix", "fixed", "broken", "broke", "leak", "leaks", "leaking", "leaky",
            "repair", "repaired", "clogged", "blocked", "dripping", "drips",
            "cracked", "crack", "mould", "mold", "damp", "faulty", "flickering",
            "bozuk", "bozuldu", "bozulmus", "akiyor", "kirik", "kirildi", "tikali",
            "tikandi", "kuf", "rutubet", "patladi", "yanmiyor", "acilmiyor",
            "kapanmiyor", "calismiyor", "siziyor",
        ])

        add(.expense, .signal, ["paid", "spent", "payed"])
        add(.expense, .hint, [
            "bill", "invoice", "receipt", "rent", "fatura", "faturasi", "faturayi",
            "kira", "kirasi", "kirayi", "dekont", "hesap", "hesabi",
        ])

        add(.note, .signal, ["password", "passcode", "wifi", "sifre", "sifresi", "kod", "kodu"])
        add(.note, .lean, ["code", "pin", "note", "remember"])

        add(.event, .signal, [
            "party", "dinner", "lunch", "brunch", "bbq", "barbecue", "birthday",
            "drinks", "picnic", "wedding", "guests", "visit", "visiting",
            "meeting", "appointment", "concert", "cinema",
            "yemek", "yemege", "yemekte", "yemegi", "mangal", "piknik", "dugun",
            "konser", "sinema", "randevu", "toplanti",
        ])
        add(.event, .lean, [
            "gelecek", "geliyor", "gelecekler", "geliyorlar", "meet", "movie", "film",
        ])

        // Event kinds, for the composer.
        for (word, kind) in [
            ("party", EventKind.houseParty), ("parti", .houseParty), ("dinner", .dinnerParty),
            ("yemek", .dinnerParty), ("yemege", .dinnerParty), ("yemegi", .dinnerParty),
            ("yemekte", .dinnerParty), ("lunch", .dinnerParty), ("brunch", .dinnerParty),
            ("bbq", .houseParty), ("barbecue", .houseParty), ("mangal", .houseParty),
            ("birthday", .birthday), ("guests", .visit), ("visit", .visit),
            ("visiting", .visit), ("misafir", .visit), ("appointment", .appointment),
            ("randevu", .appointment), ("meeting", .appointment), ("toplanti", .appointment),
            ("picnic", .picnic), ("piknik", .picnic), ("concert", .concert), ("konser", .concert),
            ("cinema", .cinema), ("sinema", .cinema),
        ] {
            table[word] = Entry(kind: .event, role: table[word]?.role ?? .signal, eventKind: kind)
        }

        // Rooms, for a problem's area.
        for (word, area) in [
            ("kitchen", IssueArea.kitchen), ("mutfak", .kitchen), ("mutfakta", .kitchen),
            ("bathroom", .bathroom), ("toilet", .bathroom), ("shower", .bathroom),
            ("bath", .bathroom), ("banyo", .bathroom), ("banyoda", .bathroom),
            ("tuvalet", .bathroom), ("dus", .bathroom), ("bedroom", .bedroom),
            ("lounge", .living), ("salon", .living), ("salonda", .living),
            ("hallway", .hallway), ("hall", .hallway), ("corridor", .hallway),
            ("koridor", .hallway), ("garage", .garage), ("garaj", .garage),
            ("garden", .garden), ("yard", .garden), ("bahce", .garden), ("bahcede", .garden),
            ("balcony", .balcony), ("balkon", .balcony), ("balkonda", .balcony),
            ("basement", .basement), ("cellar", .basement), ("bodrum", .basement),
            ("roof", .roof), ("cati", .roof), ("catida", .roof),
        ] where table[word] == nil {
            table[word] = Entry(kind: .problem, role: .hint, issueArea: area)
        }
        return table
    }()

    static let stems: [(String, Entry)] = [
        ("temizl", Entry(kind: .chore, role: .signal)),
        ("supur", Entry(kind: .chore, role: .signal)),
        ("yika", Entry(kind: .chore, role: .signal)),
        ("cikar", Entry(kind: .chore, role: .signal)),
        ("utule", Entry(kind: .chore, role: .signal)),
        ("bosalt", Entry(kind: .chore, role: .signal)),
        ("katla", Entry(kind: .chore, role: .signal)),
        ("camasir", Entry(kind: .chore, role: .signal)),
        ("bulasik", Entry(kind: .chore, role: .signal)),
        ("pisir", Entry(kind: .chore, role: .signal)),

        ("tamir", Entry(kind: .problem, role: .signal)),
        ("sizint", Entry(kind: .problem, role: .signal)),
        ("sizdir", Entry(kind: .problem, role: .signal)),
        ("ariza", Entry(kind: .problem, role: .signal)),
        ("damli", Entry(kind: .problem, role: .signal)),
        ("tikan", Entry(kind: .problem, role: .signal)),
        ("kufl", Entry(kind: .problem, role: .signal)),
        ("calismi", Entry(kind: .problem, role: .signal)),

        ("oded", Entry(kind: .expense, role: .signal)),
        ("odendi", Entry(kind: .expense, role: .signal)),
        ("harcad", Entry(kind: .expense, role: .signal)),
        ("harcam", Entry(kind: .expense, role: .signal)),

        ("sifre", Entry(kind: .note, role: .signal)),

        ("parti", Entry(kind: .event, role: .signal, eventKind: .houseParty)),
        ("kahvalti", Entry(kind: .event, role: .signal, eventKind: .dinnerParty)),
        ("misafir", Entry(kind: .event, role: .signal, eventKind: .visit)),
        ("ziyaret", Entry(kind: .event, role: .signal, eventKind: .visit)),
        ("kutla", Entry(kind: .event, role: .signal)),
        ("bulus", Entry(kind: .event, role: .signal)),
        ("toplanti", Entry(kind: .event, role: .signal, eventKind: .appointment)),
        ("randevu", Entry(kind: .event, role: .signal, eventKind: .appointment)),
        ("dogumgun", Entry(kind: .event, role: .signal, eventKind: .birthday)),
    ]

    private static let phrasesLongestFirst = phrases.sorted { $0.0.count > $1.0.count }

    /// Every keyword in `tokens`, phrases first, each token claimed at most once.
    static func hits(in tokens: [Token]) -> [Hit] {
        var hits: [Hit] = []
        var claimed: Set<Int> = []

        for index in tokens.indices {
            for (phrase, entry) in phrasesLongestFirst where index + phrase.count <= tokens.count {
                let span = index..<(index + phrase.count)
                guard !span.contains(where: claimed.contains) else { continue }
                guard zip(phrase, tokens[span]).allSatisfy({ $0 == $1.word || $0 == $1.stem }) else { continue }
                hits.append(Hit(entry, span))
                claimed.formUnion(span)
            }
        }
        for (index, token) in tokens.enumerated() where !claimed.contains(index) {
            if let entry = words[token.word] ?? words[token.stem] {
                hits.append(Hit(entry, index..<(index + 1)))
                continue
            }
            guard token.stem.count >= 4 else { continue }
            if let match = stems.first(where: { token.stem.hasPrefix($0.0) }) {
                hits.append(Hit(match.1, index..<(index + 1)))
            }
        }
        return hits
    }
}

extension Vocabulary.Hit {
    init(_ entry: Vocabulary.Entry, _ tokens: Range<Int>) {
        // A room says where a problem is, not that there is one: it carries
        // the area and no vote.
        kind = entry.role == .hint && entry.kind == .problem ? nil : entry.kind
        role = entry.role
        self.tokens = tokens
        eventKind = entry.eventKind
        issueArea = entry.issueArea
    }
}

// MARK: - Scoring

/// Turns the hits into one kind and a confidence.
///
/// Points rather than a decision tree, so a line that says two things — "buy a
/// cake for Ayşe's birthday Saturday" — is settled by weight and comes out
/// *weak*, which is when the chip is worth a second look, rather than by
/// whichever rule happened to be checked first.
struct Scorer {
    let tokens: [Token]
    let hits: [Vocabulary.Hit]
    let isNotePrefixed: Bool
    let hasDate: Bool
    let amount: CaptureAmount?
    let items: [String]

    /// Strong needs this much, and this much of a lead over the runner-up.
    static let strongScore = 5
    static let strongLead = 2

    func verdict() -> (kind: CaptureKind?, confidence: CaptureConfidence) {
        if isNotePrefixed { return (.note, .strong) }

        var score: [CaptureKind: Int] = [:]
        for kind in CaptureKind.allCases {
            score[kind] = keywordScore(kind)
        }

        // Money: a paying word with an amount settles it; either alone leans.
        let paid = hits.contains { $0.kind == .expense && $0.role == .signal }
        let billish = hits.contains { $0.kind == .expense && $0.role == .hint }
        switch (paid, amount) {
        case (true, .some): score[.expense] = 7 + (billish ? 1 : 0)
        case (true, .none): score[.expense] = 3
        case (false, .some(let amount)) where amount.currency != nil: score[.expense] = billish ? 5 : 3
        default: score[.expense] = 0
        }

        // A plan needs a when: "dinner" alone might be tonight's cooking.
        if let event = score[.event], event > 0 {
            score[.event] = hasDate ? event + 2 : min(event, 3)
        }

        let anyOther = CaptureKind.allCases.contains { $0 != .shopping && score[$0, default: 0] > 0 }

        // "süt, yumurta, ekmek": a list of short things, and nothing else said.
        if !anyOther, items.count >= 2, items.allSatisfy({ $0.split(separator: " ").count <= 4 }) {
            score[.shopping] = max(score[.shopping, default: 0], Self.strongScore) + 1
        }

        // A bare date with nothing else: something to do, probably.
        if hasDate, score.values.allSatisfy({ $0 == 0 }) {
            score[.chore] = 2
        }

        // A word or two, no date, no money, no keyword: most likely a thing
        // to buy, but only just.
        if score.values.allSatisfy({ $0 == 0 }), !hasDate, amount == nil, tokens.count <= 3 {
            score[.shopping] = 1
        }

        let ranked = CaptureKind.allCases
            .map { (kind: $0, score: score[$0, default: 0]) }
            .sorted { lhs, rhs in
                lhs.score != rhs.score
                    ? lhs.score > rhs.score
                    : Self.tieBreak.firstIndex(of: lhs.kind)! < Self.tieBreak.firstIndex(of: rhs.kind)!
            }
        guard let top = ranked.first, top.score > 0 else { return (nil, .none) }
        let runnerUp = ranked.dropFirst().first?.score ?? 0
        let strong = top.score >= Self.strongScore && top.score - runnerUp >= Self.strongLead
        return (top.kind, strong ? .strong : .weak)
    }

    /// When two kinds score the same, the rarer, more specific one wins: a
    /// line that mentions a leak and a chore is about the leak.
    static let tieBreak: [CaptureKind] = [.note, .expense, .problem, .event, .chore, .shopping]

    /// Five for a signal word, three for a lean; one more for each further
    /// signal (two at most); and two more when the signal opens or closes the
    /// line, which is where an instruction sits — "buy milk", "süt al".
    private func keywordScore(_ kind: CaptureKind) -> Int {
        let mine = hits.filter { $0.kind == kind && $0.role != .hint }
        guard !mine.isEmpty else { return 0 }
        let signals = mine.filter { $0.role == .signal }
        var score = signals.isEmpty ? 3 : 5
        score += min(2, max(0, signals.count - 1))
        if [.shopping, .chore, .problem].contains(kind), let last = tokens.indices.last,
           signals.contains(where: { $0.tokens.lowerBound == 0 || $0.tokens.upperBound - 1 == last }) {
            score += 2
        }
        return score
    }
}
