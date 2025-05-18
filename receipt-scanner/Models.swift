import Foundation
import SwiftUI
import UIKit

// Define a new struct for individual receipt items.
struct ReceiptItem: Identifiable, Codable, Equatable {
    var id = UUID()
    let name: String
    let price: String
    
    // Convenience property to get numeric value with fallbacks
    var numericPrice: Double {
        // Try to convert price string to Double
        return Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    }
    
    // CSV representation for storage
    var csvRepresentation: String {
        return "\(name):\(price)"
    }
    
    // Initialize from parts
    init(name: String, price: String) {
        self.name = name
        self.price = price
    }
    
    // Initialize from CSV representation
    init?(fromCSV string: String) {
        let parts = string.components(separatedBy: ":")
        guard parts.count == 2 else { return nil }
        self.name = parts[0].trimmingCharacters(in: .whitespaces)
        self.price = parts[1].trimmingCharacters(in: .whitespaces)
    }
}

// The main Receipt model
struct Receipt: Identifiable, Codable, Equatable {
    let id: UUID
    var store: String
    var date: String
    var time: String
    var items: [ReceiptItem]
    var imageFilename: String
    
    // Computed total cost of all items
    var total: Double {
        return items.reduce(0) { $0 + $1.numericPrice }
    }
    
    // Date helper for sorting
    var dateComponents: DateComponents? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        guard let date = formatter.date(from: self.date) else { return nil }
        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }

    // Helper computed property for CSV row
    var csvRow: String {
        let itemsString = items.map { $0.csvRepresentation }.joined(separator: "; ")
        return "\(id.uuidString),\(store),\(date),\(time),\(itemsString),\(imageFilename)\n"
    }
    
    // Helper for creating new receipts
    static func create(store: String, date: String, time: String, items: [ReceiptItem], imageFilename: String) -> Receipt {
        return Receipt(
            id: UUID(),
            store: store,
            date: date,
            time: time,
            items: items,
            imageFilename: imageFilename
        )
    }
}