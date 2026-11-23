import Foundation

/// The holidays screen's data, worked out once: each day's next date, its
/// relative wording and what a search can match, in the order the screen draws
/// them. Building it runs every calendar rule (Hebrew, Islamic, Chinese…), so
/// the view keeps one and rebuilds it only when the day, the region or the
/// language moves — never per row, never in a `body`.
struct HolidayBoard: Equatable {
    struct Entry: Identifiable, Equatable {
        let holiday: Holiday
        let title: String
        let familyTitle: String
        /// The title, the family and the id in this language and in English,
        /// folded, so "muslim", "ramazan" and "diwali" all find their day.
        let searchKey: String
        let underway: Bool
        /// Whole days from today to the next first day; nil when no year in
        /// reach has one.
        let days: Int?
        /// "Thu, 27 Nov", empty when there is no next date.
        let dateText: String
        /// "in 6 days", "tomorrow".
        let relative: String
        /// The same, for the start of a line: "Tomorrow".
        let relativeCapitalized: String

        var id: Holiday.ID { holiday.id }
    }

    struct Key: Hashable {
        let day: Date
        let region: String?
        let language: String
    }

    let key: Key
    /// Every holiday, family by family, each family soonest first.
    let entries: [Entry]

    func entries(in family: Holiday.Family) -> [Entry] {
        entries.filter { $0.holiday.family == family }
    }

    /// The soonest of `ids`: the ones under way, then the next to come.
    func upcoming(among ids: Set<Holiday.ID>, limit: Int) -> [Entry] {
        entries
            .filter { ids.contains($0.id) && $0.days != nil }
            .sorted { $0.sortDays < $1.sortDays }
            .prefix(limit)
            .map { $0 }
    }

    static func key(clock: Date, region: String?, calendar: Calendar = .current) -> Key {
        Key(day: calendar.startOfDay(for: clock), region: region, language: L10n.locale.identifier)
    }

    static func make(clock: Date, region: String?, calendar: Calendar = .current) -> HolidayBoard {
        let locale = L10n.locale
        let today = calendar.startOfDay(for: clock)
        let dateStyle = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated).locale(locale)
        let relative = RelativeDateTimeFormatter()
        relative.locale = locale
        relative.dateTimeStyle = .named
        relative.unitsStyle = .full
        relative.formattingContext = .middleOfSentence
        let relativeStart = RelativeDateTimeFormatter()
        relativeStart.locale = locale
        relativeStart.dateTimeStyle = .named
        relativeStart.unitsStyle = .full
        relativeStart.formattingContext = .beginningOfSentence

        let fold = HolidayBoard.fold
        func english(_ resource: LocalizedStringResource) -> String {
            var copy = resource
            copy.locale = Locale(identifier: "en")
            return String(localized: copy)
        }

        var built: [Entry] = []
        for family in Holiday.Family.allCases {
            let familyTitle = String(localized: family.title)
            let familyEnglish = english(family.title)
            var group: [Entry] = []
            for holiday in Holiday.all where holiday.family == family {
                let title = String(localized: holiday.id.title)
                let underway = holiday.isUnderway(on: clock, region: region, calendar: calendar)
                let next = holiday.next(after: clock, region: region, calendar: calendar)
                let days = next.flatMap { calendar.dateComponents([.day], from: today, to: $0).day }
                let components = days.map { DateComponents(day: $0) }
                group.append(Entry(
                    holiday: holiday,
                    title: title,
                    familyTitle: familyTitle,
                    searchKey: fold([title, english(holiday.id.title), familyTitle, familyEnglish, holiday.id.rawValue].joined(separator: " ")),
                    underway: underway,
                    days: days,
                    dateText: next.map { $0.formatted(dateStyle) } ?? "",
                    relative: components.map { relative.localizedString(from: $0) } ?? "",
                    relativeCapitalized: components.map { relativeStart.localizedString(from: $0) } ?? ""
                ))
            }
            built += group.sorted { $0.sortDays < $1.sortDays }
        }
        return HolidayBoard(key: key(clock: clock, region: region, calendar: calendar), entries: built)
    }

    /// Case- and accent-insensitive: "ramazan", "Ramazan", "diwali".
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: L10n.locale)
    }
}

extension HolidayBoard.Entry {
    /// Under way first, then by how soon; days with no date last.
    var sortDays: Int { underway ? -1 : (days ?? Int.max) }
}
