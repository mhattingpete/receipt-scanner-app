import Foundation
import SwiftUI
import Combine

class ReceiptManager: ObservableObject {
    @Published var receipts: [Receipt] = []
    static let shared = ReceiptManager()
    let objectWillChange = ObservableObjectPublisher()
    
    // File names for data storage
    let receiptsFileName = "receipts.csv"
    let digitalFileName = "digital_items.csv"
    
    // Error types for receipt operations
    enum ReceiptError: Error {
        case fileOperationFailed(String)
        case parsingError(String)
        case invalidData(String)
        case deletionError(String)
    }
    
    init() {
        loadReceipts()
    }

    // MARK: - File System Helpers
    
    /// Returns the documents directory URL
    func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Returns the full path to the receipts CSV file
    func csvFileURL() -> URL {
        documentsDirectory().appendingPathComponent(receiptsFileName)
    }

    /// Returns the full path to the digital items CSV file
    func digitalCSVFileURL() -> URL {
        documentsDirectory().appendingPathComponent(digitalFileName)
    }
    
    /// Checks if the CSV files exist, creates them with headers if they don't
    func ensureCSVFilesExist() {
        let fileManager = FileManager.default
        let receiptsURL = csvFileURL()
        let digitalURL = digitalCSVFileURL()
        
        // Create receipts CSV if needed
        if !fileManager.fileExists(atPath: receiptsURL.path) {
            let header = "id,store,date,time,items,imageFilename\n"
            try? header.write(to: receiptsURL, atomically: true, encoding: .utf8)
        }
        
        // Create digital items CSV if needed
        if !fileManager.fileExists(atPath: digitalURL.path) {
            let header = "itemName,itemPrice,store,date,imageFilename\n"
            try? header.write(to: digitalURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Save Receipt
    func saveReceipt(_ receipt: Receipt) {
        // First add to memory collection
        if !receipts.contains(where: { $0.id == receipt.id }) {
            receipts.append(receipt)
        }
        
        let csvRow = receipt.csvRow
        let fileURL = csvFileURL()
        
        // Ensure directory and file exist
        ensureCSVFilesExist()
        
        do {
            // Append to the file
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                defer { fileHandle.closeFile() }
                
                fileHandle.seekToEndOfFile()
                if let data = csvRow.data(using: .utf8) {
                    fileHandle.write(data)
                    
                    // Ensure data is written to disk
                    if #available(iOS 13.0, *) {
                        try fileHandle.synchronize()
                    }
                }
            } else {
                throw ReceiptError.fileOperationFailed("Failed to open file for writing: \(fileURL.path)")
            }
            
            // Notify observers
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        } catch {
            print("Error saving receipt to CSV: \(error)")
        }
    }

    // MARK: - Save Digital Items
    func saveDigitalItems(from receipt: Receipt) {
        let fileURL = digitalCSVFileURL()
        
        // Ensure directory and file exist
        ensureCSVFilesExist()
        
        do {
            // Open file for appending
            guard let fileHandle = try? FileHandle(forWritingTo: fileURL) else {
                throw ReceiptError.fileOperationFailed("Could not open digital items file")
            }
            
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            
            // Prepare batch of rows to write at once (more efficient)
            var dataToWrite = Data()
            
            // For each item in the receipt, create a CSV row
            for item in receipt.items {
                let row = "\(item.name),\(item.price),\(receipt.store),\(receipt.date),\(receipt.imageFilename)\n"
                if let rowData = row.data(using: .utf8) {
                    dataToWrite.append(rowData)
                }
            }
            
            // Write all data at once
            if !dataToWrite.isEmpty {
                fileHandle.write(dataToWrite)
                
                // Flush the data to ensure it's written
                if #available(iOS 13.0, *) {
                    try fileHandle.synchronize()
                }
            }
        } catch {
            print("Error saving digital items to CSV: \(error)")
        }
    }

    // MARK: - Load Receipts
    func loadReceipts() {
        let fileURL = csvFileURL()
        
        // Ensure the file exists
        ensureCSVFilesExist()
        
        do {
            // Read file contents
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            var loadedReceipts: [Receipt] = []
            let rows = content.components(separatedBy: "\n")
            
            // Process each row (skip header)
            for row in rows.dropFirst() {
                if row.isEmpty { 
                    continue 
                }
                
                if let receipt = parseReceiptFromCSV(row) {
                    loadedReceipts.append(receipt)
                }
            }
            
            // Sort receipts by date (newest first)
            loadedReceipts.sort { receipt1, receipt2 in
                guard let components1 = receipt1.dateComponents,
                      let components2 = receipt2.dateComponents,
                      let date1 = Calendar.current.date(from: components1),
                      let date2 = Calendar.current.date(from: components2) else {
                    return false
                }
                return date1 > date2
            }
            
            // Update receipts and notify observers
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.receipts = loadedReceipts
                self.objectWillChange.send()
            }
        } catch {
            print("Error loading receipts from CSV: \(error)")
            // Initialize with empty array on error
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.receipts = []
                self.objectWillChange.send()
            }
        }
    }
    
    // Helper to parse a receipt from CSV row
    private func parseReceiptFromCSV(_ row: String) -> Receipt? {
        let columns = row.components(separatedBy: ",")
        
        guard columns.count >= 6 else { return nil }
        
        let id = UUID(uuidString: columns[0]) ?? UUID()
        let store = columns[1]
        let date = columns[2]
        let time = columns[3]
        let itemsRaw = columns[4]
        let imageFilename = columns[5]
        
        // Parse items
        let itemPairs = itemsRaw.components(separatedBy: ";").compactMap { ReceiptItem(fromCSV: $0) }
        
        return Receipt(
            id: id,
            store: store,
            date: date,
            time: time,
            items: itemPairs,
            imageFilename: imageFilename
        )
    }
    
    // MARK: - Delete Receipt
    func deleteReceipt(_ receipt: Receipt) {
        // 1. Delete from memory
        receipts.removeAll { $0.id == receipt.id }
        
        // 2. Delete image file if it exists
        deleteReceiptImage(receipt.imageFilename)
        
        // 3. Rewrite CSV files without this receipt
        rewriteReceiptsCSV()
        rewriteDigitalItemsCSV()
        
        // 4. Notify observers of the change
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    // Delete the receipt image file
    private func deleteReceiptImage(_ filename: String) {
        let fileManager = FileManager.default
        let imagePath = documentsDirectory().appendingPathComponent(filename).path
        
        if fileManager.fileExists(atPath: imagePath) {
            do {
                try fileManager.removeItem(atPath: imagePath)
            } catch {
                print("Error deleting receipt image: \(error)")
            }
        }
    }
    
    // Rewrite the receipts CSV file without the deleted receipt
    private func rewriteReceiptsCSV() {
        let fileURL = csvFileURL()
        
        // Start with header
        var csvContent = "id,store,date,time,items,imageFilename\n"
        
        // Add all receipts in memory
        for receipt in receipts {
            csvContent.append(receipt.csvRow)
        }
        
        // Write back to file
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error rewriting receipts CSV: \(error)")
        }
    }
    
    // Rewrite the digital items CSV file
    private func rewriteDigitalItemsCSV() {
        let fileURL = digitalCSVFileURL()
        
        // Start with header
        var csvContent = "itemName,itemPrice,store,date,imageFilename\n"
        
        // Add items from all receipts in memory
        for receipt in receipts {
            for item in receipt.items {
                let row = "\(item.name),\(item.price),\(receipt.store),\(receipt.date),\(receipt.imageFilename)\n"
                csvContent.append(row)
            }
        }
        
        // Write back to file
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error rewriting digital items CSV: \(error)")
        }
    }
}
