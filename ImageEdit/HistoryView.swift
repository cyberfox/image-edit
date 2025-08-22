//
//  HistoryView.swift
//  ImageEdit
//
//  Created by Assistant on 8/21/25.
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @State private var selectedItem: HistoryItem?
    @State private var showingClearAlert = false
    @Environment(\.dismiss) private var dismiss
    
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if historyManager.items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No History Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Your generated images will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(historyManager.items) { item in
                                HistoryItemView(item: item)
                                    .onTapGesture {
                                        selectedItem = item
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !historyManager.items.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                showingClearAlert = true
                            } label: {
                                Label("Clear History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedItem) { item in
            ImageDetailView(historyItem: item)
        }
        .alert("Clear History", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                historyManager.clearHistory()
            }
        } message: {
            Text("This will permanently delete all history items. This action cannot be undone.")
        }
    }
}

struct HistoryItemView: View {
    let item: HistoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            if let thumbnail = item.thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .clipped()
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(item.prompt)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(item.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}