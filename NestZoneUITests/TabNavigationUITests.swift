import XCTest

/// Walks the shell of the app.
///
/// These are deliberately shallow: they prove every tab mounts and renders
/// without crashing, which is the thing a refactor of this size is most likely
/// to break. Behaviour lives in the reducer tests, where it can be checked
/// without a network.
final class TabNavigationUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    /// The app opens on either the auth screen, the home picker or the tab bar,
    /// depending on the simulator's stored session. Only the last is worth
    /// walking, so tests skip rather than fail when signed out.
    private func requireSignedIn() throws {
        let homeTab = app.buttons["HomeTab"]
        guard homeTab.waitForExistence(timeout: 30) else {
            throw XCTSkip("Not signed in on this simulator; skipping tab walk.")
        }
    }

    func testEveryTabOpens() throws {
        try requireSignedIn()

        for identifier in ["HomeTab", "ListsTab", "PlansTab", "HouseTab", "MessagesTab"] {
            let tab = app.buttons[identifier]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "\(identifier) is missing")
            tab.tap()

            // Give the tab a moment to mount its subscriptions, then confirm the
            // process is still alive and responding.
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: 5),
                "App left the foreground after opening \(identifier)"
            )

            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = identifier
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    /// Every segment of every grouped tab mounts: the switch is the only way
    /// to most modules now, so a segment that crashes strands one.
    func testEverySegmentOpens() throws {
        try requireSignedIn()

        let groups = [
            ("ListsTab", ["tasks", "shopping", "notes"]),
            ("PlansTab", ["calendar", "recipes", "movies"]),
            ("HouseTab", ["finance", "maintenance"]),
        ]
        for (tab, modules) in groups {
            app.buttons[tab].tap()
            for module in modules {
                let segment = app.buttons["Segment.\(module)"]
                XCTAssertTrue(segment.waitForExistence(timeout: 10), "\(tab) is missing \(module)")
                segment.tap()
                XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
            }
        }
    }

    /// "Who's doing what" at the bottom of Today is one of two ways into the
    /// contributions breakdown, so a link that stops working strands a whole
    /// screen. Unconditional: a household that has finished nothing still
    /// gets there, and finds an empty state explaining what will fill it.
    func testHomeOpensContributions() throws {
        try requireSignedIn()

        app.buttons["HomeTab"].tap()

        let button = app.buttons["ContributionsButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "Who's doing what link is missing")
        app.swipeUp()

        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "HomeTasksSection"
        home.lifetime = .keepAlways
        add(home)

        button.tap()

        // The nav bar rather than a section title: the screen renders a
        // leaderboard or an empty state depending on the household, and both
        // count as having opened.
        XCTAssertTrue(
            app.navigationBars["Contributions"].waitForExistence(timeout: 10),
            "Contributions screen did not render"
        )
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Contributions"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testSettingsShowsThemeAndLanguage() throws {
        try requireSignedIn()

        app.buttons["SettingsButton"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Theme"].waitForExistence(timeout: 10)
                || app.cells.containing(NSPredicate(format: "label CONTAINS[c] 'Theme'"))
                    .firstMatch.waitForExistence(timeout: 5),
            "Appearance section did not render"
        )
    }
}
