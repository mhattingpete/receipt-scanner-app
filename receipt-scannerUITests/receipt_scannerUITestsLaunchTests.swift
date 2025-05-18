//
//  receipt_scannerUITestsLaunchTests.swift
//  receipt-scannerUITests
//

import XCTest
import SwiftUI

final class receipt_scannerUITestsLaunchTests: XCTestCase {
    
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false // Use false for more reliable tests
    }
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // DISABLED: Old tests were causing issues
    // New tests have been moved to BasicUITests.swift and ReceiptFlowTests.swift
    
    // These tests have been moved to BasicUITests.swift and ReceiptFlowTests.swift
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Short delay to ensure UI is fully loaded
        Thread.sleep(forTimeInterval: 1)
        
        // Verify the main view has loaded
        XCTAssertTrue(app.navigationBars["Receipts"].exists)
        
        // Take a screenshot
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Receipt Scanner Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}