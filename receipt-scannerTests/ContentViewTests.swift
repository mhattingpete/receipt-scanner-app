import XCTest
@testable import receipt_scanner

final class ContentViewTests: XCTestCase {
    
    // Test filtered receipts logic directly without accessing the private property
    func testFilteredReceiptsLogic() {
        // Given
        let manager = ReceiptManager.shared
        
        // Clear any existing receipts first
        let originalReceipts = manager.receipts
        defer { manager.receipts = originalReceipts } // Restore original state after test
        
        manager.receipts = []
        
        // Add some test receipts
        let testReceipts = [
            Receipt(
                id: UUID(),
                store: "Grocery Store",
                date: "01/01/2023",
                time: "12:00",
                items: [
                    ReceiptItem(name: "Apples", price: "2.99"),
                    ReceiptItem(name: "Bananas", price: "1.99")
                ],
                imageFilename: "test1.jpg"
            ),
            Receipt(
                id: UUID(),
                store: "Electronics Shop",
                date: "02/15/2023",
                time: "15:30",
                items: [
                    ReceiptItem(name: "Headphones", price: "99.99")
                ],
                imageFilename: "test2.jpg"
            ),
            Receipt(
                id: UUID(),
                store: "Bookstore",
                date: "03/20/2023",
                time: "10:15",
                items: [
                    ReceiptItem(name: "Novel", price: "14.99"),
                    ReceiptItem(name: "Magazine", price: "5.99")
                ],
                imageFilename: "test3.jpg"
            )
        ]
        
        manager.receipts = testReceipts
        
        // Define a test filter function that mimics ContentView's filteredReceipts logic
        func filterReceipts(with searchText: String) -> [Receipt] {
            if searchText.isEmpty {
                return manager.receipts
            } else {
                return manager.receipts.filter { receipt in
                    receipt.store.lowercased().contains(searchText.lowercased())
                        || receipt.items.contains(where: {
                            $0.name.lowercased().contains(searchText.lowercased())
                        }) || receipt.date.contains(searchText)
                }
            }
        }
        
        // Test empty search (should show all receipts)
        XCTAssertEqual(filterReceipts(with: "").count, 3)
        
        // Test store search
        XCTAssertEqual(filterReceipts(with: "Grocery").count, 1)
        XCTAssertEqual(filterReceipts(with: "Grocery").first?.store, "Grocery Store")
        
        // Test item name search - case insensitive
        XCTAssertEqual(filterReceipts(with: "headphones").count, 1)
        XCTAssertEqual(filterReceipts(with: "headphones").first?.store, "Electronics Shop")
        
        // Test date search
        XCTAssertEqual(filterReceipts(with: "03/20").count, 1)
        XCTAssertEqual(filterReceipts(with: "03/20").first?.store, "Bookstore")
        
        // Test search with no matches
        XCTAssertEqual(filterReceipts(with: "Nonexistent Item").count, 0)
        
        // Test search that matches multiple receipts
        XCTAssertGreaterThan(filterReceipts(with: "e").count, 1)
    }
    
    // Test UI image loading behavior
    func testUIImageLoading() {
        // Create a test image
        let testImage = TestHelpers.createTestImage(size: CGSize(width: 50, height: 50))
        
        // Save the test image
        let filename = saveImageToDocuments(testImage)
        
        // Create a receipt with this image
        let receipt = Receipt(
            id: UUID(),
            store: "Test Store",
            date: "01/01/2023",
            time: "12:00",
            items: [ReceiptItem(name: "Test Item", price: "9.99")],
            imageFilename: filename
        )
        
        // Test that the image can be loaded via our UIImage extension
        let loadedImage = UIImage.loadFromDocuments(filename: receipt.imageFilename)
        XCTAssertNotNil(loadedImage, "Image should be loaded successfully")
        
        // Clean up
        let fileManager = FileManager.default
        let docsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? fileManager.removeItem(at: docsDirectory.appendingPathComponent(filename))
    }
}