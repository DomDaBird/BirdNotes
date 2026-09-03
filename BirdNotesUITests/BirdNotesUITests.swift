import XCTest

final class BirdNotesUITests: XCTestCase {
    @MainActor private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateDrawRotateAndReopenNotebook() throws {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["--birdnotes-ui-testing", "--birdnotes-ui-reset"]
        app.launch()
        let createNotebook = element("library.empty.createNotebook")
        XCTAssertTrue(createNotebook.waitForExistence(timeout: 10))
        createNotebook.tap()

        let nameField = element("newNotebook.name")
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("UI Smoke")

        let confirmCreation = element("newNotebook.create")
        XCTAssertTrue(confirmCreation.isEnabled)
        confirmCreation.tap()

        let notebook = element("library.item.UI Smoke.birdnotebook")
        XCTAssertTrue(notebook.waitForExistence(timeout: 10))
        notebook.tap()

        let canvas = element("notebook.pageCanvas.1")
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        waitForLabel("Notizbuchseite 1 von 1", on: canvas, timeout: 10)
        XCTAssertEqual(canvas.value as? String, "Leer")

        // XCUI kann keinen Apple Pencil simulieren. Die App bleibt im sicheren
        // Pencil-only-Standard; nur dieser automatisierte Zeichentest aktiviert
        // Fingerzeichnen bewusst über dieselbe Oberfläche wie ein Benutzer.
        let fingerDrawing = app.switches["Mit dem Finger zeichnen"].firstMatch
        XCTAssertTrue(fingerDrawing.waitForExistence(timeout: 5))
        if fingerDrawing.value as? String != "Ein" {
            fingerDrawing.tap()
        }
        waitForValue("Ein", on: fingerDrawing, timeout: 5)

        drawVisibleStroke(on: canvas)
        waitForValue("2 Striche", on: canvas, timeout: 10)

        let pageOverview = element("notebook.pageOverview")
        XCTAssertTrue(pageOverview.waitForExistence(timeout: 5))
        waitForLabel("Notizbuchseite 1 von 2", on: canvas, timeout: 10)

        selectPage(2, total: 2)
        let secondPageCanvas = element("notebook.pageCanvas.2")
        waitForValue("Leer", on: secondPageCanvas, timeout: 10)
        drawVisibleStroke(on: secondPageCanvas)
        waitForValue("2 Striche", on: secondPageCanvas, timeout: 10)
        waitForLabel("Notizbuchseite 2 von 3", on: secondPageCanvas, timeout: 10)

        selectPage(1, total: 3)
        let firstPageCanvas = element("notebook.pageCanvas.1")
        waitForValue("2 Striche", on: firstPageCanvas, timeout: 10)
        drawVisibleStroke(on: firstPageCanvas)
        waitForValue("4 Striche", on: firstPageCanvas, timeout: 10)

        // Erzwingt den scenePhase-Flush, während die zuletzt bearbeitete Seite dirty ist.
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(element("notebook.pageCanvas.1").waitForExistence(timeout: 10))
        waitForValue("4 Striche", on: element("notebook.pageCanvas.1"), timeout: 10)

        let orientationButton = element("notebook.toggleOrientation")
        XCTAssertTrue(orientationButton.waitForExistence(timeout: 5))
        XCTAssertEqual(orientationButton.label, "Auf Querformat wechseln")
        orientationButton.tap()
        waitForLabel("Auf Hochformat wechseln", on: orientationButton, timeout: 10)

        // Ein echter Neustart deckt den Autosave- und Ladepfad gemeinsam ab.
        app.terminate()
        app.launchArguments = ["--birdnotes-ui-testing"]
        app.launch()

        let persistedNotebook = element("library.item.UI Smoke.birdnotebook")
        XCTAssertTrue(persistedNotebook.waitForExistence(timeout: 10))
        persistedNotebook.tap()

        let persistedCanvas = element("notebook.pageCanvas.1")
        XCTAssertTrue(persistedCanvas.waitForExistence(timeout: 10))
        waitForValue("4 Striche", on: persistedCanvas, timeout: 10)
        waitForLabel("Notizbuchseite 1 von 3", on: persistedCanvas, timeout: 10)

        let persistedOrientationButton = element("notebook.toggleOrientation")
        XCTAssertTrue(persistedOrientationButton.waitForExistence(timeout: 5))
        XCTAssertEqual(persistedOrientationButton.label, "Auf Hochformat wechseln")

        selectPage(2, total: 3)
        waitForValue("2 Striche", on: element("notebook.pageCanvas.2"), timeout: 10)
    }

    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func drawVisibleStroke(on canvas: XCUIElement) {
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.32, dy: 0.44))
        let middle = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.55))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.68, dy: 0.43))
        start.press(forDuration: 0.15, thenDragTo: middle)
        middle.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    private func selectPage(_ number: Int, total: Int) {
        let overview = element("notebook.pageOverview")
        XCTAssertTrue(overview.waitForExistence(timeout: 5))
        overview.tap()

        let page = element("notebook.page.\(number)")
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        page.tap()
        waitForLabel(
            "Notizbuchseite \(number) von \(total)",
            on: element("notebook.pageCanvas.\(number)"),
            timeout: 10
        )
    }

    @MainActor
    private func waitForValue(_ value: String, on element: XCUIElement, timeout: TimeInterval) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            print("Erwarteter Wert: \(value); aktuelles Element: \(element.debugDescription)")
        }
        XCTAssertEqual(result, .completed)
    }

    @MainActor
    private func waitForLabel(_ label: String, on element: XCUIElement, timeout: TimeInterval) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            print("Erwartetes Label: \(label); aktuelles Element: \(element.debugDescription)")
        }
        XCTAssertEqual(result, .completed)
    }
}
