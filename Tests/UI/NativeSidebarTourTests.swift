import XCTest

/// Walks the native sidebar against a real Home Assistant (see `E2EFlow`), attaching a screenshot at every
/// stop. Not part of CI: it is the redesign's visual check, recorded by the test plan's screen capture.
final class NativeSidebarTourTests: XCTestCase {
    private var app: XCUIApplication!
    private var flow: E2EFlow!

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = E2EFlow.launchArguments
        app.launch()
        flow = E2EFlow(app: app)
    }

    func testSidebarTour() {
        if app.buttons[.onboardingWelcomeContinue].waitForExistence(timeout: 8) {
            flow.onboard()
        }
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: E2EFlow.Timeout.frontend))
        settle(6)
        snapshot("01-dashboard")

        // Interactive open from the left edge.
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.002, dy: 0.55))
        let middle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.55))
        edge.press(forDuration: 0.05, thenDragTo: middle, withVelocity: .default, thenHoldForDuration: 0.4)
        settle(1)
        snapshot("02-sidebar-edge-open")

        // Switch panels.
        let map = app.buttons["Map"]
        if map.waitForExistence(timeout: 5) {
            map.tap()
            settle(3)
            snapshot("03-map-panel")
        }

        // The frontend's menu button now opens the native sidebar.
        let menu = flow.webElement(labelContaining: "Sidebar toggle")
        if menu.waitForExistence(timeout: 10) {
            menu.tap()
            settle(1.2)
            snapshot("04-sidebar-from-menu")
        }

        // Close by tapping the card.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        settle(1)
        snapshot("05-closed")

        // Below a panel's top level the left edge goes back instead, with WebKit's interactive swipe.
        if menu.waitForExistence(timeout: 5) {
            menu.tap()
            settle(1)
        }
        let haSettings = app.buttons["Settings"]
        if haSettings.waitForExistence(timeout: 5) {
            haSettings.tap()
            settle(3)
            let areas = flow.webElement(labelContaining: "Areas")
            if areas.waitForExistence(timeout: 10) {
                areas.tap()
                settle(3)
                snapshot("07-subpage")
                edge.press(forDuration: 0.05, thenDragTo: middle, withVelocity: .slow, thenHoldForDuration: 0.3)
                settle(2)
                snapshot("08-after-back-swipe")
            }
        }

        // App settings zoom out of the gear.
        if menu.waitForExistence(timeout: 5) {
            menu.tap()
            settle(1)
        }
        let settings = app.buttons["App Settings"]
        if settings.waitForExistence(timeout: 5) {
            settings.tap()
            settle(1.5)
            snapshot("06-app-settings")
        }
    }

    private func settle(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
