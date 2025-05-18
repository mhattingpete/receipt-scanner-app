import XCTest
@testable import receipt_scanner

final class receipt_scannerTests: XCTestCase {
    
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
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up any test files
        TestHelpers.cleanUpTestFiles()
    }
    
    func testReceiptCreationAndParsing() {
        // Test the basic workflow of creating and parsing a receipt
        
        // 1. Create sample receipt data
        let store = "Test Market"
        let date = "05/15/2023"
        let time = "10:30"
        let items = [
            ReceiptItem(name: "Apples", price: "2.99"),
            ReceiptItem(name: "Milk", price: "3.49")
        ]
        
        // Create a receipt
        let receipt = TestHelpers.createTestReceipt(
            store: store,
            date: date,
            time: time,
            items: items
        )
        
        // 3. Verify receipt properties
        XCTAssertEqual(receipt.store, "Test Market")
        XCTAssertEqual(receipt.date, "05/15/2023")
        XCTAssertEqual(receipt.items.count, 2)
        XCTAssertEqual(receipt.items[0].name, "Apples")
        XCTAssertEqual(receipt.items[1].price, "3.49")
        
        // 4. Test CSV conversion
        let csvRow = receipt.csvRow
        XCTAssertTrue(csvRow.contains("Test Market"))
        XCTAssertTrue(csvRow.contains("05/15/2023"))
        XCTAssertTrue(csvRow.contains("10:30"))
        XCTAssertTrue(csvRow.contains("Apples:2.99"))
        XCTAssertTrue(csvRow.contains("Milk:3.49"))
    }
    
    func testReceiptTextParsing() {
        // Test the text parsing functionality
        
        let sampleText = """
        GROCERY MART
        123 Main Street
        05/20/2023 14:30
        
        Bananas         1.99
        Bread           3.49
        Chicken         8.99
        """
        
        let (store, date, time, items) = parseReceiptText(sampleText)
        
        XCTAssertEqual(store, "GROCERY MART")
        XCTAssertEqual(date, "05/20/2023")
        XCTAssertEqual(time, "14:30")
        XCTAssertEqual(items.count, 3)
        
        if items.count == 3 {
            XCTAssertEqual(items[0].name, "Bananas")
            XCTAssertEqual(items[0].price, "1.99")
            XCTAssertEqual(items[1].name, "Bread")
            XCTAssertEqual(items[1].price, "3.49")
            XCTAssertEqual(items[2].name, "Chicken")
            XCTAssertEqual(items[2].price, "8.99")
        }
    }
    
    func testImageHandling() {
        // Create a test image
        let testImage = TestHelpers.createTestImage(size: CGSize(width: 100, height: 100))
        
        // Save the image
        let filename = saveImageToDocuments(testImage)
        
        // Verify file exists
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path))
        
        // Load the image
        let loadedImage = UIImage.loadFromDocuments(filename: filename)
        XCTAssertNotNil(loadedImage)
        
        // Clean up
        try? fileManager.removeItem(at: fileURL)
    }
    
    func testReceiptManagerBasics() {
        // Create a test-specific manager with unique filenames
        let testUUID = UUID().uuidString
        let testFileName = "test_receipts_\(testUUID).csv"
        let testDigitalFileName = "test_digital_\(testUUID).csv"
        
        let manager = TestableReceiptManager(
            testReceiptsFileName: testFileName,
            testDigitalFileName: testDigitalFileName
        )
        
        // Initial state should be empty
        XCTAssertEqual(manager.receipts.count, 0)
        
        // Add a receipt
        let receipt = Receipt(
            id: UUID(),
            store: "Test Store",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Test Item", price: "9.99")],
            imageFilename: "test.jpg"
        )
        
        manager.saveReceipt(receipt)
        
        // Should now have one receipt
        XCTAssertEqual(manager.receipts.count, 1)
        XCTAssertEqual(manager.receipts[0].store, "Test Store")
        
        // Clean up
        let fileManager = FileManager.default
        let docsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? fileManager.removeItem(at: docsDirectory.appendingPathComponent(testFileName))
        try? fileManager.removeItem(at: docsDirectory.appendingPathComponent(testDigitalFileName))
    }
}