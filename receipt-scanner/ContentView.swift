import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var manager: ReceiptManager
    @State private var showingImagePicker = false
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var refreshID = UUID() // Refresh identifier for forcing UI updates
    @State private var showDeleteAlert = false
    @State private var receiptToDelete: Receipt?

    var filteredReceipts: [Receipt] {
        if searchText.isEmpty {
            return manager.receipts
        } else {
            let searchQuery = searchText.lowercased()
            return manager.receipts.filter { receipt in
                receipt.store.lowercased().contains(searchQuery) ||
                receipt.items.contains(where: { $0.name.lowercased().contains(searchQuery) }) ||
                receipt.date.contains(searchQuery)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar with better styling
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search by store, item or date", text: $searchText)
                        .accessibility(identifier: "searchField")
                        .onTapGesture {
                            isSearching = true
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal)
                .padding(.top, 10)

                // No receipts view
                if filteredReceipts.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 70))
                            .foregroundColor(.gray)
                        Text(searchText.isEmpty ? "No receipts yet" : "No matching receipts")
                            .font(.headline)
                        Text(searchText.isEmpty ? "Tap the camera icon to scan a receipt" : "Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                } else {
                    // Receipts list
                    List {
                        ForEach(filteredReceipts) { receipt in
                            NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                                ReceiptRow(receipt: receipt)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteReceipt(receipt)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            // Using an ID to force view refresh when needed
            .id(refreshID)
            .navigationBarTitle("Receipts")
            .navigationBarItems(
                trailing: Button(action: {
                    showingImagePicker = true
                }) {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .accessibility(identifier: "camera")
            )
            .sheet(isPresented: $showingImagePicker, onDismiss: {
                // Ensure we're on the main thread when refreshing UI data
                DispatchQueue.main.async {
                    // Refresh the receipts list when the sheet is dismissed
                    manager.loadReceipts()
                    
                    // Force a UI update by changing the refresh ID
                    refreshID = UUID()
                }
            }) {
                ReceiptScannerView()
            }
            .onReceive(manager.objectWillChange) { _ in
                // Force refresh when manager publishes changes
                refreshID = UUID()
            }
            .onAppear {
                // Refresh receipts when view appears
                manager.loadReceipts()
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Receipt"),
                    message: Text("Are you sure you want to delete this receipt? This cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let receipt = receiptToDelete {
                            manager.deleteReceipt(receipt)
                            refreshID = UUID() // Force refresh
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // Function to handle receipt deletion with confirmation
    private func deleteReceipt(_ receipt: Receipt) {
        receiptToDelete = receipt
        showDeleteAlert = true
    }
}

// Extract receipt row to separate component for better reusability
struct ReceiptRow: View {
    let receipt: Receipt
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Receipt thumbnail with caching
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                    
                if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    Image(systemName: "receipt")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
            }
            .onAppear {
                // Load image asynchronously
                DispatchQueue.global(qos: .userInitiated).async {
                    if self.thumbnail == nil {
                        let image = UIImage.loadFromDocuments(filename: receipt.imageFilename)
                        DispatchQueue.main.async {
                            self.thumbnail = image
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.store)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("\(receipt.date) \(receipt.time)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if !receipt.items.isEmpty {
                    Text("\(receipt.items.count) items · $\(String(format: "%.2f", receipt.total))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(itemsPreview)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // Generate a preview of the first few items
    private var itemsPreview: String {
        let maxItems = min(2, receipt.items.count)
        let preview = receipt.items[0..<maxItems].map { $0.name }.joined(separator: ", ")
        
        if receipt.items.count > maxItems {
            return "\(preview), and \(receipt.items.count - maxItems) more"
        }
        return preview
    }
}
