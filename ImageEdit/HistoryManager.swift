//
//  HistoryManager.swift
//  ImageEdit
//
//  Created by Assistant on 8/21/25.
//

import Foundation
import UIKit
import Combine

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var items: [HistoryItem] = []
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let historyFile = "image_history.json"
    
    private init() {
        loadHistory()
    }
    
    // Save a new history item
    func addItem(prompt: String, imageURL: String, image: UIImage, steps: Int, cfgScale: Double, apiEndpoint: String) {
        // Create thumbnail (max 200x200)
        let thumbnailData = createThumbnail(from: image)
        
        let item = HistoryItem(
            prompt: prompt,
            imageURL: imageURL,
            thumbnailData: thumbnailData,
            steps: steps,
            cfgScale: cfgScale,
            apiEndpoint: apiEndpoint
        )
        
        items.insert(item, at: 0) // Add to beginning
        
        // Keep only last 100 items
        if items.count > 100 {
            items = Array(items.prefix(100))
        }
        
        saveHistory()
    }
    
    // Delete an item
    func deleteItem(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    // Clear all history
    func clearHistory() {
        items.removeAll()
        saveHistory()
    }
    
    // Create thumbnail from image
    private func createThumbnail(from image: UIImage) -> Data? {
        let maxSize: CGFloat = 200
        let scale = min(maxSize / image.size.width, maxSize / image.size.height)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        guard let thumbnailImage = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        
        return thumbnailImage.jpegData(compressionQuality: 0.7)
    }
    
    // Save history to disk
    private func saveHistory() {
        let url = documentsPath.appendingPathComponent(historyFile)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: url)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    // Load history from disk
    private func loadHistory() {
        let url = documentsPath.appendingPathComponent(historyFile)
        
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([HistoryItem].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
        }
    }
}