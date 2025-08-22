//
//  ImageDetailView.swift
//  ImageEdit
//
//  Created by Assistant on 8/21/25.
//

import SwiftUI

struct ImageDetailView: View {
    let historyItem: HistoryItem
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var showingInfo = false
    @State private var showingError = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                } else if let image = image {
                    ImageViewer(image: image, showingInfo: $showingInfo)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                        Text("Failed to load image")
                            .foregroundColor(.white)
                        Button("Try Again") {
                            loadImage()
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray, .gray.opacity(0.3))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .gray.opacity(0.3))
                        }
                        
                        if let image = image {
                            ShareLink(item: Image(uiImage: image), preview: SharePreview("Generated Image", image: Image(uiImage: image))) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
            .toolbarBackground(.black.opacity(0.8), for: .navigationBar)
        }
        .onAppear {
            loadImage()
        }
        .sheet(isPresented: $showingInfo) {
            ImageInfoView(historyItem: historyItem)
                .presentationDetents([.medium])
        }
    }
    
    private func loadImage() {
        isLoading = true
        
        Task {
            do {
                // First try to load from URL
                if let url = historyItem.fullImageURL {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let downloadedImage = UIImage(data: data) {
                        await MainActor.run {
                            self.image = downloadedImage
                            self.isLoading = false
                        }
                        return
                    }
                }
                
                // Fallback to thumbnail if available
                await MainActor.run {
                    self.image = historyItem.thumbnailImage
                    self.isLoading = false
                    if self.image == nil {
                        self.showingError = true
                    }
                }
            } catch {
                await MainActor.run {
                    // If download fails, use thumbnail
                    self.image = historyItem.thumbnailImage
                    self.isLoading = false
                    if self.image == nil {
                        self.showingError = true
                    }
                }
            }
        }
    }
}

struct ImageViewer: View {
    let image: UIImage
    @Binding var showingInfo: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnifyBy = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale * magnifyBy)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .updating($magnifyBy) { currentState, gestureState, _ in
                            gestureState = currentState
                        }
                        .onEnded { value in
                            scale = min(max(scale * value, 0.5), 4.0)
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale > 1.0 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.0
                        }
                    }
                }
        }
    }
}

struct ImageInfoView: View {
    let historyItem: HistoryItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Prompt Section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Prompt", systemImage: "text.quote")
                            .font(.headline)
                        Text(historyItem.prompt)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    
                    // Generation Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Generation Settings", systemImage: "slider.horizontal.3")
                            .font(.headline)
                        
                        HStack {
                            Label("Steps", systemImage: "number")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(historyItem.steps)")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Label("Guidance Scale", systemImage: "wand.and.rays")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f", historyItem.cfgScale))
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Label("Created", systemImage: "calendar")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(historyItem.formattedDate)
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Technical Details
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Technical Details", systemImage: "gearshape")
                            .font(.headline)
                        
                        HStack {
                            Text("API Endpoint")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(historyItem.apiEndpoint)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        
                        HStack {
                            Text("Image Path")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(historyItem.imageURL)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Image Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}