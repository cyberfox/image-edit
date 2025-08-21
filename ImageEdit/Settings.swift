//
//  Settings.swift
//  ImageEdit
//
//  Created by Assistant on 8/21/25.
//

import SwiftUI
import Combine

class Settings: ObservableObject {
    static let shared = Settings()
    
    @AppStorage("apiEndpoint") var apiEndpoint: String = "http://huginn:8000"
    @AppStorage("defaultSteps") var defaultSteps: Double = 50
    @AppStorage("defaultCFGScale") var defaultCFGScale: Double = 4.0
    
    // Computed property to get URL
    var apiURL: URL? {
        URL(string: apiEndpoint)
    }
    
    // Validation
    func isValidEndpoint(_ endpoint: String) -> Bool {
        guard let url = URL(string: endpoint) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    // Reset to defaults
    func resetToDefaults() {
        apiEndpoint = "http://huginn:8000"
        defaultSteps = 50
        defaultCFGScale = 4.0
    }
}