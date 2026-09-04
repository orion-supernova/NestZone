import XCTest

/// Captures the first frame the user sees, for every configuration Xcode runs.
final class LaunchUITests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool { true }

    override func setUp() {
        continueAfterFailure = false
    }

    func testLaunchRendersWithoutCrashing() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 30),
            "App did not reach the foreground"
        )

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Launch"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
