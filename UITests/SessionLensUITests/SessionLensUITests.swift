import UIKit
import XCTest

/// iOS UI tests: run on iPad (regular width, NavigationSplitView) and iPhone
/// (compact width, TabView + NavigationStack). Queries use accessibility labels
/// and accessibilityIdentifiers with waitForExistence so they pass in both layouts.
@MainActor
final class SessionLensUITests: XCTestCase {

    func testLaunchAndDemo() throws {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }

        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-tab=1", "-resetData"]
        app.launch()

        // "Timeline" is the navigation title in both layouts and the tab-bar
        // label on compact width — query by label, never by tab id.
        let timelineShown = app.navigationBars["Timeline"].waitForExistence(timeout: 10)
            || app.navigationBars.staticTexts["Timeline"].waitForExistence(timeout: 5)
            || app.buttons["Timeline"].firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(timelineShown, "Timeline should be visible after launch with -tab=1")

        // Demo data loaded: the first timeline row exposes its summary as a label.
        let firstRowSummary = app.staticTexts["Session started. Working directory: /demo/project"].firstMatch
        XCTAssertTrue(firstRowSummary.waitForExistence(timeout: 5), "Demo timeline row should be visible")

        // Tap row to reveal event detail pane.
        firstRowSummary.tap()
        if !element(app, "timeline.detailPane").waitForExistence(timeout: 3) {
            firstRowSummary.tap()
        }
        XCTAssertTrue(element(app, "timeline.detailPane").waitForExistence(timeout: 5), "Timeline detail pane should appear")

        // Filter timeline via search field, then clear.
        let searchField = app.textFields["timeline.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Timeline search field should exist")
        let filteredRow = app.staticTexts["I will add the button in HomeView.swift and call AuthService.signIn()."].firstMatch
        searchField.tap()
        searchField.typeText("Home")
        if !filteredRow.waitForExistence(timeout: 4) {
            // Retry without dismissing keyboard if cold bring-up dropped a synthetic keystroke.
            let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8)
            searchField.typeText(deletes + "Home")
        }
        XCTAssertTrue(filteredRow.waitForExistence(timeout: 5), "Filtered timeline row should be visible")
        let clearButton = app.buttons["timeline.searchClear"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5), "Clear search button should appear")
        clearButton.tap()
        XCTAssertTrue(firstRowSummary.waitForExistence(timeout: 5), "Cleared search should restore timeline rows")

        // Navigate to Sessions and verify demo log files.
        selectSection(app, "Sessions")
        XCTAssertTrue(element(app, "sessions.table").waitForExistence(timeout: 5), "Sessions table/list should exist")
        XCTAssertTrue(
            app.staticTexts["sessions.row.session-demo-01.jsonl"].firstMatch.waitForExistence(timeout: 5),
            "Demo session file row should be visible"
        )

        // Navigate to Diff and switch selected diff file.
        selectSection(app, "Diff")
        XCTAssertTrue(element(app, "diff.fileList").waitForExistence(timeout: 5), "Diff file list should exist")
        let initialDiffTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'diffPane.title' AND label == 'HomeView.swift'")
        ).firstMatch
        XCTAssertTrue(initialDiffTitle.waitForExistence(timeout: 5), "Initial diff file should be HomeView.swift")

        let renamedFileRow = app.buttons["diff.fileRow.AuthHelpers.swift"].firstMatch
        XCTAssertTrue(renamedFileRow.waitForExistence(timeout: 5), "AuthHelpers.swift row button should exist in diff list")
        renamedFileRow.tap()
        let updatedDiffTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'diffPane.title' AND label == 'AuthHelpers.swift'")
        ).firstMatch
        if !updatedDiffTitle.waitForExistence(timeout: 3) {
            renamedFileRow.tap()
        }
        XCTAssertTrue(updatedDiffTitle.waitForExistence(timeout: 5), "Diff pane should switch to AuthHelpers.swift")

        // Navigate to Settings and verify Demo data mode.
        selectSection(app, "Settings")
        XCTAssertTrue(element(app, "settings.form").waitForExistence(timeout: 5), "Settings form should exist")
        let demoModeValue = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'settings.mode' AND label CONTAINS 'Demo data'")
        ).firstMatch
        XCTAssertTrue(demoModeValue.waitForExistence(timeout: 5), "Settings should report Demo data mode")
    }

    func testAdaptiveLayoutLoadDemoAndOrientations() throws {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }

        let app = XCUIApplication()
        app.launchArguments = ["-resetData"]
        app.launch()

        // Empty state before loading demo data.
        XCTAssertTrue(
            app.staticTexts["No session logs"].firstMatch.waitForExistence(timeout: 10),
            "Empty state should be shown before loading data"
        )

        if UIDevice.current.userInterfaceIdiom == .pad {
            // Regular width on iPad uses NavigationSplitView, never TabView.
            XCTAssertTrue(element(app, "sidebar.list").waitForExistence(timeout: 5), "iPad split view sidebar should exist")
            XCTAssertFalse(app.tabBars.firstMatch.exists, "iPad regular width should not render compact TabView")

            let loadDemo = app.buttons["sidebar.loadDemoButton"]
            XCTAssertTrue(loadDemo.waitForExistence(timeout: 5), "Sidebar Load Demo Data button should exist")
            loadDemo.tap()

            XCTAssertTrue(element(app, "sessions.table").waitForExistence(timeout: 5), "Sessions table should appear after loading demo")

            // Verify all 4 iPad orientations keep NavigationSplitView sidebar and detail visible.
            let orientations: [UIDeviceOrientation] = [
                .portrait,
                .landscapeLeft,
                .portraitUpsideDown,
                .landscapeRight,
                .portrait,
            ]
            for orientation in orientations {
                XCUIDevice.shared.orientation = orientation
                XCTAssertTrue(
                    element(app, "sidebar.list").waitForExistence(timeout: 5),
                    "Split view sidebar should stay visible in orientation \(orientation.rawValue)"
                )
                XCTAssertTrue(
                    element(app, "main.tabPicker").waitForExistence(timeout: 5),
                    "Detail picker should stay visible in orientation \(orientation.rawValue)"
                )
                XCTAssertTrue(
                    element(app, "sessions.table").waitForExistence(timeout: 5),
                    "Sessions content should stay visible in orientation \(orientation.rawValue)"
                )
            }
        } else {
            // Compact width on iPhone keeps TabView + NavigationStack, no split view sidebar.
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5), "Compact width should render TabView")
            XCTAssertFalse(element(app, "sidebar.list").exists, "Compact width should not render split view sidebar")

            let loadDemo = app.buttons["sessions.loadDemoButton"]
            XCTAssertTrue(loadDemo.waitForExistence(timeout: 5), "Compact Load Demo Data button should exist")
            loadDemo.tap()

            XCTAssertTrue(element(app, "sessions.table").waitForExistence(timeout: 5), "Sessions list should appear after loading demo")
            XCTAssertTrue(
                app.staticTexts["sessions.row.session-demo-01.jsonl"].firstMatch.waitForExistence(timeout: 5),
                "Demo session file row should appear on compact width"
            )
        }
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func selectSection(_ app: XCUIApplication, _ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let segmentedButton = app.segmentedControls["main.tabPicker"].buttons[title]
        if segmentedButton.exists && segmentedButton.isHittable {
            segmentedButton.tap()
            return
        }

        let tabButton = app.tabBars.buttons[title]
        if tabButton.exists && tabButton.isHittable {
            tabButton.tap()
            return
        }

        let button = app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Section \(title) button should exist", file: file, line: line)
        button.tap()
    }
}

/// Attaches to a running SessionLens instance (`simctl launch ... -resetData -demo`)
/// and navigates to each of the 5 feature screens without terminating the app on teardown,
/// enabling synchronous foreground `xcrun simctl io <id> screenshot` captures.
@MainActor
final class SessionLensScreenshotUITests: XCTestCase {

    private func attach() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "fr.dcreations.sessionlens")
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: 10)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func selectSection(_ app: XCUIApplication, _ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let segmentedButton = app.segmentedControls["main.tabPicker"].buttons[title]
        if segmentedButton.waitForExistence(timeout: 2) && segmentedButton.isHittable {
            segmentedButton.tap()
            return
        }
        let tabButton = app.tabBars.buttons[title]
        if tabButton.waitForExistence(timeout: 2) && tabButton.isHittable {
            tabButton.tap()
            return
        }
        let button = app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Section \(title) button should exist", file: file, line: line)
        button.tap()
    }

    func test1Timeline() throws {
        let app = attach()
        selectSection(app, "Timeline")
        if app.buttons["timeline.searchClear"].exists {
            app.buttons["timeline.searchClear"].tap()
        }
        let firstRow = app.staticTexts["Session started. Working directory: /demo/project"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 8), "Timeline demo rows should appear")
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test2Diff() throws {
        let app = attach()
        selectSection(app, "Diff")
        XCTAssertTrue(element(app, "diff.fileList").waitForExistence(timeout: 8), "Diff file list should appear")
        let renamedFileRow = app.buttons["diff.fileRow.AuthHelpers.swift"].firstMatch
        XCTAssertTrue(renamedFileRow.waitForExistence(timeout: 5), "AuthHelpers.swift diff row should exist")
        renamedFileRow.tap()
        let diffTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'diffPane.title' AND label == 'AuthHelpers.swift'")
        ).firstMatch
        if !diffTitle.waitForExistence(timeout: 3) {
            renamedFileRow.tap()
        }
        XCTAssertTrue(diffTitle.waitForExistence(timeout: 5), "Diff pane should show AuthHelpers.swift")
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test3Search() throws {
        let app = attach()
        selectSection(app, "Timeline")
        if app.buttons["timeline.searchClear"].exists {
            app.buttons["timeline.searchClear"].tap()
        }
        let searchField = app.textFields["timeline.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should exist")
        searchField.tap()
        Thread.sleep(forTimeInterval: 0.4)
        searchField.typeText("Auth\n")
        if (searchField.value as? String) != "Auth" {
            if app.buttons["timeline.searchClear"].exists {
                app.buttons["timeline.searchClear"].tap()
            }
            searchField.tap()
            Thread.sleep(forTimeInterval: 0.3)
            searchField.typeText("Auth\n")
        }
        let filteredRow = app.staticTexts["I will add the button in HomeView.swift and call AuthService.signIn()."].firstMatch
        if !filteredRow.waitForExistence(timeout: 4) {
            let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8)
            searchField.typeText(deletes + "Auth\n")
        }
        if app.keyboards.buttons["Search"].exists && app.keyboards.buttons["Search"].isHittable {
            app.keyboards.buttons["Search"].tap()
        }
        XCTAssertTrue(filteredRow.waitForExistence(timeout: 5), "Filtered search results should appear")
        Thread.sleep(forTimeInterval: 0.6)
    }

    func test4Detail() throws {
        let app = attach()
        selectSection(app, "Timeline")
        if app.buttons["timeline.searchClear"].exists {
            app.buttons["timeline.searchClear"].tap()
        }
        let toolCallRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Tool call: edit_file' AND label CONTAINS 'HomeView.swift'")
        ).firstMatch
        XCTAssertTrue(toolCallRow.waitForExistence(timeout: 5), "edit_file tool call row should exist")
        toolCallRow.tap()
        if !element(app, "timeline.detailPane").waitForExistence(timeout: 3) {
            toolCallRow.tap()
        }
        XCTAssertTrue(element(app, "timeline.detailPane").waitForExistence(timeout: 5), "Raw JSONL detail pane should appear")
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test5Sessions() throws {
        let app = attach()
        selectSection(app, "Sessions")
        XCTAssertTrue(element(app, "sessions.table").waitForExistence(timeout: 8), "Sessions table/list should exist")
        XCTAssertTrue(
            app.staticTexts["sessions.row.session-demo-01.jsonl"].firstMatch.waitForExistence(timeout: 5),
            "Demo session file row should appear"
        )
        Thread.sleep(forTimeInterval: 0.5)
    }
}
