import SwiftUI
import Combine
import UIKit

@main
struct ReceiptScannerApp: App {
    // Initialize receipt manager on app start
    @StateObject private var manager = ReceiptManager.shared
    
    // Check if running in UI testing mode
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-Testing")
    }
    
    init() {
        // Setup test data for UI testing
        if isUITesting {
            setupTestData()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager)
                .onAppear {
                    // Ensure receipts are loaded when app launches
                    manager.loadReceipts()
                }
        }
    }
    
    // Creates sample receipts for UI testing
    private func setupTestData() {
        // Clear existing receipts first
        manager.receipts = []
        
        // Create test images first
        let testImage1 = createTestImage(size: CGSize(width: 300, height: 500))
        let testImage2 = createTestImage(size: CGSize(width: 300, height: 500))
        
        // Save images to get filenames
        let filename1 = saveImageToDocuments(testImage1)
        let filename2 = saveImageToDocuments(testImage2)
        
        // Create test receipts with actual image files
        let testReceipt1 = Receipt(
            id: UUID(),
            store: "Test Grocery Store",
            date: "01/01/2023",
            time: "12:00",
            items: [
                ReceiptItem(name: "Apples", price: "2.99"),
                ReceiptItem(name: "Bananas", price: "1.99")
            ],
            imageFilename: filename1
        )
        
        let testReceipt2 = Receipt(
            id: UUID(),
            store: "Test Electronics Shop",
            date: "02/15/2023",
            time: "15:30",
            items: [
                ReceiptItem(name: "Headphones", price: "99.99")
            ],
            imageFilename: filename2
        )
        
        // Save the test receipts
        manager.saveReceipt(testReceipt1)
        manager.saveReceipt(testReceipt2)
    }
    
    // Creates a simple test image
    private func createTestImage(size: CGSize) -> UIImage {
        // Use UIGraphicsImageRenderer for better compatibility with newer iOS versions
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Draw a white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add text to simulate receipt
            let text = "Test Receipt" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            text.draw(at: CGPoint(x: 50, y: 50), withAttributes: attributes)
        }
    }
}
