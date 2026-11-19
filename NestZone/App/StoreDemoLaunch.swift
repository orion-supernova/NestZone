import ComposableArchitecture
import Foundation

#if DEBUG || MEASURE
/// The screenshot launch arguments that open a screen by themselves, a few
/// seconds after launch, through the same actions a tap would send:
/// `-openConversation first`, `-openMovieNight 1`, `-openRecipe first`,
/// `-openIssue first`, `-calendarMode agenda|week|month`.
///
/// Data arrives over live subscriptions, so each step waits (up to ten
/// seconds) for the thing it is about to open rather than guessing a delay.
@MainActor
enum StoreDemoLaunch {
    static func run(_ store: StoreOf<MainFeature>) async {
        let defaults = UserDefaults.standard
        let requested = ["openConversation", "openMovieNight", "openRecipe", "openIssue", "calendarMode"]
            .contains { defaults.object(forKey: $0) != nil }
        guard requested else { return }
        try? await Task.sleep(for: .seconds(3))

        if let mode = defaults.string(forKey: "calendarMode").flatMap(CalendarFeature.State.Mode.init(rawValue:)) {
            store.send(.plans(.delegate(.open(.module(.calendar)))))
            await wait { store.plans.segments[id: .calendar] != nil }
            store.send(.plans(.segments(.element(id: .calendar, action: .screen(.calendar(.modeSelected(mode)))))))
        }

        if defaults.string(forKey: "openConversation") != nil {
            store.send(.tabSelected(.messages))
            await wait { !store.messages.conversations.isEmpty }
            let all = store.messages.conversations
            if let chat = all.first(where: \.isGroupChat) ?? all.first {
                store.send(.messages(.conversationTapped(chat)))
            }
        }

        if defaults.bool(forKey: "openMovieNight") {
            store.send(.today(.delegate(.open(.movieNight))))
        }

        if defaults.string(forKey: "openRecipe") != nil {
            store.send(.plans(.delegate(.open(.module(.recipes)))))
            await wait { firstRecipe(store) != nil }
            if let recipe = firstRecipe(store) {
                store.send(.plans(.delegate(.open(.recipe(recipe)))))
            }
        }

        if defaults.string(forKey: "openIssue") != nil {
            await wait { store.homeTab.issues.contains(where: \.isOpen) }
            if let issue = store.homeTab.issues.first(where: \.isOpen) {
                store.send(.today(.delegate(.open(.issue(issue.id)))))
            }
        }
    }

    private static func firstRecipe(_ store: StoreOf<MainFeature>) -> Recipe? {
        guard case let .recipes(recipes) = store.plans.segments[id: .recipes]?.screen else { return nil }
        return recipes.visible.first
    }

    private static func wait(until ready: () -> Bool) async {
        for _ in 0..<40 where !ready() { try? await Task.sleep(for: .milliseconds(250)) }
    }
}
#endif
