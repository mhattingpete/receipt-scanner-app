import XCTest

final class BasicUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verify basic UI elements appear
        XCTAssertTrue(app.navigationBars["Receipts"].waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testCameraButtonExists() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Check camera button exists
        XCTAssertTrue(app.buttons["camera"].waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testSearchFieldExists() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Check search field exists
        let searchField = app.textFields.matching(identifier: "searchField").firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
    }
    
    @MainActor
    func testNavigationBarTitle() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verify navigation bar title
        XCTAssertTrue(app.navigationBars.staticTexts["Receipts"].exists)
    }
    
    @MainActor
    func testListExists() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verify the list view exists
        XCTAssertTrue(app.collectionViews.firstMatch.exists)
    }
    
    @MainActor
    func testSwipeToDeleteReceipt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
        
        // Wait for UI to stabilize
        sleep(1)
        
        // Check if any cell exists (using a test mode that ensures at least one receipt)
        let firstCell = app.collectionViews.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Receipt cell should exist")
        
        // Get initial cell count
        let initialCellCount = app.collectionViews.cells.count
        XCTAssertGreaterThan(initialCellCount, 0, "There should be at least one receipt to test deletion")
        
        // Perform swipe action
        firstCell.swipeLeft(velocity: XCUIGestureVelocity.fast)
        
        // Sleep briefly to ensure swipe completes and button appears
        sleep(1)
        
        // Check if delete button appears
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button should appear after swipe")
        
        // Tap delete button
        deleteButton.tap()
        
        // Check if confirmation alert appears
        let deleteAlert = app.alerts["Delete Receipt"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 5), "Delete confirmation alert should appear")
        
        // Complete deletion to verify it works
        deleteAlert.buttons["Delete"].tap()
        
        // Wait for deletion to complete
        sleep(1)
        
        // Verify cell was deleted
        let newCellCount = app.collectionViews.cells.count
        XCTAssertEqual(newCellCount, initialCellCount - 1, "Cell count should decrease after deletion")
    }
}