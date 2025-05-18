// Optimized receipt scanning and parsing utilities
import SwiftUI
import UIKit
import Vision

// This file contains only the OCR and text parsing functionality
// Image handling has been moved to ImageHelpers.swift

/// Recognizes text from a given UIImage using Vision with improved accuracy.
func recognizeText(in image: UIImage, completion: @escaping (String?) -> Void) {
    guard let cgImage = image.cgImage else {
        print("Error: Failed to get CGImage from UIImage")
        completion(nil)
        return
    }

    // Pre-process the image if needed for better OCR results
    let processedImage = preprocessImageForOCR(cgImage)

    // Create text recognition request
    let request = VNRecognizeTextRequest { request, error in
        if let error = error {
            print("Text recognition failed with error: \(error)")
            completion(nil)
            return
        }

        if let observations = request.results as? [VNRecognizedTextObservation] {
            // Get multiple candidates per observation for better accuracy
            let recognizedStrings = observations.compactMap { observation -> String? in
                // Get top 3 candidates and pick the most likely one based on confidence
                let candidates = observation.topCandidates(3)
                return candidates.first?.string
            }

            // Join lines with newline
            let recognizedText = recognizedStrings.joined(separator: "\n")
            completion(recognizedText)
        } else {
            completion(nil)
        }
    }

    // Configure the request for optimal receipt recognition
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    // Use a compatible revision for iOS 18.4
    if #available(iOS 16.0, *) {
        request.revision = VNRecognizeTextRequestRevision3
    } else {
        request.revision = VNRecognizeTextRequestRevision1
    }

    // Create handler and perform request
    let requestHandler = VNImageRequestHandler(cgImage: processedImage, options: [:])

    DispatchQueue.global(qos: .userInitiated).async {
        do {
            try requestHandler.perform([request])
        } catch {
            print("Error performing OCR: \(error)")
            completion(nil)
        }
    }
}

// Preprocesses the image to improve OCR accuracy
private func preprocessImageForOCR(_ image: CGImage) -> CGImage {
    // For now, just return the original image
    // Future enhancements could include:
    // - Contrast enhancement
    // - Deskewing
    // - Noise reduction
    // - Binarization for text clarity
    return image
}

/// Parses the recognized text to extract receipt details with improved accuracy.
func parseReceiptText(_ text: String) -> (
    store: String, date: String, time: String, items: [ReceiptItem]
) {
    // Default values
    var store = "Unknown Store"
    var date = "Unknown Date"
    var time = "Unknown Time"
    var items: [ReceiptItem] = []

    // Clean up text and split into lines, ignoring empty lines
    let cleanedText = text.replacingOccurrences(of: "\r", with: "")
    let lines = cleanedText.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    // Extract store name (typically first non-empty line)
    if let firstLine = lines.first, !firstLine.isEmpty {
        // Handle common prefixes that might appear before the store name
        let storePrefixes = ["RECEIPT", "INVOICE", "WELCOME TO", "THANK YOU FOR SHOPPING AT"]
        var storeName = firstLine

        for prefix in storePrefixes {
            if storeName.uppercased().hasPrefix(prefix) {
                storeName = storeName.dropFirst(prefix.count).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                break
            }
        }

        store = storeName
    }

    // Enhanced patterns for date and time extraction with multiple formats
    let datePatterns = [
        #"(\d{1,2}[\/-]\d{1,2}[\/-]\d{2,4})"#,  // MM/DD/YYYY or DD/MM/YYYY
        #"(\d{1,2}[\/-]\d{1,2}[\/-]\d{2})"#,  // MM/DD/YY or DD/MM/YY
        #"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},?\s+\d{4}"#,  // Month DD, YYYY
        #"\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{4}"#,  // DD Month YYYY
    ]

    let timePatterns = [
        #"(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[APMapm]{2})?)"#,  // HH:MM(:SS) (AM/PM)
        #"(\d{1,2}[h]\d{2}(?:min)?)"#,  // European format: 14h30
    ]

    // Look for date in each line
    for line in lines {
        for pattern in datePatterns {
            if let range = line.range(of: pattern, options: .regularExpression) {
                date = String(line[range])
                break
            }
        }
        if date != "Unknown Date" { break }
    }

    // Look for time in each line
    for line in lines {
        for pattern in timePatterns {
            if let range = line.range(of: pattern, options: .regularExpression) {
                time = String(line[range])
                break
            }
        }
        if time != "Unknown Time" { break }
    }

    // Enhanced item pattern detection with multiple formats
    let itemPatterns = [
        // Format: Item name followed by price (with optional currency symbol)
        #"^(.*?)\s+(\$?\d+(?:[.,]\d+)?)(?:\s*\w{0,2})?\s*$"#,

        // Format: Item with quantity x price
        #"^(.*?)\s+(\d+)\s*[xX]\s*(\$?\d+(?:[.,]\d+)?)\s*=?\s*(\$?\d+(?:[.,]\d+)?)"#,

        // Format: Item with just price at the end (flexible whitespace)
        #"^(.*?)(?:\s{2,}|\t)(\$?\d+(?:[.,]\d+)?)\s*$"#,
    ]

    // Detect which part of receipt has items (usually after "ITEMS" or similar headings)
    var processingItems = false
    var potentialTotalLine = -1

    for (index, line) in lines.enumerated() {
        let uppercaseLine = line.uppercased()

        // Check for section markers
        if uppercaseLine.contains("ITEM") || uppercaseLine.contains("DESCRIPTION")
            || uppercaseLine.contains("QTY")
        {
            processingItems = true
            continue
        }

        // Check for total markers to know when to stop processing items
        if uppercaseLine.contains("TOTAL") || uppercaseLine.contains("SUBTOTAL")
            || uppercaseLine.contains("AMOUNT")
        {
            potentialTotalLine = index
            processingItems = false
        }

        // Only process lines that might contain items
        if processingItems || potentialTotalLine == -1 {
            // Try each pattern
            for pattern in itemPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(location: 0, length: line.utf16.count)

                    if let match = regex.firstMatch(in: line, options: [], range: range) {
                        if match.numberOfRanges >= 3 {
                            // Basic pattern: item name and price
                            if let itemRange = Range(match.range(at: 1), in: line),
                                let priceRange = Range(match.range(at: 2), in: line)
                            {

                                let itemName = String(line[itemRange]).trimmingCharacters(
                                    in: .whitespacesAndNewlines)
                                var price = String(line[priceRange])

                                // Clean up price: remove currency symbols and standardize decimal separator
                                price = price.replacingOccurrences(of: "$", with: "")
                                price = price.replacingOccurrences(of: ",", with: ".")

                                // Filter out common false positives (like dates mistaken for items)
                                if !itemName.isEmpty && !price.isEmpty && !isLikelyDate(itemName)
                                    && Double(price) != nil
                                {
                                    items.append(ReceiptItem(name: itemName, price: price))
                                }

                                break  // Found a match for this line, move to next line
                            }
                        } else if match.numberOfRanges >= 5 {
                            // Quantity x price pattern
                            // Process according to the specific pattern...
                        }
                    }
                }
            }
        }
    }

    return (store, date, time, items)
}

// Helper to detect if a string looks like a date (to avoid false positive items)
private func isLikelyDate(_ str: String) -> Bool {
    let datePatterns = [
        #"\d{1,2}[\/-]\d{1,2}[\/-]\d{2,4}"#,
        #"\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"#,
    ]

    for pattern in datePatterns {
        if str.range(of: pattern, options: .regularExpression) != nil {
            return true
        }
    }
    return false
}

// Note: Image saving functionality has been moved to ImageHelpers.swift
// The saveImageToDocuments() function is now imported from there
