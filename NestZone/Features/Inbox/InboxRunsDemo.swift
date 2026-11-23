#if DEBUG
import Foundation

/// `-inboxRunsDemo 1`: adds a few stretches of the same kind of thing to the
/// top of the feed (client-side only, nothing written), so the merged rows can
/// be looked at without a household that has just done a big shop.
enum InboxRunsDemo {
    static func adding(to rows: [HomeActivity]) -> [HomeActivity] {
        guard UserDefaults.standard.bool(forKey: "inboxRunsDemo"),
              !rows.contains(where: { $0.id.rawValue.hasPrefix("demo-run") })
        else { return rows }

        let now = Date.now
        func row(_ n: Int, _ category: ActivityCategory, _ title: String, _ body: String,
                 by actor: String, _ name: String, minutesAgo: Double) -> HomeActivity {
            HomeActivity(
                id: ActivityID("demo-run-\(n)"), category: category, title: "\(name) \(title)",
                body: body, actor: UserID(actor), actorName: name,
                created: Timestamp(now.addingTimeInterval(-minutesAgo * 60))
            )
        }
        let shopping = ["Milk", "Eggs", "Sourdough", "Tomatoes", "Feta", "Coffee beans"]
        var demo: [HomeActivity] = shopping.enumerated().map { index, item in
            row(index, .shopping, "added", item, by: "demo-sam", "Sam", minutesAgo: 2 + Double(index) * 3)
        }
        demo += ["Dishes", "Bins", "Hoover"].enumerated().map { index, item in
            row(20 + index, .tasks, "finished a task", item, by: "demo-maya", "Maya", minutesAgo: 40 + Double(index) * 4)
        }
        return demo + rows
    }
}
#endif
