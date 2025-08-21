//
//  SettingsView.swift
//  ImageEdit
//
//  Created by Assistant on 8/21/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempEndpoint: String = ""
    @State private var showingResetAlert = false
    @State private var endpointError: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // API Endpoint Card
                        VStack(alignment: .leading, spacing: 16) {
                            Label("API Configuration", systemImage: "server.rack")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("API Endpoint")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField("https://api.example.com", text: $tempEndpoint)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .onChange(of: tempEndpoint) { _, newValue in
                                        validateEndpoint(newValue)
                                    }
                                
                                if let error = endpointError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Text("The server endpoint for image processing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        
                        // Default Generation Settings Card
                        VStack(alignment: .leading, spacing: 20) {
                            Label("Default Generation Settings", systemImage: "slider.horizontal.3")
                                .font(.headline)
                            
                            // Steps Setting
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Default Steps")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(settings.defaultSteps))")
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                
                                Slider(value: $settings.defaultSteps, in: 10...100, step: 1)
                                    .accentColor(.blue)
                                
                                Text("Number of inference steps (higher = better quality, slower)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            // CFG Scale Setting
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Default Guidance Scale")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%.1f", settings.defaultCFGScale))
                                        .fontWeight(.medium)
                                        .foregroundColor(.purple)
                                }
                                
                                Slider(value: $settings.defaultCFGScale, in: 1.0...10.0, step: 0.1)
                                    .accentColor(.purple)
                                
                                Text("How closely to follow the prompt (higher = more adherence)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        
                        // Actions Card
                        VStack(spacing: 12) {
                            Button {
                                showingResetAlert = true
                            } label: {
                                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                            }
                            
                            Text("Current endpoint: \(settings.apiEndpoint)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        
                        Spacer(minLength: 30)
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            tempEndpoint = settings.apiEndpoint
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
                tempEndpoint = settings.apiEndpoint
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
    }
    
    private func validateEndpoint(_ endpoint: String) {
        if endpoint.isEmpty {
            endpointError = nil
            return
        }
        
        if !settings.isValidEndpoint(endpoint) {
            endpointError = "Invalid URL format. Must start with http:// or https://"
        } else {
            endpointError = nil
        }
    }
    
    private func saveSettings() {
        if settings.isValidEndpoint(tempEndpoint) {
            settings.apiEndpoint = tempEndpoint
        }
    }
}