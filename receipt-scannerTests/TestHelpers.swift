import XCTest
import SwiftUI
import UIKit
import Combine
import Foundation
import Vision
import VisionKit
@testable import receipt_scanner

/// TestHelpers provides utilities for common testing needs
class TestHelpers {
    
    /// Creates a test image with some basic content
    static func createTestImage(size: CGSize = CGSize(width: 200, height: 300)) -> UIImage {
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
            
            // Add some line items
            let items = [
                "Apple                $1.99",
                "Milk                 $3.49",
                "Bread                $2.99"
            ] as [NSString]
            
            let itemAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.darkGray
            ]
            
            for (index, item) in items.enumerated() {
                item.draw(at: CGPoint(x: 40, y: 100 + (index * 30)), withAttributes: itemAttributes)
            }
        }
    }
    
    /// Create a test receipt with custom parameters
    static func createTestReceipt(
        store: String = "Test Store",
        date: String = "01/01/2023",
        time: String = "12:00",
        items: [ReceiptItem] = [ReceiptItem(name: "Test Item", price: "9.99")],
        imageFilename: String = "test_image.jpg"
    ) -> Receipt {
        return Receipt(
            id: UUID(),
            store: store,
            date: date,
            time: time,
            items: items,
            imageFilename: imageFilename
        )
    }
    
    /// Clean up test files in documents directory
    static func cleanUpTestFiles(withPrefix prefix: String = "test_") {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: nil
            )
            
            for fileURL in fileURLs where fileURL.lastPathComponent.hasPrefix(prefix) {
                try? fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("Error cleaning up test files: \(error)")
        }
    }
}

extension XCTestCase {
    /// Wait for a specific duration during tests
    func wait(seconds: TimeInterval) {
        let expectation = XCTestExpectation(description: "Waiting")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: seconds + 0.5)
    }
}

// Helper extension for creating random colors in tests
extension UIColor {
    static func random() -> UIColor {
        return UIColor(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1),
            alpha: 1.0
        )
    }
}