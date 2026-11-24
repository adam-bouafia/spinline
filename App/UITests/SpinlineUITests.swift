import XCTest

/// Drives the app on a simulator against the virtual trainer, and keeps a
/// screenshot of each screen as a test attachment.
final class SpinlineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testConnectRideAndRunAWorkout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        // Devices: the virtual trainer connects at launch.
        XCTAssertTrue(app.buttons["disconnect-virtual-trainer"].waitForExistence(timeout: 15))
        snapshot(app, "1-devices")

        // Ride: ERG responds and live values arrive.
        app.tabBars.buttons["Ride"].tap()
        let up = app.buttons["erg-up"]
        XCTAssertTrue(up.waitForExistence(timeout: 10))
        up.tap()
        let target = app.staticTexts["erg-target"]
        wait(for: target, label: "160 W", timeout: 10)
        sleep(2)
        snapshot(app, "2-ride")

        // Workouts: open one and start it.
        app.tabBars.buttons["Workouts"].tap()
        let openers = app.buttons["workout-openers"]
        XCTAssertTrue(openers.waitForExistence(timeout: 10))
        openers.tap()
        let start = app.buttons["start-workout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        snapshot(app, "3-workout-detail")
        start.tap()

        // At ten times real time the two-minute warm-up ends after about 12 s.
        let step = app.staticTexts["session-step"]
        wait(for: step, label: "Warm-up", timeout: 10)
        wait(for: step, label: "Opener", timeout: 30)
        snapshot(app, "4-session")
    }

    @MainActor
    private func wait(for element: XCUIElement, label: String, timeout: TimeInterval) {
        let predicate = NSPredicate(format: "label == %@", label)
        let found = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [found], timeout: timeout), .completed, "\(element) never showed \(label)")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
