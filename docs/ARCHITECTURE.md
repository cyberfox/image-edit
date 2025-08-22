# ImageEdit - Architecture Documentation

## Overview

ImageEdit is a SwiftUI-based iOS application that provides an intuitive interface for AI-powered image editing. The app allows users to transform images using text prompts by communicating with a remote AI image generation API.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Core Components](#core-components)
3. [Features](#features)
4. [Data Flow](#data-flow)
5. [API Integration](#api-integration)
6. [Storage & Persistence](#storage--persistence)
7. [UI/UX Design](#uiux-design)
8. [Dependencies](#dependencies)

## Project Structure

```
ImageEdit/
├── ImageEdit/
│   ├── ImageEditApp.swift          # App entry point
│   ├── ContentView.swift           # Main UI view
│   ├── FullScreenImageView.swift   # Full-screen image viewer
│   ├── Settings.swift              # Settings data model
│   ├── SettingsView.swift          # Settings UI
│   ├── HistoryItem.swift           # History item model
│   ├── HistoryManager.swift        # History management
│   ├── HistoryView.swift           # History grid UI
│   ├── ImageDetailView.swift       # History item detail view
│   ├── Info.plist                  # App configuration
│   └── Assets.xcassets/            # App assets
├── ImageEditTests/                 # Unit tests
├── ImageEditUITests/               # UI tests
├── docs/                           # Documentation
└── .gitignore                      # Git ignore file
```

## Core Components

### 1. ContentView.swift (Main UI)

The heart of the application, containing:

- **APIClient**: Internal class handling all network requests
  - `submitEdit()`: Uploads image and prompt to API
  - `fetchJob()`: Polls job status
  - `downloadResult()`: Downloads generated image
  
- **Main View Structure**:
  - Photo picker integration
  - Prompt input field
  - Generation settings (steps, CFG scale)
  - Real-time status updates
  - Result display with actions

**Key State Variables**:
```swift
@StateObject private var api = APIClient()
@StateObject private var settings = Settings.shared
@StateObject private var historyManager = HistoryManager.shared
@State private var pickedImage: UIImage?
@State private var prompt: String = ""
@State private var steps: Double = 0
@State private var cfg: Double = 0
@State private var statusText: String = "Ready"
@State private var resultImage: UIImage?
```

### 2. Settings System

#### Settings.swift
- Singleton pattern with `@AppStorage` for persistence
- Manages:
  - API endpoint URL
  - Default generation steps (10-100)
  - Default CFG scale (1.0-10.0)
- Includes validation and reset functionality

#### SettingsView.swift
- Modern form-based UI
- Real-time validation
- Visual feedback for invalid inputs
- Reset to defaults option

### 3. History System

#### HistoryItem.swift
- Data model for saved generations
- Stores:
  - Unique ID
  - Prompt text
  - Image URL (relative path)
  - Thumbnail data (JPEG, 200x200)
  - Creation timestamp
  - Generation parameters
  - API endpoint used

#### HistoryManager.swift
- Singleton managing history persistence
- Features:
  - Automatic thumbnail generation
  - JSON file storage in Documents directory
  - 100-item limit (FIFO)
  - Thread-safe operations

#### HistoryView.swift
- Grid layout with adaptive columns
- Thumbnail previews
- Tap to view full screen
- Clear all functionality

#### ImageDetailView.swift
- Full-screen image viewer
- Pinch/pan/double-tap zoom
- Info sheet showing all metadata
- Share functionality
- Fallback to thumbnail if network fails

### 4. Full-Screen Image Viewer

#### FullScreenImageView.swift
- Reusable component for viewing images
- Gesture support:
  - Pinch to zoom (0.5x - 4x)
  - Pan when zoomed
  - Double-tap to toggle zoom
- Toolbar with share/save actions
- Dark background for focus

## Features

### 1. Image Generation
- **Input Methods**: 
  - PhotosPicker for selecting images
  - Support for JPEG conversion
  - Compression for faster uploads
  
- **Customization**:
  - Multi-line prompt input
  - Adjustable inference steps
  - Configurable guidance scale
  - Real-time parameter preview

- **Processing**:
  - Upload progress indication
  - Queue status updates
  - Progress percentage display
  - Animated status indicators

### 2. Results Management
- **Display Options**:
  - In-app preview
  - Full-screen viewing
  - Zoom capabilities
  
- **Actions**:
  - Save to Photos library
  - Share via iOS share sheet
  - Open in Safari
  - Automatic history saving

### 3. Settings & Configuration
- **Endpoint Management**:
  - Custom API URL configuration
  - URL validation
  - HTTP/HTTPS support
  
- **Default Values**:
  - Persistent storage
  - Easy reset option
  - Applied to new generations

### 4. History & Gallery
- **Organization**:
  - Grid thumbnail view
  - Chronological ordering
  - Visual preview with metadata
  
- **Features**:
  - Offline thumbnail access
  - Full image loading on demand
  - Detailed metadata viewing
  - Batch clearing

### 5. UI/UX Enhancements
- **Visual Design**:
  - Card-based layout
  - System-matched colors
  - Gradient buttons
  - Shadow effects
  - Smooth animations
  
- **Feedback**:
  - Loading states
  - Error messages
  - Success confirmations
  - Progress indicators

## Data Flow

### Image Generation Flow

1. **User Input**
   - User selects image via PhotosPicker
   - Image converted to JPEG with 0.9 compression
   - User enters prompt and adjusts settings

2. **API Request**
   - `submitEdit()` creates multipart form data
   - Sends: image, prompt, steps, cfg_scale
   - Returns job ID

3. **Status Polling**
   - `poll()` checks job status every 3 seconds
   - Updates progress and status text
   - Continues until success/failure

4. **Result Handling**
   - Downloads generated image
   - Displays in UI
   - Saves to history automatically
   - Enables sharing options

### Settings Flow

1. **Initialization**
   - Settings load from UserDefaults on app start
   - ContentView reads default values
   - Applied to sliders if not previously set

2. **Modification**
   - User opens settings sheet
   - Changes are validated in real-time
   - Save on "Done", discard on "Cancel"

3. **Application**
   - New API endpoint used immediately
   - Default values apply to next generation
   - Persisted across app launches

## API Integration

### Endpoints

The app communicates with a FastAPI server with these endpoints:

1. **POST /edit**
   - Multipart form upload
   - Fields: file, prompt, num_inference_steps, true_cfg_scale, seed (optional)
   - Returns: job_id, status

2. **GET /jobs/{job_id}**
   - Returns job status
   - Fields: id, status, progress, prompt, result_url, error

3. **GET /{result_path}**
   - Downloads generated image
   - Full URL constructed from base + relative path

### Error Handling

- Network failures show user-friendly messages
- Invalid endpoints prevented by validation
- Timeouts handled gracefully
- Failed jobs display error from API

## Storage & Persistence

### UserDefaults (@AppStorage)
- API endpoint
- Default generation settings
- Automatically synced

### File System
- History stored in Documents directory
- File: `image_history.json`
- Thumbnails embedded as base64 JPEG
- Automatic cleanup (100 item limit)

### Memory Management
- Images compressed before upload
- Thumbnails limited to 200x200
- Full images loaded on demand
- Proper cleanup in view lifecycle

## UI/UX Design

### Design System

1. **Colors**
   - Primary: System blues and purples
   - Background: `systemGroupedBackground`
   - Cards: `secondarySystemGroupedBackground`
   - Accents: Gradients for CTAs

2. **Typography**
   - Large title for main header
   - Headlines for sections
   - Body text for content
   - Captions for metadata

3. **Layout**
   - 20pt standard spacing
   - 16pt compact spacing
   - Card corner radius: 20pt
   - Button corner radius: 16pt

4. **Animations**
   - Spring animations for sheets
   - Smooth transitions for state changes
   - Progress animations
   - Loading indicators

### Navigation Structure

```
ContentView (Main)
├── FullScreenImageView (Input Image)
├── FullScreenImageView (Result Image)
├── SettingsView (Sheet)
└── HistoryView (Sheet)
    └── ImageDetailView (Full Screen Cover)
        └── ImageInfoView (Sheet)
```

## Dependencies

### System Frameworks
- **SwiftUI**: UI framework
- **PhotosUI**: Photo picker and library access
- **Photos**: Saving images to library
- **Combine**: Reactive programming
- **Foundation**: Core utilities

### Project Configuration
- **Minimum iOS**: 18.5
- **Swift Version**: 5.0
- **Xcode Version**: 16.4+

### External Services
- Requires external AI image generation API
- Default endpoint: `http://huginn:8000`
- Configurable via settings

## Error States & Edge Cases

### Handled Scenarios
1. **No Internet**: Shows connection error
2. **Invalid Image**: Prevents upload
3. **API Timeout**: Continues polling
4. **Missing History**: Shows empty state
5. **Failed Thumbnail**: Falls back to placeholder
6. **Invalid URL**: Real-time validation

### State Recovery
- History persists through crashes
- Settings saved immediately
- Failed jobs can be retried
- Partial results handled gracefully

## Future Considerations

### Potential Enhancements
1. **Batch Processing**: Multiple images at once
2. **Presets**: Save favorite prompts
3. **Cloud Sync**: iCloud history backup
4. **Advanced Editing**: Multiple prompts, masks
5. **Social Features**: Share to gallery

### Technical Improvements
1. **Caching**: Better image caching strategy
2. **Background Processing**: Continue when app backgrounds
3. **Widgets**: Quick access to history
4. **Shortcuts**: Siri integration

## Development Guidelines

### Code Style
- Use SwiftUI property wrappers appropriately
- Prefer `@StateObject` for view-owned objects
- Use `@Published` for observable properties
- Extract reusable components
- Keep views under 200 lines

### Testing Approach
- Unit test data models
- UI test critical flows
- Mock network requests
- Test error states
- Verify persistence

### Performance
- Lazy load images
- Compress before upload
- Efficient thumbnail generation
- Minimize re-renders
- Profile memory usage

---

This documentation represents the current state of the ImageEdit app as of August 2025. For updates and contributions, please refer to the main repository.