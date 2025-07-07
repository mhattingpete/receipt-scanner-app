// Optimized receipt scanning and parsing utilities
import SwiftUI
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

func recognizeText(in image: UIImage, completion: @escaping (String?) -> Void) {
    guard #available(iOS 18.2, *) else {
        recognizeTextWithVision(in: image, completion: completion)
        return
    }

    Task.detached {
        do {
            let text = try await FastVLMReader.recognize(image)
            await MainActor.run { completion(text) }
        } catch {
            print("FastVLM OCR failed:", error)
            // Fallback to Vision if needed
            recognizeTextWithVision(in: image, completion: completion)
        }
    }
}

// This file contains only the OCR and text parsing functionality
// Image handling has been moved to ImageHelpers.swift

/// Recognizes text from a given UIImage using Vision with improved accuracy.
private func recognizeTextWithVision(in image: UIImage, completion: @escaping (String?) -> Void) {
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
    let context = CIContext()
    let ciImage = CIImage(cgImage: image)
    
    // Step 1: Auto-adjust exposure and contrast
    let adjustedImage = autoAdjustContrast(ciImage)
    
    // Step 2: Noise reduction
    let denoisedImage = reduceNoise(adjustedImage)
    
    // Step 3: Edge enhancement for text clarity
    let sharpenedImage = enhanceEdges(denoisedImage)
    
    // Step 4: Binarization for high contrast text
    let binarizedImage = binarizeForOCR(sharpenedImage)
    
    // Convert back to CGImage
    if let processedCGImage = context.createCGImage(binarizedImage, from: binarizedImage.extent) {
        return processedCGImage
    }
    
    // Fallback to original if preprocessing fails
    return image
}

// MARK: - Image Preprocessing Helpers

/// Auto-adjusts contrast and exposure for better text visibility
private func autoAdjustContrast(_ image: CIImage) -> CIImage {
    // Auto enhance filter for general improvements
    let autoEnhance = CIFilter.colorControls()
    autoEnhance.inputImage = image
    autoEnhance.contrast = 1.2  // Slightly increase contrast
    autoEnhance.brightness = 0.1  // Slightly increase brightness
    autoEnhance.saturation = 0.8  // Reduce saturation to focus on text
    
    return autoEnhance.outputImage ?? image
}

/// Reduces camera noise while preserving text edges
private func reduceNoise(_ image: CIImage) -> CIImage {
    let noiseReduction = CIFilter.noiseReduction()
    noiseReduction.inputImage = image
    noiseReduction.noiseLevel = 0.02  // Light noise reduction to preserve text detail
    noiseReduction.sharpness = 0.4   // Maintain some sharpness
    
    return noiseReduction.outputImage ?? image
}

/// Enhances edges to make text clearer
private func enhanceEdges(_ image: CIImage) -> CIImage {
    let unsharpMask = CIFilter.unsharpMask()
    unsharpMask.inputImage = image
    unsharpMask.radius = 2.5      // Edge detection radius
    unsharpMask.intensity = 0.5   // Enhancement intensity
    
    return unsharpMask.outputImage ?? image
}

/// Converts image to high-contrast black and white for optimal OCR
private func binarizeForOCR(_ image: CIImage) -> CIImage {
    // First convert to grayscale
    let grayscale = CIFilter.photoEffectMono()
    grayscale.inputImage = image
    
    guard let grayImage = grayscale.outputImage else { return image }
    
    // Apply threshold to create high contrast
    let threshold = CIFilter.colorThreshold()
    threshold.inputImage = grayImage
    threshold.threshold = 0.5  // Adjust threshold for text clarity
    
    return threshold.outputImage ?? grayImage
}

/// Detects and corrects perspective distortion in receipt images
private func correctPerspective(_ image: CIImage) -> CIImage {
    // For now, return original image
    // Advanced implementation would use CIPerspectiveCorrection
    // after detecting receipt corners with vision framework
    return image
}

/// Detects receipt boundaries and crops to content area
private func cropToReceiptBounds(_ image: CIImage) -> CIImage {
    // For now, return original image
    // Advanced implementation would detect receipt edges
    // and crop to remove background
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

// MARK: - FastVLM JSON convenience
@available(iOS 18.2, *)
func recognizeReceiptJSON(
    in image: UIImage,
    completion: @escaping (FastVLMReader.ReceiptJSON?) -> Void
) {
    Task.detached {
        do {
            let receipt = try await FastVLMReader.recognizeJSON(image)
            await MainActor.run { completion(receipt) }
        } catch {
            print("FastVLM JSON recognition failed: \(error)")
            await MainActor.run { completion(nil) }
        }
    }
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
