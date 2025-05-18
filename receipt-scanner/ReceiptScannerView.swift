import SwiftUI
import UIKit
import Vision
import VisionKit
import Combine

struct ReceiptScannerView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var scannedImages: [UIImage]?
    @State private var isShowingScanner = false
    @State private var isProcessing = false
    @State private var showSavedConfirmation = false
    @State private var processingError: String? = nil
    @ObservedObject private var receiptManager = ReceiptManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Preview area
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .background(Color.gray.opacity(0.05))
                        .frame(height: 280)
                
                    if let uiImage = scannedImages?.first {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 250)
                            .cornerRadius(8)
                            .onTapGesture {
                                // If we have an image and tap it, show a preview
                                if let image = scannedImages?.first {
                                    // Save image temporarily if needed
                                    _ = saveImageToDocuments(image)
                                }
                            }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Tap \"Scan Receipt\" to begin")
                                .foregroundColor(.gray)
                         }
                    }
                }
                .padding(.horizontal)
                
                // Processing or confirmation
                if isProcessing {
                    ProgressView("Processing receipt text...")
                        .padding()
                } else if let error = processingError {
                    Text(error)
                        .foregroundColor(.orange)
                        .padding()
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        isShowingScanner = true
                        showSavedConfirmation = false
                    }) {
                        Label("Scan Receipt", systemImage: "doc.text.viewfinder")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isProcessing)
                    
                    if let image = scannedImages?.first, !isProcessing {
                        Button(action: {
                            saveScannedReceipt(image)
                        }) {
                            Label("Save Receipt", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitle("Scan Receipt", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { 
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $isShowingScanner) {
                DocumentScannerView { pages in
                    isShowingScanner = false
                    if let images = pages, !images.isEmpty {
                        scannedImages = images
                    }
                }
            }
            .alert(isPresented: $showSavedConfirmation) {
                Alert(
                    title: Text("Receipt Saved"),
                    message: Text(processingError != nil 
                        ? "Image saved but text recognition failed. Try again or manually enter details."
                        : "The receipt has been successfully saved."),
                    dismissButton: .default(Text("OK")) {
                        // Dismiss after ensuring data is refreshed
                        DispatchQueue.main.async {
                            receiptManager.loadReceipts()
                            receiptManager.objectWillChange.send()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
        }
    }

    // Save the scanned receipt
    private func saveScannedReceipt(_ image: UIImage) {
        isProcessing = true
        
        // Run OCR on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // First save the image
            let imageFilename = saveImageToDocuments(image)
            
            // Then run OCR
            recognizeText(in: image) { text in
                DispatchQueue.main.async {
                    if let text = text {
                        // Process recognized text
                        let (store, date, time, items) = parseReceiptText(text)
                        
                        // Create and save receipt
                        let newReceipt = Receipt(
                            id: UUID(),
                            store: store,
                            date: date,
                            time: time,
                            items: items,
                            imageFilename: imageFilename)
                        
                        // Save receipt data
                        ReceiptManager.shared.saveReceipt(newReceipt)
                        ReceiptManager.shared.saveDigitalItems(from: newReceipt)
                        
                        // Update UI
                        self.isProcessing = false
                        self.showSavedConfirmation = true
                    } else {
                        // Handle OCR failure but still save the image
                        self.isProcessing = false
                        self.processingError = "Could not recognize text, but image was saved."
                        self.showSavedConfirmation = true
                    }
                }
            }
        }
    }
}