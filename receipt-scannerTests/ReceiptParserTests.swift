import XCTest
@testable import receipt_scanner

final class ReceiptParserTests: XCTestCase {
    
    // Test parsing receipt text with valid data
    func testParseReceiptText() {
        // Setup sample receipt text
        let sampleText = """
        Grocery Store
        123 Main St
        03/15/2023 14:30
        
        Apples    5.99
        Milk      3.49
        Bread     2.99
        """
        
        // Call the function
        let (store, date, time, items) = parseReceiptText(sampleText)
        
        // Verify results
        XCTAssertEqual(store, "Grocery Store")
        XCTAssertEqual(date, "03/15/2023")
        XCTAssertEqual(time, "14:30")
        XCTAssertEqual(items.count, 3)
        
        // Check specific items
        XCTAssertEqual(items[0].name, "Apples")
        XCTAssertEqual(items[0].price, "5.99")
        XCTAssertEqual(items[1].name, "Milk")
        XCTAssertEqual(items[1].price, "3.49")
        XCTAssertEqual(items[2].name, "Bread")
        XCTAssertEqual(items[2].price, "2.99")
    }
    
    // Test parsing receipt with comma-based decimal
    func testParseReceiptWithCommaDecimal() {
        let sampleText = """
        Euro Store
        04/20/2023
        
        Coffee     3,75
        Croissant  2,50
        """
        
        let (store, date, _, items) = parseReceiptText(sampleText)
        
        XCTAssertEqual(store, "Euro Store")
        XCTAssertEqual(date, "04/20/2023")
        XCTAssertEqual(items.count, 2)
        
        // Check that commas are replaced with periods
        XCTAssertEqual(items[0].name, "Coffee")
        XCTAssertEqual(items[0].price, "3.75")
        XCTAssertEqual(items[1].name, "Croissant")
        XCTAssertEqual(items[1].price, "2.50")
    }
    
    // Test parsing receipt with minimal information
    func testParseReceiptMinimalInfo() {
        let sampleText = "Corner Shop"
        
        let (store, date, time, items) = parseReceiptText(sampleText)
        
        XCTAssertEqual(store, "Corner Shop")
        XCTAssertEqual(date, "Unknown Date")
        XCTAssertEqual(time, "Unknown Time")
        XCTAssertEqual(items.count, 0)
    }
    
    // Test parsing receipt with different date formats
    func testParseReceiptDifferentDateFormats() {
        let dateFormats = [
            "05/10/2023",
            "5-10-2023",
            "05/10/23"
        ]
        
        for dateFormat in dateFormats {
            let sampleText = "Store\n\(dateFormat)"
            let (_, date, _, _) = parseReceiptText(sampleText)
            XCTAssertEqual(date, dateFormat)
        }
    }
    
    // Test parsing receipt with different time formats
    func testParseReceiptDifferentTimeFormats() {
        let timeFormats = [
            "14:30",
            "2:30PM",
            "2:30 PM"
        ]
        
        for timeFormat in timeFormats {
            let sampleText = "Store\n\(timeFormat)"
            let (_, _, time, _) = parseReceiptText(sampleText)
            XCTAssertEqual(time, timeFormat)
        }
    }
    
    // Test parsing receipt with real-world formatting
    func testParseReceiptRealWorldFormat() {
        let sampleText = """
        MEGA MART
        LOCATION: 123 SHOPPING LANE
        DATE: 07/15/2023  TIME: 16:45
        
        ITEM                  PRICE
        -------------------------------
        Cereal                 4.99
        Orange Juice           3.29  
        Paper Towels          12.49 EA
        Batteries              8.99
        
        SUBTOTAL:             29.76
        TAX:                   2.38
        TOTAL:                32.14
        """
        
        let (store, date, time, items) = parseReceiptText(sampleText)
        
        XCTAssertEqual(store, "MEGA MART")
        XCTAssertEqual(date, "07/15/2023")
        XCTAssertEqual(time, "16:45")
        
        // Should identify the 4 product items but not the totals
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[0].name, "Cereal")
        XCTAssertEqual(items[0].price, "4.99")
        XCTAssertEqual(items[3].name, "Batteries")
        XCTAssertEqual(items[3].price, "8.99")
    }
}