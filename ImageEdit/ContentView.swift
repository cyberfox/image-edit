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

struct ServerStatus: Codable {
    let ok: Bool
    let model: String
    let modelLoaded: Bool
    let timeoutMinutes: Double
    let minutesSinceLastRequest: Double
    let minutesUntilUnload: Double?
    
    enum CodingKeys: String, CodingKey {
        case ok, model
        case modelLoaded = "model_loaded"
        case timeoutMinutes = "timeout_minutes"
        case minutesSinceLastRequest = "minutes_since_last_request"
        case minutesUntilUnload = "minutes_until_unload"
    }
}

// MARK: - API
final class APIClient: NSObject, ObservableObject, URLSessionTaskDelegate {
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    func submitEdit(imageDatas: [Data],
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

        // Add up to 3 image files
        let fileNames = ["file", "file2", "file3"]
        for (index, imageData) in imageDatas.enumerated() {
            guard index < 3 else { break }  // Max 3 images
            let fieldName = fileNames[index]
            body.append("--\(boundary)\r\n".data())
            body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"image\(index + 1).jpg\"\r\n".data())
            body.append("Content-Type: image/jpeg\r\n\r\n".data())
            body.append(imageData)
            body.append("\r\n".data())
        }

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
    
    func checkHealth() async throws -> ServerStatus {
        guard let baseURL = Settings.shared.apiURL else {
            throw NSError(domain: "api", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint"])
        }
        let url = baseURL.appendingPathComponent("/health")
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "health", code: 5, userInfo: [NSLocalizedDescriptionKey: "Health check failed"])
        }
        return try JSONDecoder().decode(ServerStatus.self, from: data)
    }
    
    func unloadModel() async throws -> [String: String] {
        guard let baseURL = Settings.shared.apiURL else {
            throw NSError(domain: "api", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint"])
        }
        let url = baseURL.appendingPathComponent("/model/unload")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "unload", code: 6, userInfo: [NSLocalizedDescriptionKey: "Model unload failed"])
        }
        return try JSONDecoder().decode([String: String].self, from: data)
    }
}

fileprivate extension String {
    func data() -> Data { data(using: .utf8)! }
}

// MARK: - UI
struct ContentView: View {
    @StateObject private var api = APIClient()
    @StateObject private var settings = Settings.shared
    @StateObject private var historyManager = HistoryManager.shared

    // Support for multiple images (1-3)
    @State private var selectedItems: [PhotosPickerItem?] = [nil, nil, nil]
    @State private var pickedImages: [UIImage?] = [nil, nil, nil]
    @State private var pickedImageDatas: [Data?] = [nil, nil, nil]
    @State private var activeImageCount: Int = 1  // Start with 1 image slot

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
    @State private var resultRelativeURL: String?
    @State private var showingInputFullScreen = false
    @State private var showingResultFullScreen = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var serverStatus: ServerStatus?
    @State private var healthCheckTimer: Timer?

    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Section
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AI Image Editor")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                    HStack(spacing: 8) {
                                        Text("Transform your images with AI")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        // Server status indicator
                                        if let status = serverStatus {
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(status.modelLoaded ? Color.green : Color.orange)
                                                    .frame(width: 8, height: 8)
                                                Text(status.modelLoaded ? "Model Ready" : "Model Unloaded")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                if status.modelLoaded, let minutes = status.minutesUntilUnload {
                                                    Text("(\(Int(minutes))m)")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary.opacity(0.7))
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                Spacer()
                                
                                HStack(spacing: 16) {
                                    // Model unload button (subtle)
                                    if serverStatus?.modelLoaded == true {
                                        Button {
                                            Task { await unloadModel() }
                                        } label: {
                                            Image(systemName: "moon.zzz")
                                                .font(.title3)
                                                .foregroundColor(.secondary.opacity(0.7))
                                        }
                                        .help("Unload model to free memory")
                                    }
                                    
                                    Button {
                                        hideKeyboard()
                                        showingHistory = true
                                    } label: {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Button {
                                        hideKeyboard()
                                        showingSettings = true
                                    } label: {
                                        Image(systemName: "gearshape.fill")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Image Picker Card - Multiple Images
                            VStack(spacing: 16) {
                                // Display all active image slots
                                ForEach(0..<activeImageCount, id: \.self) { index in
                                    VStack(spacing: 12) {
                                        HStack {
                                            Text("Image \(index + 1)")
                                                .font(.headline)
                                                .foregroundColor(index == 0 ? .primary : .secondary)

                                            if index == 0 {
                                                Text("(Required)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            // Remove button for images 2 and 3
                                            if index > 0 {
                                                Button {
                                                    removeImage(at: index)
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .font(.caption)
                                                        .foregroundColor(.red)
                                                }
                                            }
                                        }

                                        // Photo picker for this slot
                                        PhotosPicker(selection: Binding(
                                            get: { selectedItems[index] },
                                            set: { newValue in
                                                selectedItems[index] = newValue
                                                Task { await loadPhoto(newValue, at: index) }
                                            }
                                        ), matching: .images, photoLibrary: .shared()) {
                                            HStack {
                                                Image(systemName: pickedImages[index] == nil ? "photo.badge.plus" : "photo.on.rectangle.angled")
                                                    .font(.title3)
                                                Text(pickedImages[index] == nil ? "Select Image \(index + 1)" : "Change Image \(index + 1)")
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
                                            .cornerRadius(12)
                                        }

                                        // Image preview
                                        if let ui = pickedImages[index] {
                                            Image(uiImage: ui)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxHeight: 200)
                                                .cornerRadius(12)
                                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                                                .onTapGesture {
                                                    showingInputFullScreen = true
                                                }
                                        }
                                    }
                                    .padding()
                                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                                    .cornerRadius(16)
                                }

                                // Add Image button (show when < 3 images)
                                if activeImageCount < 3 {
                                    Button {
                                        withAnimation {
                                            activeImageCount += 1
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title3)
                                            Text("Add Image (\(activeImageCount + 1)/3)")
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.blue)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                                        .cornerRadius(12)
                                    }
                                }

                                if activeImageCount > 1 {
                                    Text("Tip: Reference images in your prompt as 'image 1', 'image 2', etc.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
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
                            hideKeyboard()
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
                                    colors: (hasFirstImage && !isBusy) ? [Color.purple, Color.blue] : [Color.gray, Color.gray.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: (hasFirstImage && !isBusy) ? Color.blue.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
                        }
                        .disabled(!hasFirstImage || isBusy)
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
            if let image = pickedImages[0] {
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
        .sheet(isPresented: $showingHistory) {
            HistoryView()
        }
        .onAppear {
            // Initialize with settings values if not already set
            if steps == 0 {
                steps = settings.defaultSteps
            }
            if cfg == 0 {
                cfg = settings.defaultCFGScale
            }
            
            // Start health check polling
            startHealthCheckPolling()
        }
        .onDisappear {
            // Stop health check polling
            healthCheckTimer?.invalidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Immediate health check when returning to app
            Task {
                await performHealthCheck()
            }
        }
    }
    
    // Helper function to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

    // Computed property to check if first image is present
    private var hasFirstImage: Bool {
        pickedImageDatas[0] != nil
    }

    // MARK: - Actions
    private func removeImage(at index: Int) {
        guard index > 0 && index < 3 else { return }

        withAnimation {
            // Clear the image at this index
            pickedImages[index] = nil
            pickedImageDatas[index] = nil
            selectedItems[index] = nil

            // If removing the last slot, decrease active count
            if index == activeImageCount - 1 {
                activeImageCount -= 1
            } else {
                // Shift images down to fill the gap
                for i in index..<(activeImageCount - 1) {
                    pickedImages[i] = pickedImages[i + 1]
                    pickedImageDatas[i] = pickedImageDatas[i + 1]
                    selectedItems[i] = selectedItems[i + 1]
                }
                // Clear the last slot
                let lastIndex = activeImageCount - 1
                pickedImages[lastIndex] = nil
                pickedImageDatas[lastIndex] = nil
                selectedItems[lastIndex] = nil
                activeImageCount -= 1
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?, at index: Int) async {
        guard let item, index >= 0, index < 3 else { return }
        do {
            // Prefer JPEG for size; Photos may deliver HEIC/PNG—convert below
            if let data = try await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                // Re-encode as medium JPEG to keep uploads snappy; adjust as needed
                let jpeg = ui.jpegData(compressionQuality: 0.9) ?? data
                withAnimation {
                    self.pickedImages[index] = UIImage(data: jpeg)
                    self.pickedImageDatas[index] = jpeg
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
        // Collect all non-nil image datas
        let imageDatas = pickedImageDatas.compactMap { $0 }
        guard !imageDatas.isEmpty else { return }

        withAnimation {
            isBusy = true
            resultImage = nil
            statusText = "Uploading…"
            progress = 0
            errorMessage = nil
        }
        jobId = nil

        do {
            let resp = try await api.submitEdit(
                imageDatas: imageDatas,
                prompt: prompt,
                steps: Int(steps),
                trueCfgScale: cfg
            )
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
                    resultRelativeURL = path
                    
                    // Save to history
                    historyManager.addItem(
                        prompt: prompt,
                        imageURL: path,
                        image: img,
                        steps: Int(steps),
                        cfgScale: cfg,
                        apiEndpoint: settings.apiEndpoint
                    )
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
    
    private func startHealthCheckPolling() {
        // Initial health check
        Task {
            await performHealthCheck()
        }
        
        // Poll every 30 seconds
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await self.performHealthCheck()
            }
        }
    }
    
    @MainActor
    private func performHealthCheck() async {
        do {
            let status = try await api.checkHealth()
            withAnimation {
                self.serverStatus = status
            }
        } catch {
            // Silently fail - don't show errors for background health checks
            print("Health check failed: \(error)")
        }
    }
    
    @MainActor
    private func unloadModel() async {
        do {
            _ = try await api.unloadModel()
            // Refresh status after unload
            await performHealthCheck()
            withAnimation {
                statusText = "Model unloaded"
            }
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation {
                    statusText = "Ready"
                }
            }
        } catch {
            withAnimation {
                errorMessage = "Failed to unload model"
            }
        }
    }
}
