import Foundation
import UIKit

/// A simplified helper class for diagnostic purposes to diagnose issues with receipt saving and loading.
class ReceiptDiagnostics {
    
    /// Singleton instance for easy access
    static let shared = ReceiptDiagnostics()
    
    /// Whether detailed logging is enabled 
    var verboseLogging = false
    
    /// Debug file location to check if files are stored correctly
    func checkStorage() {
        let fileManager = FileManager.default
        let docsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        log("Documents directory: \(docsDirectory.path)")
        
        // List files in documents directory
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: docsDirectory, includingPropertiesForKeys: nil)
            log("Files in documents directory: \(fileURLs.count)")
            
            // Check receipt files specifically
            let manager = ReceiptManager.shared
            let csvExists = fileManager.fileExists(atPath: manager.csvFileURL().path)
            let digitalExists = fileManager.fileExists(atPath: manager.digitalCSVFileURL().path)
            
            log("Receipts in memory: \(manager.receipts.count)")
            log("Receipt CSV exists: \(csvExists)")
            log("Digital items CSV exists: \(digitalExists)")
            
            // Check CSV content
            if csvExists {
                if let content = try? String(contentsOf: manager.csvFileURL(), encoding: .utf8) {
                    let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
                    log("Receipt CSV has \(rows.count) rows (including header)")
                }
            }
        } catch {
            log("Error checking storage: \(error)", isError: true)
        }
    }
    
    /// Create and save a test receipt to verify functionality
    @discardableResult
    func testSaveReceipt() -> Bool {
        log("Testing receipt saving functionality")
        
        // Create test receipt
        let testReceipt = Receipt(
            id: UUID(),
            store: "TEST_STORE",
            date: "01/01/2023",
            time: "12:34",
            items: [
                ReceiptItem(name: "Test Item 1", price: "9.99"),
                ReceiptItem(name: "Test Item 2", price: "19.99")
            ],
            imageFilename: "test_receipt.jpg"
        )
        
        // Save to manager
        let countBefore = ReceiptManager.shared.receipts.count
        
        ReceiptManager.shared.saveReceipt(testReceipt)
        ReceiptManager.shared.saveDigitalItems(from: testReceipt)
        
        // Verify save
        ReceiptManager.shared.loadReceipts()
        let countAfter = ReceiptManager.shared.receipts.count
        
        let success = countAfter > countBefore
        log("Test " + (success ? "PASSED" : "FAILED"))
        
        return success
    }
    
    /// Internal logging function
    private func log(_ message: String, isError: Bool = false) {
        let prefix = isError ? "ERROR" : "INFO"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] \(prefix): \(message)")
    }
    
    /// Run diagnostic check with optional action
    func runDiagnostics(executing action: (() -> Void)? = nil) {
        log("=== STARTING DIAGNOSTICS ===")
        checkStorage()
        
        if let action = action {
            log("=== EXECUTING TEST ACTION ===")
            action()
            log("=== ACTION COMPLETED ===")
            checkStorage()
        }
        
        log("=== DIAGNOSTICS COMPLETE ===")
    }
}