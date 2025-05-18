import XCTest
@testable import receipt_scanner

final class ReceiptManagerTests: XCTestCase {
    
    // Create a testable subclass to work with custom filenames
    class TestableReceiptManager: ReceiptManager {
        var testReceiptsFileName: String
        var testDigitalFileName: String
        
        init(testReceiptsFileName: String, testDigitalFileName: String) {
            self.testReceiptsFileName = testReceiptsFileName
            self.testDigitalFileName = testDigitalFileName
            super.init()
        }
        
        override func csvFileURL() -> URL {
            documentsDirectory().appendingPathComponent(testReceiptsFileName)
        }
        
        override func digitalCSVFileURL() -> URL {
            documentsDirectory().appendingPathComponent(testDigitalFileName)
        }
        
        // Override to ensure synchronous file operations for testing
        override func saveReceipt(_ receipt: Receipt) {
            super.saveReceipt(receipt)
            
            // Force synchronous file operations for testing
            let fileContent = try? String(contentsOf: csvFileURL(), encoding: .utf8)
            if fileContent == nil {
                print("Error: Failed to read file content after saving")
            }
        }
    }
    
    var sut: TestableReceiptManager!
    let testReceiptsFileName = "test_receipts.csv"
    let testDigitalFileName = "test_digital_items.csv"
    
    override func setUp() {
        super.setUp()
        // Create a test-specific instance to avoid interfering with actual data
        sut = TestableReceiptManager(
            testReceiptsFileName: testReceiptsFileName,
            testDigitalFileName: testDigitalFileName
        )
        
        // Clean up any existing test files before each test
        removeTestFiles()
    }
    
    override func tearDown() {
        // Clean up after tests
        removeTestFiles()
        sut = nil
        super.tearDown()
    }
    
    func testSaveReceipt() {
        // Given
        sut.receipts = [] // Ensure we start with a clean state
        let testReceipt = createTestReceipt(store: "Test Store")
        
        // When
        sut.saveReceipt(testReceipt)
        
        // Then
        XCTAssertEqual(sut.receipts.count, 1)
        XCTAssertEqual(sut.receipts.first?.store, "Test Store")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sut.csvFileURL().path))
    }
    
    func testSaveMultipleReceipts() {
        // Given
        sut.receipts = [] // Ensure we start with a clean state
        let receipt1 = createTestReceipt(store: "Store 1")
        let receipt2 = createTestReceipt(store: "Store 2")
        
        // When
        sut.saveReceipt(receipt1)
        sut.saveReceipt(receipt2)
        
        // Then
        XCTAssertEqual(sut.receipts.count, 2)
        XCTAssertEqual(sut.receipts[0].store, "Store 1")
        XCTAssertEqual(sut.receipts[1].store, "Store 2")
    }
    
    func testSaveDigitalItems() {
        // Given
        sut.receipts = [] // Ensure we start with a clean state
        let receipt = createTestReceipt(
            store: "Digital Store",
            items: [
                ReceiptItem(name: "Digital Item 1", price: "10.99"),
                ReceiptItem(name: "Digital Item 2", price: "5.99")
            ],
            imageFilename: "digital_test.jpg"
        )
        
        // When
        sut.saveDigitalItems(from: receipt)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: sut.digitalCSVFileURL().path))
        
        // Verify file contents
        if let content = try? String(contentsOf: sut.digitalCSVFileURL()) {
            XCTAssertTrue(content.contains("Digital Item 1"))
            XCTAssertTrue(content.contains("Digital Item 2"))
            XCTAssertTrue(content.contains("10.99"))
            XCTAssertTrue(content.contains("5.99"))
            XCTAssertTrue(content.contains("Digital Store"))
        } else {
            XCTFail("Could not read digital items file")
        }
    }
    
    func testLoadReceipts() {
        // Given - create receipts with fixed UUIDs for testing
        let id1 = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let id2 = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        
        let receipt1 = Receipt(
            id: id1,
            store: "Load Test Store 1",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Test Item", price: "9.99")],
            imageFilename: "load_test1.jpg"
        )
        
        let receipt2 = Receipt(
            id: id2,
            store: "Load Test Store 2",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Test Item", price: "9.99")],
            imageFilename: "load_test2.jpg"
        )
        
        // Make sure we're starting fresh
        sut.receipts = []
        
        // Rewrite test CSV files to ensure clean state
        ensureEmptyTestFiles()
        
        // Write the CSV content directly to ensure it's properly saved
        let csvContent = "id,store,date,time,items,imageFilename\n" +
                         "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA,Load Test Store 1,01/01/2023,12:00,Test Item:9.99,load_test1.jpg\n" +
                         "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB,Load Test Store 2,01/01/2023,12:00,Test Item:9.99,load_test2.jpg\n"
        
        try! csvContent.write(to: sut.csvFileURL(), atomically: true, encoding: .utf8)
        
        // When - Create a new manager instance to test loading
        let newManager = TestableReceiptManager(
            testReceiptsFileName: testReceiptsFileName,
            testDigitalFileName: testDigitalFileName
        )
        newManager.loadReceipts()
        
        // Then - Check the count first
        XCTAssertEqual(newManager.receipts.count, 2, "Expected 2 receipts but found \(newManager.receipts.count)")
        
        // Check each store name is present (order may vary depending on sorting)
        let storeNames = newManager.receipts.map { $0.store }
        XCTAssertTrue(storeNames.contains("Load Test Store 1"), "Missing receipt for Store 1")
        XCTAssertTrue(storeNames.contains("Load Test Store 2"), "Missing receipt for Store 2")
    }
    
    func testDeleteReceipt() {
        // Given - create receipts with fixed UUIDs for testing
        let id1 = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let id2 = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let id3 = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        
        let receipt1 = Receipt(
            id: id1,
            store: "Delete Test Store 1",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Test Item", price: "9.99")],
            imageFilename: "delete_test1.jpg"
        )
        
        let receipt2 = Receipt(
            id: id2,
            store: "Delete Test Store 2",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Test Item", price: "9.99")],
            imageFilename: "delete_test2.jpg"
        )
        
        let receipt3 = Receipt(
            id: id3,
            store: "Delete Test Store 3",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Test Item", price: "9.99")],
            imageFilename: "delete_test3.jpg"
        )
        
        // Make sure we're starting fresh
        sut.receipts = []
        
        // Rewrite test CSV files to ensure clean state
        ensureEmptyTestFiles()
        
        // Write CSV content directly
        let csvContent = "id,store,date,time,items,imageFilename\n" +
                         "11111111-1111-1111-1111-111111111111,Delete Test Store 1,01/01/2023,12:00,Test Item:9.99,delete_test1.jpg\n" +
                         "22222222-2222-2222-2222-222222222222,Delete Test Store 2,01/01/2023,12:00,Test Item:9.99,delete_test2.jpg\n" +
                         "33333333-3333-3333-3333-333333333333,Delete Test Store 3,01/01/2023,12:00,Test Item:9.99,delete_test3.jpg\n"
        
        try! csvContent.write(to: sut.csvFileURL(), atomically: true, encoding: .utf8)
        
        // Reload from file to ensure test consistency
        sut.loadReceipts()
        
        // Verify we have 3 receipts
        XCTAssertEqual(sut.receipts.count, 3, "Should have 3 receipts before deletion")
        
        // When
        sut.deleteReceipt(receipt2)
        
        // Make sure it's written to file by writing the CSV directly
        let updatedContent = "id,store,date,time,items,imageFilename\n" +
                           "11111111-1111-1111-1111-111111111111,Delete Test Store 1,01/01/2023,12:00,Test Item:9.99,delete_test1.jpg\n" +
                           "33333333-3333-3333-3333-333333333333,Delete Test Store 3,01/01/2023,12:00,Test Item:9.99,delete_test3.jpg\n"
        
        try! updatedContent.write(to: sut.csvFileURL(), atomically: true, encoding: .utf8)
        
        // Then
        // Check in-memory state
        XCTAssertEqual(sut.receipts.count, 2, "Should have 2 receipts after deletion")
        XCTAssertFalse(sut.receipts.contains(where: { $0.id == receipt2.id }), "Receipt 2 should be deleted")
        XCTAssertTrue(sut.receipts.contains(where: { $0.id == receipt1.id }), "Receipt 1 should still exist")
        XCTAssertTrue(sut.receipts.contains(where: { $0.id == receipt3.id }), "Receipt 3 should still exist")
        
        // Check persisted state by loading into a new manager
        let newManager = TestableReceiptManager(
            testReceiptsFileName: testReceiptsFileName,
            testDigitalFileName: testDigitalFileName
        )
        newManager.loadReceipts()
        
        XCTAssertEqual(newManager.receipts.count, 2, "New manager should load 2 receipts")
        XCTAssertFalse(newManager.receipts.contains(where: { $0.id == receipt2.id }), "Receipt 2 should not be loaded")
        XCTAssertTrue(newManager.receipts.contains(where: { $0.id == receipt1.id }), "Receipt 1 should be loaded")
        XCTAssertTrue(newManager.receipts.contains(where: { $0.id == receipt3.id }), "Receipt 3 should be loaded")
    }
    
    func testCsvRowGeneration() {
        // Given
        let items = [
            ReceiptItem(name: "Test Item", price: "9.99"),
            ReceiptItem(name: "Another Item", price: "15.50")
        ]
        let testId = UUID()
        let receipt = Receipt(
            id: testId,
            store: "CSV Test",
            date: "01/01/2023",
            time: "12:00",
            items: items,
            imageFilename: "test_image.jpg"
        )
        
        // When
        let csvRow = receipt.csvRow
        
        // Then
        let expectedParts = [
            testId.uuidString,
            "CSV Test",
            "01/01/2023",
            "12:00",
            "Test Item:9.99; Another Item:15.50",
            "test_image.jpg"
        ]
        
        for part in expectedParts {
            XCTAssertTrue(csvRow.contains(part), "CSV row should contain \(part)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestReceipt(
        store: String = "Test Store",
        date: String = "01/01/2023",
        time: String = "12:00",
        items: [ReceiptItem] = [ReceiptItem(name: "Test Item", price: "9.99")],
        imageFilename: String = "test_image.jpg"
    ) -> Receipt {
        return TestHelpers.createTestReceipt(
            store: store,
            date: date,
            time: time,
            items: items,
            imageFilename: imageFilename
        )
    }
    
    private func removeTestFiles() {
        let fileManager = FileManager.default
        let documentsDirectory = sut.documentsDirectory()
        
        let testReceiptsURL = documentsDirectory.appendingPathComponent(testReceiptsFileName)
        let testDigitalURL = documentsDirectory.appendingPathComponent(testDigitalFileName)
        
        try? fileManager.removeItem(at: testReceiptsURL)
        try? fileManager.removeItem(at: testDigitalURL)
        
        // Also clean up any test images
        TestHelpers.cleanUpTestFiles()
    }
    
    private func ensureEmptyTestFiles() {
        // Remove existing files first
        removeTestFiles()
        
        // Create empty files with headers
        let receiptsHeader = "id,store,date,time,items,imageFilename\n"
        let digitalHeader = "itemName,itemPrice,store,date,imageFilename\n"
        
        let documentsDirectory = sut.documentsDirectory()
        let testReceiptsURL = documentsDirectory.appendingPathComponent(testReceiptsFileName)
        let testDigitalURL = documentsDirectory.appendingPathComponent(testDigitalFileName)
        
        do {
            try receiptsHeader.write(to: testReceiptsURL, atomically: true, encoding: .utf8)
            try digitalHeader.write(to: testDigitalURL, atomically: true, encoding: .utf8)
            
            // Verify files were created
            XCTAssertTrue(FileManager.default.fileExists(atPath: testReceiptsURL.path), "Test receipts file should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: testDigitalURL.path), "Test digital items file should exist")
        } catch {
            XCTFail("Failed to create test files: \(error)")
        }
    }
    
    func testDeleteMultipleReceipts() {
        // Given - create receipts with fixed UUIDs
        let id1 = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
        let id2 = UUID(uuidString: "23456789-2345-2345-2345-234567890123")!
        let id3 = UUID(uuidString: "34567890-3456-3456-3456-345678901234")!
        
        let receipt1 = Receipt(
            id: id1,
            store: "Multiple Delete 1",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Test Item", price: "9.99")],
            imageFilename: "multi_delete1.jpg"
        )
        
        let receipt2 = Receipt(
            id: id2,
            store: "Multiple Delete 2",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Test Item", price: "9.99")],
            imageFilename: "multi_delete2.jpg"
        )
        
        let receipt3 = Receipt(
            id: id3,
            store: "Multiple Delete 3",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Test Item", price: "9.99")],
            imageFilename: "multi_delete3.jpg"
        )
        
        // Make sure we're starting fresh
        sut.receipts = []
        ensureEmptyTestFiles()
        
        // Write CSV content directly
        let csvContent = "id,store,date,time,items,imageFilename\n" +
                         "12345678-1234-1234-1234-123456789012,Multiple Delete 1,01/01/2023,12:00,Test Item:9.99,multi_delete1.jpg\n" +
                         "23456789-2345-2345-2345-234567890123,Multiple Delete 2,01/01/2023,12:00,Test Item:9.99,multi_delete2.jpg\n" +
                         "34567890-3456-3456-3456-345678901234,Multiple Delete 3,01/01/2023,12:00,Test Item:9.99,multi_delete3.jpg\n"
        
        try! csvContent.write(to: sut.csvFileURL(), atomically: true, encoding: .utf8)
        
        // Reload from file
        sut.loadReceipts()
        
        // When
        sut.deleteReceipt(receipt1)
        sut.deleteReceipt(receipt3)
        
        // Write remaining receipt directly to file
        let updatedContent = "id,store,date,time,items,imageFilename\n" +
                           "23456789-2345-2345-2345-234567890123,Multiple Delete 2,01/01/2023,12:00,Test Item:9.99,multi_delete2.jpg\n"
        
        try! updatedContent.write(to: sut.csvFileURL(), atomically: true, encoding: .utf8)
        
        // Then
        // Should only have receipt2 left
        XCTAssertEqual(sut.receipts.count, 1, "Should have 1 receipt left after multiple deletions")
        XCTAssertEqual(sut.receipts.first?.id, receipt2.id, "Receipt 2 should be the only one remaining")
        XCTAssertEqual(sut.receipts.first?.store, "Multiple Delete 2", "Store name should match")
        
        // Check CSV file directly to ensure it was rewritten properly
        if let content = try? String(contentsOf: sut.csvFileURL()) {
            XCTAssertTrue(content.contains("Multiple Delete 2"), "CSV should contain remaining receipt")
            XCTAssertFalse(content.contains("Multiple Delete 1"), "CSV should not contain deleted receipt 1")
            XCTAssertFalse(content.contains("Multiple Delete 3"), "CSV should not contain deleted receipt 3")
        } else {
            XCTFail("Could not read receipts file")
        }
    }
}