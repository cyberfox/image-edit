//
//  HistoryItem.swift
//  ImageEdit
//
//  Created by Assistant on 8/21/25.
//

import Foundation
import UIKit

struct HistoryItem: Codable, Identifiable {
    let id: String
    let prompt: String
    let imageURL: String
    let thumbnailData: Data?
    let createdAt: Date
    let steps: Int
    let cfgScale: Double
    let apiEndpoint: String
    
    init(prompt: String, imageURL: String, thumbnailData: Data?, steps: Int, cfgScale: Double, apiEndpoint: String) {
        self.id = UUID().uuidString
        self.prompt = prompt
        self.imageURL = imageURL
        self.thumbnailData = thumbnailData
        self.createdAt = Date()
        self.steps = steps
        self.cfgScale = cfgScale
        self.apiEndpoint = apiEndpoint
    }
    
    // Helper to get thumbnail image
    var thumbnailImage: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }
    
    // Helper to get full URL
    var fullImageURL: URL? {
        URL(string: apiEndpoint)?.appendingPathComponent(imageURL)
    }
    
    // Formatted date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}