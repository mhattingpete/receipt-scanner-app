import SwiftUI
import UIKit

// MARK: - Image Loading and Saving Helpers

extension UIImage {
    /// Loads an image from the Documents directory using the given filename.
    static func loadFromDocuments(filename: String) -> UIImage? {
        // Validate the filename isn't empty
        guard !filename.isEmpty else {
            print("Error: Empty filename provided to loadFromDocuments")
            return nil
        }
        
        // Get the documents directory URL
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask)[0]
        // Append the filename to create the full URL.
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // Check if file exists before attempting to load
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Error: File does not exist at path: \(fileURL.path)")
            return nil
        }
        
        // Load the image from this file.
        let image = UIImage(contentsOfFile: fileURL.path)
        
        if image == nil {
            print("Error: Failed to load image from: \(fileURL.path)")
        }
        
        return image
    }
    
    /// Saves the image to the Documents directory and returns the filename.
    func saveToDocuments(filename: String? = nil) -> String {
        // Generate a filename if one wasn't provided
        let fileName = filename ?? "image_\(UUID().uuidString).jpg"
        
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        // Create documents directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(
                at: documentsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("Warning: Could not create directory: \(error)")
        }
        
        // Convert to JPEG data with moderate compression
        if let data = self.jpegData(compressionQuality: 0.7) {
            do {
                try data.write(to: fileURL)
                print("Image saved to: \(fileURL.path)")
            } catch {
                print("Error saving image: \(error)")
            }
        } else {
            print("Error: Failed to convert image to JPEG data")
        }
        
        return fileName
    }
    
    /// Optimizes the image for storage as a receipt
    func optimizedForReceipt() -> UIImage {
        // Remove transparency if present
        let imageToProcess: UIImage
        if let cgImage = self.cgImage, cgImage.alphaInfo != .none {
            UIGraphicsBeginImageContextWithOptions(self.size, true, self.scale)
            self.draw(in: CGRect(origin: .zero, size: self.size))
            imageToProcess = UIGraphicsGetImageFromCurrentImageContext() ?? self
            UIGraphicsEndImageContext()
        } else {
            imageToProcess = self
        }
        
        return imageToProcess
    }
}

// MARK: - Convenience Functions

/// Saves the receipt image to the documents directory with optimized settings.
func saveImageToDocuments(_ image: UIImage) -> String {
    let fileName = "receipt_\(UUID().uuidString).jpg"
    let optimizedImage = image.optimizedForReceipt()
    return optimizedImage.saveToDocuments(filename: fileName)
}

// MARK: - Image View Helpers

struct FullScreenImageView: View {
    let image: UIImage?
    @Binding var isShowing: Bool
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let image = image {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    // Enable pinch to zoom functionality
                                }
                        )
                }
            } else {
                Text("Image not available")
                    .foregroundColor(.white)
            }
            
            VStack {
                HStack {
                    Button(action: {
                        isShowing = false
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                            .foregroundColor(.white)
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        isShowing = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing)
                }
                .padding(.top, 40)
                
                Spacer()
            }
        }
        .gesture(
            TapGesture(count: 2).onEnded { _ in
                // Double tap to zoom could be implemented here
            }
        )
    }
}
