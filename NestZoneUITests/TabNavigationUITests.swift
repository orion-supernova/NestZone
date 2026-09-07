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

        for identifier in ["HomeTab", "HubTab", "NotesTab", "MessagesTab", "SettingsTab"] {
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

    func testHubOpensShoppingList() throws {
        try requireSignedIn()

        app.buttons["HubTab"].tap()
        let shopping = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Shopping'")
        ).firstMatch
        guard shopping.waitForExistence(timeout: 10) else {
            throw XCTSkip("Hub tiles not rendered; backend may be unreachable.")
        }
        shopping.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    /// The chart button in the Tasks header is the only way into the
    /// contributions breakdown, so a button that stops working strands a whole
    /// screen. Unconditional, unlike the summary card it replaced: a household
    /// that has finished nothing still gets there, and finds an empty state
    /// explaining what will fill it.
    func testHomeOpensContributions() throws {
        try requireSignedIn()

        app.buttons["HomeTab"].tap()

        let button = app.buttons["ContributionsButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "chart button is missing")
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

        app.buttons["SettingsTab"].tap()
        XCTAssertTrue(
            app.staticTexts["Theme"].waitForExistence(timeout: 10)
                || app.cells.containing(NSPredicate(format: "label CONTAINS[c] 'Theme'"))
                    .firstMatch.waitForExistence(timeout: 5),
            "Appearance section did not render"
        )
    }
}
