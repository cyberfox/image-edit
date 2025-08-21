//
//  ContentView.swift
//  ImageEdit
//
//  Created by Morgan Schweers on 8/21/25.
//

import SwiftUI
import PhotosUI
import Photos   // for saving to Photos

// Build an absolute URL from Settings API URL + relative result_url
func absoluteResultURL(_ relative: String) -> URL? {
    Settings.shared.apiURL?.appendingPathComponent(relative)
}

// Save a UIImage to Photos (requires NSPhotoLibraryAddUsageDescription)
func saveImageToPhotos(_ image: UIImage, onDone: @escaping (Error?) -> Void) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { ok, err in
            DispatchQueue.main.async { onDone(ok ? nil : err) }
        })
    }
}

// MARK: - Config
// Now using Settings.shared.apiURL instead of hardcoded BASE_URL

// MARK: - DTOs
struct SubmitResponse: Codable {
    let jobId: String
    let status: String
    enum CodingKeys: String, CodingKey { case jobId = "job_id", status }
}

struct JobStatus: Codable {
    let id: String
    let status: String            // "queued" | "running" | "succeeded" | "failed"
    let progress: Double
    let prompt: String
    let resultURL: String?
    let error: String?
    enum CodingKeys: String, CodingKey {
        case id, status, progress, prompt, error
        case resultURL = "result_url"
    }
}

// MARK: - API
final class APIClient: NSObject, ObservableObject, URLSessionTaskDelegate {
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    func submitEdit(imageData: Data,
                    filename: String,
                    prompt: String,
                    steps: Int,
                    trueCfgScale: Double,
                    seed: Int? = nil) async throws -> SubmitResponse {

        guard let baseURL = Settings.shared.apiURL else {
            throw NSError(domain: "api", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint"])
        }
        var req = URLRequest(url: baseURL.appendingPathComponent("/edit"))
        let boundary = "----BOUNDARY-\(UUID().uuidString)"
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data())
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data())
            body.append("\(value)\r\n".data())
        }
        // fields expected by your FastAPI server
        addField("prompt", prompt)
        addField("num_inference_steps", String(steps))
        addField("true_cfg_scale", String(trueCfgScale))
        if let seed { addField("seed", String(seed)) }

        // file part
        body.append("--\(boundary)\r\n".data())
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data())
        body.append("Content-Type: image/jpeg\r\n\r\n".data())
        body.append(imageData)
        body.append("\r\n".data())
        body.append("--\(boundary)--\r\n".data())
        req.httpBody = body

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "upload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Upload failed"])
        }
        return try JSONDecoder().decode(SubmitResponse.self, from: data)
    }

    func fetchJob(_ jobId: String) async throws -> JobStatus {
        guard let baseURL = Settings.shared.apiURL else {
            throw NSError(domain: "api", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint"])
        }
        let url = baseURL.appendingPathComponent("/jobs/\(jobId)")
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "poll", code: 2, userInfo: [NSLocalizedDescriptionKey: "Poll failed"])
        }
        return try JSONDecoder().decode(JobStatus.self, from: data)
    }

    func downloadResult(relativePath: String) async throws -> UIImage {
        guard let baseURL = Settings.shared.apiURL else {
            throw NSError(domain: "api", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint"])
        }
        let url = baseURL.appendingPathComponent(relativePath)
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "download", code: 3, userInfo: [NSLocalizedDescriptionKey: "Download failed"])
        }
        guard let img = UIImage(data: data) else {
            throw NSError(domain: "download", code: 4, userInfo: [NSLocalizedDescriptionKey: "Bad image"])
        }
        return img
    }
}

fileprivate extension String {
    func data() -> Data { data(using: .utf8)! }
}

// MARK: - UI
struct ContentView: View {
    @StateObject private var api = APIClient()
    @StateObject private var settings = Settings.shared
    @State private var selectedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var pickedImageData: Data?
    @State private var prompt: String = ""
    @State private var steps: Double = 0
    @State private var cfg: Double = 0
    @State private var jobId: String?
    @State private var statusText: String = "Ready"
    @State private var progress: Double = 0
    @State private var resultImage: UIImage?
    @State private var isBusy: Bool = false
    @State private var errorMessage: String?
    @Environment(\.openURL) private var openURL
    @State private var resultAbsoluteURL: URL?
    @State private var showingInputFullScreen = false
    @State private var showingResultFullScreen = false
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Section
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AI Image Editor")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                    Text("Transform your images with AI")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                Button {
                                    showingSettings = true
                                } label: {
                                    Image(systemName: "gearshape.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Image Picker Card
                            VStack(spacing: 16) {
                                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                                    HStack {
                                        Image(systemName: pickedImage == nil ? "photo.badge.plus" : "photo.on.rectangle.angled")
                                            .font(.title2)
                                        Text(pickedImage == nil ? "Select Image" : "Change Image")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                }
                                .onChange(of: selectedItem) { _, item in
                                    Task { await loadPhoto(item) }
                                }
                                
                                // Selected Image Preview
                                if let ui = pickedImage {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Input Image")
                                                .font(.headline)
                                            Spacer()
                                            Button {
                                                showingInputFullScreen = true
                                            } label: {
                                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Image(uiImage: ui)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 250)
                                            .cornerRadius(16)
                                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                                            .onTapGesture {
                                                showingInputFullScreen = true
                                            }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(20)
                            .padding(.horizontal)
                        }
                        
                        // Prompt Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Edit Instructions")
                                .font(.headline)
                            
                            TextField("Describe how you want to transform the image...", text: $prompt, axis: .vertical)
                                .padding()
                                .background(Color(UIColor.tertiarySystemGroupedBackground))
                                .cornerRadius(12)
                                .lineLimit(3...6)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // Settings Card
                        VStack(spacing: 20) {
                            Text("Generation Settings")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Steps", systemImage: "slider.horizontal.3")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(steps))")
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                Slider(value: $steps, in: 10...75, step: 1)
                                    .accentColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Guidance Scale", systemImage: "wand.and.rays")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%.1f", cfg))
                                        .fontWeight(.medium)
                                        .foregroundColor(.purple)
                                }
                                Slider(value: $cfg, in: 1.0...8.0, step: 0.1)
                                    .accentColor(.purple)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // Generate Button
                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                if isBusy {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isBusy ? "Processing..." : "Generate")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: (pickedImageData != nil && !isBusy) ? [Color.purple, Color.blue] : [Color.gray, Color.gray.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: (pickedImageData != nil && !isBusy) ? Color.blue.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
                        }
                        .disabled(pickedImageData == nil || isBusy)
                        .padding(.horizontal)
                        
                        // Status Card
                        if isBusy || statusText != "Ready" {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: statusIcon)
                                        .foregroundColor(statusColor)
                                    Text(statusText)
                                        .font(.headline)
                                    Spacer()
                                    if isBusy {
                                        Text("\(Int(progress))%")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                ProgressView(value: progress/100.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: statusColor))
                                    .scaleEffect(x: 1, y: 2, anchor: .center)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(20)
                            .padding(.horizontal)
                        }
                        
                        // Result Card
                        if let ri = resultImage {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Generated Image")
                                        .font(.headline)
                                    Spacer()
                                    Button {
                                        showingResultFullScreen = true
                                    } label: {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Image(uiImage: ri)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                                    .onTapGesture {
                                        showingResultFullScreen = true
                                    }
                                
                                // Action Buttons
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        // Save to Photos
                                        Button {
                                            saveImageToPhotos(ri) { err in
                                                withAnimation {
                                                    statusText = err == nil ? "Saved!" : "Save failed"
                                                }
                                                if err == nil {
                                                    Task {
                                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                                        withAnimation {
                                                            statusText = "Ready"
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            Label("Save", systemImage: "square.and.arrow.down")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.regular)
                                        
                                        // Share Image
                                        ShareLink(item: Image(uiImage: ri), preview: SharePreview("Generated Image", image: Image(uiImage: ri))) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.regular)
                                        
                                        // Open in Safari
                                        if let url = resultAbsoluteURL {
                                            Button {
                                                openURL(url)
                                            } label: {
                                                Label("Web", systemImage: "safari")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.regular)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(20)
                            .padding(.horizontal)
                        }
                        
                        // Error Message
                        if let err = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(err)
                                    .font(.footnote)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showingInputFullScreen) {
            if let image = pickedImage {
                FullScreenImageView(image: image, title: "Input Image", isPresented: $showingInputFullScreen)
            }
        }
        .fullScreenCover(isPresented: $showingResultFullScreen) {
            if let image = resultImage {
                FullScreenImageView(image: image, title: "Generated Image", isPresented: $showingResultFullScreen)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            // Initialize with settings values if not already set
            if steps == 0 {
                steps = settings.defaultSteps
            }
            if cfg == 0 {
                cfg = settings.defaultCFGScale
            }
        }
    }
    
    // Computed properties for status styling
    private var statusIcon: String {
        switch statusText.lowercased() {
        case "ready": return "checkmark.circle.fill"
        case "uploading…", "queued", "running": return "arrow.clockwise.circle.fill"
        case "succeeded": return "checkmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        case "saved!": return "checkmark.circle.fill"
        default: return "info.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch statusText.lowercased() {
        case "ready", "succeeded", "saved!": return .green
        case "uploading…", "queued", "running": return .blue
        case "failed", "save failed": return .red
        default: return .secondary
        }
    }

    // MARK: - Actions
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            // Prefer JPEG for size; Photos may deliver HEIC/PNG—convert below
            if let data = try await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                // Re-encode as medium JPEG to keep uploads snappy; adjust as needed
                let jpeg = ui.jpegData(compressionQuality: 0.9) ?? data
                withAnimation {
                    self.pickedImage = UIImage(data: jpeg)
                    self.pickedImageData = jpeg
                }
            }
        } catch {
            withAnimation {
                self.errorMessage = "Failed to load photo: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func submit() async {
        guard let imgData = pickedImageData else { return }
        withAnimation {
            isBusy = true
            resultImage = nil
            statusText = "Uploading…"
            progress = 0
            errorMessage = nil
        }
        jobId = nil

        do {
            let resp = try await api.submitEdit(imageData: imgData,
                                                filename: "upload.jpg",
                                                prompt: prompt,
                                                steps: Int(steps),
                                                trueCfgScale: cfg)
            jobId = resp.jobId
            withAnimation {
                statusText = "Queued"
            }
            // Poll every <= 3s until terminal state
            try await poll(jobId: resp.jobId)
        } catch {
            withAnimation {
                errorMessage = "Submit failed: \(error.localizedDescription)"
                statusText = "Ready"
                isBusy = false
            }
        }
    }

    @MainActor
    private func poll(jobId: String) async throws {
        while true {
            let job = try await api.fetchJob(jobId)
            withAnimation {
                progress = min(100, max(0, job.progress))
                statusText = job.status.capitalized
            }

            if job.status == "succeeded" {
                if let path = job.resultURL {
                    let img = try await api.downloadResult(relativePath: path)
                    withAnimation {
                        resultImage = img
                        statusText = "Ready"
                    }
                    resultAbsoluteURL = absoluteResultURL(path)   // <- keep the URL for share/open
                }
                withAnimation {
                    isBusy = false
                }
                return
            } else if job.status == "failed" {
                withAnimation {
                    errorMessage = job.error ?? "Job failed"
                    statusText = "Ready"
                    isBusy = false
                }
                return
            }

            try await Task.sleep(nanoseconds: 3_000_000_000) // 3s
        }
    }
}
