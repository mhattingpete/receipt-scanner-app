import SwiftUI
import UIKit
import VisionKit
import Vision

/// SwiftUI wrapper around VisionKit's VNDocumentCameraViewController.
struct DocumentScannerView: UIViewControllerRepresentable {
    /// Called when the user cancels or finishes scanning.
    var completion: (_ pages: [UIImage]?) -> Void

    // MARK: - UIViewControllerRepresentable
    func makeCoordinator() -> Coordinator { 
        Coordinator(completion: completion) 
    }

    func makeUIViewController(context: Context) -> DocumentScannerHostController {
        let vc = DocumentScannerHostController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: DocumentScannerHostController, context: Context) {
        // Nothing to update
    }

    // MARK: - Coordinator bridges delegate → SwiftUI
    final class Coordinator: NSObject, DocumentScannerHostControllerDelegate {
        private let completion: (_ pages: [UIImage]?) -> Void
        
        init(completion: @escaping (_ pages: [UIImage]?) -> Void) { 
            self.completion = completion 
        }

        func documentScannerController(_ vc: DocumentScannerHostController, didFinishWith images: [UIImage]) {
            completion(images)
        }

        func documentScannerControllerDidCancel(_ vc: DocumentScannerHostController) {
            completion(nil)
        }
    }
}

// MARK: - Delegate protocol
protocol DocumentScannerHostControllerDelegate: AnyObject {
    /// Called when the user finishes scanning. `images` contains one UIImage per page.
    func documentScannerController(_ vc: DocumentScannerHostController, didFinishWith images: [UIImage])
    /// Called on user cancel or error.
    func documentScannerControllerDidCancel(_ vc: DocumentScannerHostController)
}

// MARK: - Host controller
final class DocumentScannerHostController: UIViewController {
    weak var delegate: DocumentScannerHostControllerDelegate?

    private lazy var scannerVC: VNDocumentCameraViewController = {
        let vc = VNDocumentCameraViewController()
        vc.delegate = self
        return vc
    }()

    // Present the scanner the first time the view appears.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard presentedViewController == nil else { return }
        present(scannerVC, animated: true)
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate
extension DocumentScannerHostController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.documentScannerControllerDidCancel(self)
        }
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: Error
    ) {
        print("Document‑camera error:", error)
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.documentScannerControllerDidCancel(self)
        }
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        var pages: [UIImage] = []
        for index in 0..<scan.pageCount {
            pages.append(scan.imageOfPage(at: index))
        }

        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.documentScannerController(self, didFinishWith: pages)
        }
    }
}