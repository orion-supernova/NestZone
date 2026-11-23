import Foundation

/// The changelog, shelved by version.
///
/// The feed grows by a handful of entries every release, and one long column
/// of cards is how it became a scroll. A version is the unit people think in
/// ("what came in 1.12?"), so each is one shelf: open for the newest and for
/// anything this build is still waiting for, one quiet row for the rest.
public struct UpdateGroup: Identifiable, Equatable, Sendable {
    public let id: String
    /// As the server wrote it; `nil` for notes tied to no version.
    public let version: String?
    /// Server order within the version, with the small-fixes entry last.
    public let entries: [AppUpdate]
    public let isComingSoon: Bool
    /// "Nestie, NestZone Plus, chat" — the short names of its entries.
    public let summary: String

    /// "1.12" for 1.12.0, "1.9.1" as it is: a zero patch is noise on a row
    /// that is read as a heading.
    public var displayVersion: String? {
        guard let version, !version.isEmpty else { return nil }
        let parts = version.split(separator: ".")
        if parts.count == 3, parts[2] == "0" { return parts.prefix(2).joined(separator: ".") }
        return version
    }

    /// The newest entry's date, for the quiet line under an open version.
    public var date: Timestamp { entries.map(\.displayDate).max() ?? entries[0].displayDate }

    init(version: String?, entries: [AppUpdate]) {
        let ordered = entries.filter { !$0.isCompact } + entries.filter(\.isCompact)
        self.id = version ?? "none"
        self.version = version
        self.entries = ordered
        self.isComingSoon = ordered.first?.isComingSoon ?? false
        let named = ordered.filter { !$0.isCompact }
        self.summary = (named.isEmpty ? ordered : named)
            .map { $0.text().title.shortName }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Pinned entries stay on top as cards of their own; the rest go to their
    /// versions, newest version first, and the ones with no version last.
    static func shelve(_ updates: [AppUpdate]) -> (pinned: [AppUpdate], groups: [UpdateGroup]) {
        let pinned = updates.filter(\.isPinned)
        let rest = updates.filter { !$0.isPinned }
        var order: [String?] = []
        var byVersion: [String?: [AppUpdate]] = [:]
        for update in rest {
            let key = (update.version?.isEmpty == false) ? update.version : nil
            if byVersion[key] == nil { order.append(key) }
            byVersion[key, default: []].append(update)
        }
        let groups = order
            .sorted { lhs, rhs in
                switch (lhs, rhs) {
                case let (l?, r?): AppVersion(l) > AppVersion(r)
                case (_?, nil): true
                default: false
                }
            }
            .map { UpdateGroup(version: $0, entries: byVersion[$0] ?? []) }
        return (pinned, groups)
    }
}

extension AppUpdate {
    /// Small fixes and improvements read as a list, not as a card: they have
    /// no story to tell, only lines.
    public var isCompact: Bool { kind == .fix || kind == .improvement }
}

private extension String {
    /// "Meet Nestie, your house's plant or pet" -> "Meet Nestie";
    /// "NestZone Plus: one subscription…" -> "NestZone Plus".
    var shortName: String {
        let cut = self.firstIndex(where: { $0 == ":" || $0 == "," }) ?? endIndex
        return String(self[..<cut]).trimmingCharacters(in: .whitespaces)
    }
}
