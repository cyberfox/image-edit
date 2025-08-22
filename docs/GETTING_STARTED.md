# ImageEdit - Getting Started Guide

## For Developers

### Prerequisites

- **macOS**: Ventura or later
- **Xcode**: 16.4 or later
- **iOS Deployment Target**: 18.5
- **Swift**: 5.0

### Initial Setup

1. **Clone the Repository**
   ```bash
   git clone [repository-url]
   cd ImageEdit
   ```

2. **Open in Xcode**
   ```bash
   open ImageEdit.xcodeproj
   ```

3. **Configure Signing**
   - Select the project in navigator
   - Choose your development team
   - Update bundle identifier if needed

4. **Set Up API Server**
   - Default expects server at `http://huginn:8000`
   - Can be changed in Settings within app
   - Server must implement the API described below

### Required API Endpoints

Your image generation server must implement:

```
POST /edit
Content-Type: multipart/form-data
Fields:
  - file: image file
  - prompt: string
  - num_inference_steps: integer
  - true_cfg_scale: float
  - seed: integer (optional)

Response:
{
  "job_id": "string",
  "status": "string"
}
```

```
GET /jobs/{job_id}
Response:
{
  "id": "string",
  "status": "queued|running|succeeded|failed",
  "progress": 0-100,
  "prompt": "string",
  "result_url": "string" (relative path),
  "error": "string" (optional)
}
```

```
GET /{result_url}
Returns: Generated image file
```

### Building & Running

1. **Select Target Device**
   - Choose iOS Simulator or connected device
   - Recommended: iPhone 15 Pro or later

2. **Build & Run**
   - Press Cmd+R or click Run button
   - First build will take longer

3. **Testing on Device**
   - Requires Apple Developer account
   - Enable developer mode on device
   - Trust developer certificate

### Project Structure Overview

```
ImageEdit/
├── Core Views
│   ├── ContentView.swift       # Main screen
│   ├── FullScreenImageView.swift
│   └── ImageEditApp.swift      # App entry
├── Settings
│   ├── Settings.swift          # Data model
│   └── SettingsView.swift      # UI
├── History
│   ├── HistoryItem.swift       # Data model
│   ├── HistoryManager.swift    # Business logic
│   ├── HistoryView.swift       # Grid UI
│   └── ImageDetailView.swift   # Detail view
└── Resources
    ├── Info.plist
    └── Assets.xcassets
```

### Key Code Patterns

#### State Management
```swift
@StateObject private var settings = Settings.shared  // Singletons
@State private var localValue: String = ""          // View state
@Published var observableProperty: Int = 0          // Observable
```

#### Async Networking
```swift
Task {
    do {
        let result = try await api.submitEdit(...)
        // Handle success
    } catch {
        // Handle error
    }
}
```

#### SwiftUI Navigation
```swift
.sheet(isPresented: $showingView) { ViewName() }
.fullScreenCover(item: $selectedItem) { item in DetailView(item) }
```

### Common Development Tasks

#### Adding a New Setting

1. Add property to `Settings.swift`:
   ```swift
   @AppStorage("newSetting") var newSetting: String = "default"
   ```

2. Add UI to `SettingsView.swift`:
   ```swift
   TextField("Label", text: $settings.newSetting)
   ```

3. Use in `ContentView.swift`:
   ```swift
   let value = settings.newSetting
   ```

#### Modifying the API Client

1. Find `APIClient` class in `ContentView.swift`
2. Add new methods following existing patterns
3. Handle errors appropriately
4. Update UI states during operations

#### Adding UI Features

1. Follow existing design patterns
2. Use consistent spacing (16pt, 20pt)
3. Match color scheme
4. Add animations where appropriate

### Debugging Tips

1. **Network Issues**
   - Check console for URLSession errors
   - Verify API endpoint is reachable
   - Use Network Link Conditioner to test

2. **UI Layout**
   - Use Xcode preview for quick iteration
   - Test on multiple device sizes
   - Check landscape orientation

3. **State Management**
   - Use Xcode debugger breakpoints
   - Print state changes
   - Check @Published updates

### Testing

#### Manual Testing Checklist
- [ ] Image selection works
- [ ] Generation completes successfully
- [ ] History saves and loads
- [ ] Settings persist
- [ ] Error states display correctly
- [ ] All gestures work in image viewer
- [ ] Share functionality works

#### Unit Testing
- Test models in `ImageEditTests/`
- Mock network responses
- Test data persistence

#### UI Testing
- Test flows in `ImageEditUITests/`
- Record UI interactions
- Verify element existence

### Performance Optimization

1. **Image Handling**
   - Compress before upload (0.9 quality)
   - Generate small thumbnails (200x200)
   - Load full images on demand

2. **Memory Management**
   - Release large images when not visible
   - Use `@StateObject` for persistent objects
   - Profile with Instruments

3. **Network Efficiency**
   - Poll status every 3 seconds
   - Cancel requests when view disappears
   - Handle timeouts gracefully

### Contributing Guidelines

1. **Code Style**
   - Follow existing patterns
   - Use meaningful variable names
   - Comment complex logic
   - Keep functions focused

2. **Pull Requests**
   - Test thoroughly
   - Update documentation
   - Include screenshots for UI changes
   - Describe changes clearly

3. **Issues**
   - Search existing issues first
   - Provide reproduction steps
   - Include device/OS information
   - Attach relevant screenshots

### Deployment Checklist

- [ ] Update version number
- [ ] Test on physical device
- [ ] Verify API endpoint
- [ ] Check all permissions
- [ ] Archive and validate
- [ ] Submit to App Store

### Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Swift Style Guide](https://swift.org/documentation/api-design-guidelines/)

---

For feature documentation, see [FEATURES.md](./FEATURES.md)
For architecture details, see [ARCHITECTURE.md](./ARCHITECTURE.md)