import XCTest
@testable import receipt_scanner
import UIKit
import SwiftUI

final class UIImageExtensionTests: XCTestCase {
    
    func testSaveAndLoadImage() {
        // Given - Create a test image
        let testImage = TestHelpers.createTestImage(size: CGSize(width: 100, height: 100))
        
        // When - Save the image to documents
        let filename = "test_image_\(UUID().uuidString).jpg"
        let savedFilename = saveImageToDocuments(testImage)
        
        // Then - Verify the image was saved
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(savedFilename)
        
        XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path), "Image file should exist")
        
        // When - Load the image back
        let loadedImage = UIImage.loadFromDocuments(filename: savedFilename)
        
        // Then - Verify the image was loaded
        XCTAssertNotNil(loadedImage, "Should be able to load the saved image")
        
        // Clean up
        try? fileManager.removeItem(at: fileURL)
    }
    
    func testLoadNonExistentImage() {
        // When - Try to load an image that doesn't exist
        let loadedImage = UIImage.loadFromDocuments(filename: "nonexistent_image.jpg")
        
        // Then - The result should be nil
        XCTAssertNil(loadedImage, "Loading non-existent image should return nil")
    }
    
    func testSaveAndLoadMultipleImages() {
        // Given - Create test images
        let filenames: [String] = (0..<3).map { _ in
            // Use TestHelpers to create a test image
            let testImage = TestHelpers.createTestImage(size: CGSize(width: 50, height: 50))
            
            // Save the image and return filename
            return saveImageToDocuments(testImage)
        }
        
        // Clean up the files after verification
        defer {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            for filename in filenames {
                try? fileManager.removeItem(at: documentsDirectory.appendingPathComponent(filename))
            }
        }
        
        // When/Then - Verify all images can be loaded
        for filename in filenames {
            let loadedImage = UIImage.loadFromDocuments(filename: filename)
            XCTAssertNotNil(loadedImage, "Should be able to load the saved image: \(filename)")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up any test files created
        TestHelpers.cleanUpTestFiles()
    }
}