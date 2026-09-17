import Observation
import SwiftUI

/// What everybody in the household looks like, keyed by user id.
///
/// `Avatar` is drawn in fourteen places across eight features, and only one of
/// them — the Settings profile row — holds a whole `User`. The rest have a
/// member row from `stats:contributions`, or a payer from `finance:summary`, or
/// a comment author from `issues:detail`: a name, an id, and nothing else.
/// Getting a photo onto those screens by threading it through would mean a new
/// field on eight member models and a `storage.getUrl` in eight queries, and
/// the next feature would have to remember to do it a ninth time.
///
/// So the photo is looked up instead of passed. Every one of those call sites
/// already hands `Avatar` the user's id as its colour seed — it has to, or the
/// member's tint would not match their slice of the contributions ring — and an
/// id is the whole key. `Avatar` resolves it here, and a screen that knew
/// nothing about avatars yesterday draws them today without being edited.
///
/// This is a mirror of what the server said and nothing else. It is filled from
/// the reads the app was doing anyway — `users:me`, `homes:members`,
/// `users:byIds`, all of which now resolve the URL alongside the document — so
/// there is no path by which a user document arrives and the directory misses
/// it, and no request made on its behalf. It holds no optimistic state: a write
/// in flight is the reducer's business, and putting it here would make an
/// unconfirmed photo everybody else's business too.
@MainActor
@Observable
public final class AvatarDirectory {
    public static let shared = AvatarDirectory()

    /// Raw user id → how to draw them.
    private var entries: [String: AvatarEntry] = [:]

    init() {}

    /// The photo for a user id, or `nil` if they have none.
    public func url(for seed: String) -> URL? { entries[seed]?.photo }

    /// What to call them — for a photo's title, and for VoiceOver.
    public func name(for seed: String) -> String? { entries[seed]?.name }

    public func entry(for seed: String) -> AvatarEntry? { entries[seed] }

    /// Records what the server last said about these people.
    ///
    /// Removal is as much a fact as arrival: a user whose `avatarURL` is `nil`
    /// has their photo cleared, so taking it off puts the initials back
    /// everywhere rather than leaving a stale face behind on every other
    /// screen. The *entry* stays, because the name is still true.
    public func record(_ users: [User]) {
        var updated = entries
        for user in users {
            updated[user.id.rawValue] = AvatarEntry(
                name: user.displayName,
                photo: user.avatarURL
            )
        }
        // Convex re-publishes every live query in the app on any query-set
        // change, so this runs on screens that merely swapped a subscription,
        // with the same people each time. Writing an identical dictionary into
        // an observed property would invalidate every avatar on screen for no
        // visible change.
        guard updated != entries else { return }
        entries = updated
    }

    public func record(_ user: User?) {
        guard let user else { return }
        record([user])
    }

    /// Forgets everybody. Called when a session ends.
    ///
    /// One household's faces are one household's data, on the same terms as the
    /// cached home list: a session that has ended must not leave them on the
    /// device for whoever signs in next.
    public func clear() {
        guard !entries.isEmpty else { return }
        entries = [:]
    }
}

extension AvatarDirectory {
    /// Records from off the main actor, which is where every Convex stream
    /// delivers.
    ///
    /// Ordering between two of these is not worth defending. They carry the
    /// same field from the same table, read by queries the server keeps
    /// consistent with each other, so the worst a reordering can do is settle
    /// on a value that another push is about to confirm.
    public nonisolated static func record(_ users: [User]) {
        Task { @MainActor in shared.record(users) }
    }

    public nonisolated static func record(_ user: User?) {
        guard let user else { return }
        record([user])
    }
}
