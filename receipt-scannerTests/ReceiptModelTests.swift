import XCTest
@testable import receipt_scanner

final class ReceiptModelTests: XCTestCase {
    
    func testReceiptItemInitialization() {
        // Given
        let name = "Test Item"
        let price = "9.99"
        
        // When
        let item = ReceiptItem(name: name, price: price)
        
        // Then
        XCTAssertEqual(item.name, name, "Item name should match the provided value")
        XCTAssertEqual(item.price, price, "Item price should match the provided value")
    }
    
    func testReceiptInitialization() {
        // Given
        let id = UUID()
        let store = "Test Store"
        let date = "01/01/2023"
        let time = "12:00"
        let items = [
            ReceiptItem(name: "Item 1", price: "9.99"),
            ReceiptItem(name: "Item 2", price: "19.99")
        ]
        let imageFilename = "test_image.jpg"
        
        // When
        let receipt = Receipt(
            id: id,
            store: store,
            date: date,
            time: time,
            items: items,
            imageFilename: imageFilename
        )
        
        // Then
        XCTAssertEqual(receipt.id, id)
        XCTAssertEqual(receipt.store, store)
        XCTAssertEqual(receipt.date, date)
        XCTAssertEqual(receipt.time, time)
        XCTAssertEqual(receipt.items.count, 2)
        XCTAssertEqual(receipt.items[0].name, "Item 1")
        XCTAssertEqual(receipt.items[0].price, "9.99")
        XCTAssertEqual(receipt.items[1].name, "Item 2")
        XCTAssertEqual(receipt.items[1].price, "19.99")
        XCTAssertEqual(receipt.imageFilename, imageFilename)
    }
    
    func testReceiptCsvRow() {
        // Given
        let id = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
        let receipt = Receipt(
            id: id,
            store: "CSV Test",
            date: "01/01/2023",
            time: "12:00",
            items: [
                ReceiptItem(name: "Item 1", price: "9.99"),
                ReceiptItem(name: "Item 2", price: "19.99")
            ],
            imageFilename: "test_image.jpg"
        )
        
        // When
        let csvRow = receipt.csvRow
        
        // Then
        let expectedRow = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F,CSV Test,01/01/2023,12:00,Item 1:9.99; Item 2:19.99,test_image.jpg\n"
        XCTAssertEqual(csvRow, expectedRow)
    }
    
    func testEmptyReceiptItems() {
        // Given
        let testId = UUID(uuidString: "A621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
        let receipt = Receipt(
            id: testId,
            store: "Empty Store",
            date: "01/01/2023",
            time: "12:00",
            items: [],
            imageFilename: "empty.jpg"
        )
        
        // Then
        XCTAssertEqual(receipt.items.count, 0)
        
        // The CSV row should handle empty items correctly
        let csvRow = receipt.csvRow
        let expectedEmptyRow = "A621E1F8-C36C-495A-93FC-0C247A3E6E5F,Empty Store,01/01/2023,12:00,,empty.jpg\n"
        XCTAssertEqual(csvRow, expectedEmptyRow, "CSV row should match expected format")
    }
    
    func testReceiptWithSpecialCharacters() {
        // Given
        let testId = UUID(uuidString: "B621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
        let receipt = Receipt(
            id: testId,
            store: "Store, with, commas",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Item: with colon", price: "9.99")],
            imageFilename: "special_chars.jpg"
        )
        
        // When
        let csvRow = receipt.csvRow
        
        // Then
        // The CSV format should handle the special characters
        let expectedRow = "B621E1F8-C36C-495A-93FC-0C247A3E6E5F,Store, with, commas,01/01/2023,12:00,Item: with colon:9.99,special_chars.jpg\n"
        XCTAssertEqual(csvRow, expectedRow, "CSV row with special characters should match expected format")
    }
    
    func testCodable() {
            // Given - Use a fixed UUID for deterministic testing
            let testId = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
            let receipt = Receipt(
                id: testId,
                store: "Codable Test",
                date: "01/01/2023",
                time: "12:00",
                items: [
                    ReceiptItem(name: "Encode Item", price: "9.99")
                ],
                imageFilename: "encode.jpg"
            )
        
            // When - Encode to JSON
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(receipt)
            
                // Then - Decode back and verify
                let decoder = JSONDecoder()
                let decodedReceipt = try decoder.decode(Receipt.self, from: data)
            
                XCTAssertEqual(decodedReceipt.id.uuidString, "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
                XCTAssertEqual(decodedReceipt.store, "Codable Test")
                XCTAssertEqual(decodedReceipt.date, "01/01/2023")
                XCTAssertEqual(decodedReceipt.time, "12:00")
                XCTAssertEqual(decodedReceipt.items.count, 1)
                XCTAssertEqual(decodedReceipt.items[0].name, "Encode Item")
                XCTAssertEqual(decodedReceipt.items[0].price, "9.99")
                XCTAssertEqual(decodedReceipt.imageFilename, "encode.jpg")
            } catch {
                XCTFail("Failed to encode/decode Receipt: \(error)")
            }
        }
}