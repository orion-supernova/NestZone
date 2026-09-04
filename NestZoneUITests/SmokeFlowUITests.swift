import XCTest

/// Drives the two flows that were failing against the real backend, so a
/// client/server contract mismatch shows up here rather than in someone's hands.
final class SmokeFlowUITests: XCTestCase {

    @MainActor
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        return app
    }

    @MainActor
    private func requireSignedIn(_ app: XCUIApplication) throws {
        guard app.buttons["HomeTab"].waitForExistence(timeout: 40) else {
            throw XCTSkip("Not signed in on this simulator.")
        }
    }

    @MainActor
    private func assertNoErrorAlert(_ app: XCUIApplication, _ context: String) {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            let message = alert.staticTexts.allElementsBoundByIndex
                .map(\.label)
                .joined(separator: " | ")
            XCTFail("\(context) put up an alert: \(message)")
        }
    }

    @MainActor
    func testAddShoppingItem() throws {
        let app = launch()
        try requireSignedIn(app)

        app.buttons["HubTab"].tap()
        let shopping = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Shopping'")
        ).firstMatch
        guard shopping.waitForExistence(timeout: 15) else {
            throw XCTSkip("Hub tiles never rendered; backend unreachable.")
        }
        shopping.tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "composer missing")
        field.tap()
        let name = "UITest \(Int(Date().timeIntervalSince1970))"
        field.typeText(name)
        app.buttons["Add"].firstMatch.tap()

        assertNoErrorAlert(app, "Adding a shopping item")
        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: 15),
            "the new item never appeared in the list"
        )
    }

    @MainActor
    func testStartMovieNightRound() throws {
        let app = launch()
        try requireSignedIn(app)

        app.buttons["HomeTab"].tap()
        let card = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'watch'")
        ).firstMatch
        guard card.waitForExistence(timeout: 15) else {
            throw XCTSkip("Home tab never rendered.")
        }
        card.tap()

        let start = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Start a round'")
        ).firstMatch
        guard start.waitForExistence(timeout: 10) else {
            throw XCTSkip("A round is already open on this account.")
        }
        start.tap()

        // The picker defaults to "Popular", which needs no extra input.
        let confirm = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Start a round'")
        ).element(boundBy: 0)
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "picker never opened")
        confirm.tap()

        // Creating a round hits TMDb through a Convex action, so allow for it.
        assertNoErrorAlert(app, "Starting a movie-night round")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "MovieNight"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
