// GlobalImports.swift
// A utility file to ensure consistent importing of types across the app

import Foundation
import SwiftUI
import UIKit
import Vision
import VisionKit
import Combine

// Re-export common types to ensure they're available throughout the app

// This file serves as a central point for importing all common modules
// used throughout the app, making imports more consistent.

typealias ImageType = UIImage
typealias DocumentCameraType = VNDocumentCameraViewController