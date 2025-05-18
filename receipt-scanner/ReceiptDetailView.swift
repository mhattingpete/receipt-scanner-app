import SwiftUI
import UIKit

struct ReceiptDetailView: View {
    var receipt: Receipt
    @State private var uiImage: UIImage? = nil
    @State private var isShowingFullImage = false
    @State private var imageScale: CGFloat = 1.0
    @State private var selectedTab = 0
    
    var formattedTotal: String {
        return String(format: "%.2f", receipt.total)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Receipt header with store and date info
                VStack(alignment: .leading, spacing: 8) {
                    Text(receipt.store)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label(receipt.date, systemImage: "calendar")
                        Spacer()
                        Label(receipt.time, systemImage: "clock")
                    }
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    
                    Divider()
                }
                .padding(.horizontal)
                
                // Receipt image thumbnail (tappable)
                ZStack(alignment: .bottomTrailing) {
                    if let image = uiImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(12)
                            .shadow(radius: 3)
                            .onTapGesture {
                                isShowingFullImage = true
                            }
                        
                        // Expand icon
                        Button(action: {
                            isShowingFullImage = true
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .padding(8)
                    } else {
                        // Loading or placeholder state
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding(.bottom, 4)
                            Text("Loading image...")
                                .foregroundColor(.gray)
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                
                // Items list section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    ForEach(receipt.items) { item in
                        HStack {
                            Text(item.name)
                                .font(.subheadline)
                            Spacer()
                            Text("$\(item.price)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
                        
                        Divider()
                    }
                    
                    // Total amount
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text("$\(formattedTotal)")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationBarTitle(Text(receipt.store), displayMode: .inline)
        .navigationBarItems(trailing: shareButton)
        .onAppear {
            // Load the image using your helper extension on a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                let image = UIImage.loadFromDocuments(filename: receipt.imageFilename)
                DispatchQueue.main.async {
                    self.uiImage = image
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingFullImage) {
            FullScreenImageView(image: uiImage, isShowing: $isShowingFullImage)
        }
    }
    
    private var shareButton: some View {
        Button(action: {
            shareReceipt()
        }) {
            Image(systemName: "square.and.arrow.up")
        }
    }
    
    private func shareReceipt() {
        // Create text summary of receipt
        var text = "Receipt from \(receipt.store)\n"
        text += "Date: \(receipt.date) \(receipt.time)\n\n"
        text += "Items:\n"
        
        for item in receipt.items {
            text += "• \(item.name): $\(item.price)\n"
        }
        
        text += "\nTotal: $\(formattedTotal)"
        
        // Share text and image
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController 
        else { return }
        
        let activityItems: [Any] = [text] + (uiImage.map { [$0] } ?? [])
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        rootViewController.present(activityVC, animated: true)
    }
}



struct ReceiptDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy receipt for previewing
        let dummyReceipt = Receipt(
            id: UUID(),
            store: "Dummy Store",
            date: "01/01/2020",
            time: "12:00",
            items: [
                ReceiptItem(name: "Item A", price: "9.99"),
                ReceiptItem(name: "Item B", price: "19.99"),
                ReceiptItem(name: "Item C", price: "5.99")
            ],
            imageFilename: "dummy_receipt.jpg"
        )
        return NavigationView {
            ReceiptDetailView(receipt: dummyReceipt)
        }
    }
}
