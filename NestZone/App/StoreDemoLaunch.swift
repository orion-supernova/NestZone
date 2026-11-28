import ComposableArchitecture
import Foundation

#if DEBUG || MEASURE
/// The screenshot launch arguments that open a screen by themselves, a few
/// seconds after launch, through the same actions a tap would send:
/// `-openConversation first`, `-openMovieNight 1`, `-openRecipe first`,
/// `-openIssue first`, `-calendarMode agenda|week|month`, `-openSettings 1`
/// (add `-settingsScroll 1` to start it at the foot), `-openInbox activity|updates`
/// (the bell), `-openUpdatesEditor first` (the bell's Manage updates, on the
/// newest entry; admin accounts only, and nothing is saved), `-openEvent first`
/// (the next event, opened from Today as a page), `-pinnedDemo 1` (two made-up
/// pinned notes on Today, in memory only: nothing is written, and the next push
/// from the server replaces them), `-switchHome "Our Place"` (opens that home
/// by name, as the Switch Home sheet would, and stops there: the choice is
/// remembered on the device, so the next launch starts in it and the other
/// hooks follow on that launch).
///
/// Data arrives over live subscriptions, so each step waits (up to ten
/// seconds) for the thing it is about to open rather than guessing a delay.
@MainActor
enum StoreDemoLaunch {
    static func run(_ store: StoreOf<MainFeature>) async {
        let defaults = UserDefaults.standard
        let requested = ["openConversation", "openMovieNight", "openRecipe", "openIssue", "calendarMode", "openSettings", "openCustomize", "dockMode", "openInbox", "openUpdatesEditor", "openEvent", "pinnedDemo", "dockNotice", "switchHome", "openTour", "openPostOnboarding"]
            .contains { defaults.object(forKey: $0) != nil }
        guard requested else { return }
        try? await Task.sleep(for: .seconds(3))

        if let name = defaults.string(forKey: "switchHome") {
            await wait { store.settings.homes.contains { $0.name == name } }
            if let home = store.settings.homes.first(where: { $0.name == name }) {
                store.send(.settings(.delegate(.homeSwitched(home.id))))
            }
            return
        }

        // `-dockMode auto | always:dinner|event|movie | addOnly | off`
        if let raw = defaults.string(forKey: "dockMode") {
            let parts = raw.split(separator: ":").map(String.init)
            var setting = DockSetting()
            switch parts.first {
            case "always":
                setting.mode = .always
                setting.thing = switch parts.last {
                case "event": .event
                case "movie": .movieRound
                default: .dinner
                }
            case "addOnly": setting.mode = .addOnly
            case "off": setting.mode = .off
            default: break
            }
            store.now.$dockSettings.withLock { $0[store.homeID] = setting }
            store.send(.now(.tick(store.now.now)))
        }
        // `-dockNotice 1`: the note the dock's menu leaves when it is switched
        // off, which a long press cannot be scripted to do.
        if defaults.bool(forKey: "dockNotice") {
            store.send(.now(.delegate(.dockTurnedOff)))
        }
        // `-openTour 1` opens Settings' tour; `-openPostOnboarding 1` plays the
        // end of a first run (Plus offer, then the first shopping item) as if
        // a home had just been made.
        if defaults.bool(forKey: "openTour") {
            store.send(.settingsButtonTapped)
            try? await Task.sleep(for: .seconds(1))
            store.send(.settings(.delegate(.tourRequested)))
        }
        if defaults.bool(forKey: "openPostOnboarding") {
            store.send(.firstRunBegan)
        }
        if defaults.bool(forKey: "openCustomize") {
            store.send(.settings(.delegate(.customizeTapped)))
        }

        if let mode = defaults.string(forKey: "calendarMode").flatMap(CalendarFeature.State.Mode.init(rawValue:)) {
            store.send(.plans(.delegate(.open(.module(.calendar)))))
            await wait { store.plans.segments[id: .calendar] != nil }
            store.send(.plans(.segments(.element(id: .calendar, action: .screen(.calendar(.modeSelected(mode)))))))
        }

        if defaults.bool(forKey: "pinnedDemo") {
            let notes = [
                Note(id: NoteID(rawValue: "demo-wifi"), body: "Wi-Fi: Nest-5G\nPassword: kettle-sunrise-42", color: "yellow"),
                Note(id: NoteID(rawValue: "demo-bins"), body: "Bins out on Sunday night. Recycling is every other week.", color: "blue"),
                Note(id: NoteID(rawValue: "demo-landlord"), body: "Landlord: Ms Alder\n+44 20 7946 0000", color: "pink"),
            ]
            store.send(.home(.pinnedNotesUpdated(notes)))
        }

        if defaults.string(forKey: "openEvent") != nil {
            // `-openEvent demo` opens a made-up event (read-only: the page only
            // reads its plan, and the id is not the server's).
            let demo = defaults.string(forKey: "openEvent") == "demo"
            if !demo { await wait { !store.homeTab.upcoming.isEmpty } }
            let start = Calendar.current.date(byAdding: .hour, value: 30, to: .now) ?? .now
            let fake = EventOccurrence(
                eventID: EventID(rawValue: "demo-event"),
                title: "Housewarming dinner",
                notes: "Bring a plant. Parking is on the left.",
                location: "Home",
                kind: .general,
                startsAt: Timestamp(start),
                endsAt: Timestamp(start.addingTimeInterval(3 * 3600))
            )
            if let occurrence = demo ? fake : store.homeTab.upcoming.first {
                store.send(.today(.delegate(.open(.occurrence(occurrence)))))
            }
        }

        if defaults.bool(forKey: "openSettings") {
            store.send(.settingsButtonTapped)
        }

        if let side = defaults.string(forKey: "openInbox") ?? (defaults.object(forKey: "openUpdatesEditor") != nil ? "updates" : nil) {
            // Sent again if the first is lost to the tabs still settling: a sheet
            // asked for while the root is mid-transition is dropped.
            for _ in 0..<6 where !store.inbox.isOpen {
                store.send(.inbox(.bellTapped))
                try? await Task.sleep(for: .milliseconds(800))
            }
            if let tab = InboxFeature.State.Tab(rawValue: side) {
                store.send(.inbox(.tabSelected(tab)))
            }
            if defaults.object(forKey: "openUpdatesEditor") != nil {
                await wait { store.inbox.badge.isAdmin }
                store.send(.inbox(.adminTapped))
                await wait { store.inbox.admin?.updates.isEmpty == false }
                if let newest = store.inbox.admin?.updates.first {
                    store.send(.inbox(.admin(.presented(.editTapped(newest)))))
                    // `-updatesEditorLanguage tr`: the editor's picker, set.
                    if let code = defaults.string(forKey: "updatesEditorLanguage"),
                       let language = AppLanguage(rawValue: code) {
                        try? await Task.sleep(for: .milliseconds(600))
                        store.send(.inbox(.admin(.presented(.composer(.presented(.binding(.set(\.language, language))))))))
                    }
                }
            }
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
