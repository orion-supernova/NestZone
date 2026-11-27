import Foundation

/// What a tapped notification was about, read off its payload.
///
/// The server sends the bell's `category` on every push, the `home` it belongs
/// to, and for some a `link` naming the one thing: `event:<id>:<startMs>` (or
/// `event:<id>`), `issue:<id>`, `conversation:<id>`, `recipe:<id>`. A push from
/// before links existed has only the category, which is still enough to open
/// the right module, so every part but the category is optional.
public struct PushTap: Equatable, Sendable {
    public enum Link: Equatable, Sendable {
        /// `startMs` is the occurrence of a repeating series; without it only
        /// the event is known.
        case event(EventID, startMs: Int64?)
        case issue(IssueID)
        case conversation(ConversationID)
        case recipe(RecipeID)
    }

    public var category: ActivityCategory
    public var home: HomeID?
    public var link: Link?

    public init(category: ActivityCategory, home: HomeID? = nil, link: Link? = nil) {
        self.category = category
        self.home = home
        self.link = link
    }

    /// Nil for a notification that is not ours to route (the cooking timer is
    /// local and carries nothing).
    public init?(userInfo: [AnyHashable: Any]) {
        let category = (userInfo["category"] as? String).flatMap(ActivityCategory.init(rawValue:))
        let link = (userInfo["link"] as? String).flatMap(Self.parse)
        let home = (userInfo["home"] as? String).flatMap { $0.isEmpty ? nil : HomeID(rawValue: $0) }
        guard category != nil || link != nil else { return nil }
        self.init(category: category ?? link?.category ?? .other, home: home, link: link)
    }

    static func parse(_ raw: String) -> Link? {
        let parts = raw.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, !parts[1].isEmpty else { return nil }
        switch parts[0] {
        case "event":
            let ms = parts.count > 2 ? Int64(parts[2]) : nil
            return .event(EventID(rawValue: parts[1]), startMs: ms)
        case "issue": return .issue(IssueID(rawValue: parts[1]))
        case "conversation": return .conversation(ConversationID(rawValue: parts[1]))
        case "recipe": return .recipe(RecipeID(rawValue: parts[1]))
        default: return nil
        }
    }
}

extension PushTap.Link {
    /// Where the same tap goes when the one thing cannot be opened.
    var category: ActivityCategory {
        switch self {
        case .event: .calendar
        case .issue: .issues
        case .conversation: .messages
        case .recipe: .recipes
        }
    }
}

/// Effect ids for a tap in flight, shared by the root and the tabs so a
/// sign-out cancels both and the latest tap wins.
enum PushTapCancel { case delivery, routing, deadline }

/// Hands a tap from `UNUserNotificationCenterDelegate` to the root reducer.
///
/// A tap that launches the app arrives before anything is listening, so it is
/// kept until a listener asks and then delivered once, and cleared: replaying
/// it to a later subscriber would open the same screen again. (The token
/// broker replays because a token is state; a tap is an event.)
public final class PushTapBroker: @unchecked Sendable {
    public static let shared = PushTapBroker()

    private let lock = NSLock()
    private var pending: [PushTap] = []
    private var continuations: [UUID: AsyncStream<PushTap>.Continuation] = [:]

    public func received(_ tap: PushTap) {
        lock.withLock {
            if let continuation = continuations.values.first {
                continuation.yield(tap)
            } else {
                pending.append(tap)
            }
        }
    }

    func stream() -> AsyncStream<PushTap> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock {
                continuations[id] = continuation
                for tap in pending { continuation.yield(tap) }
                pending.removeAll()
            }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
            }
        }
    }
}
