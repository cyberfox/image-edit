# Claude Development Guide for ImageEdit

## Project Overview
ImageEdit is an iOS app that uses AI to transform images via a Python server running the Qwen-Image-Edit model.

## Key Components

### iOS App (Swift/SwiftUI)
- **ContentView.swift**: Main UI with image picker, prompt input, and generation controls
- **APIClient**: Handles server communication (health checks, image submission, model unload)
- **HistoryManager**: Tracks generation history with Core Data
- **Settings**: User preferences for API endpoint and generation defaults

### Python Server
- **server/image-edit-server.py**: FastAPI server with model management
- Auto-loads model on first request
- Auto-unloads after timeout (default 30 minutes)
- Endpoints: `/edit`, `/health`, `/model/unload`, `/jobs/{id}`, `/results/{filename}`

## Development Commands

### iOS Build & Test
```bash
# Build for simulator
xcodebuild -scheme ImageEdit -configuration Debug -sdk iphonesimulator -derivedDataPath build

# Run tests
xcodebuild test -scheme ImageEdit -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Server Operations
```bash
# Start server (from server/ directory)
python image-edit-server.py

# Server runs on http://localhost:8000 by default
# Set MODEL_TIMEOUT_MINUTES env var to change auto-unload time
```

## Important Considerations

1. **Model Memory Management**: The Qwen model requires significant GPU memory. The app includes:
   - Health check polling to show model status
   - Manual unload button (moon icon) to free memory
   - Auto-unload after inactivity timeout

2. **API Endpoint Configuration**: Users can configure the server endpoint in Settings. Default is `http://localhost:8000`

3. **Image Processing Flow**:
   - User selects image and enters prompt
   - App submits to `/edit` endpoint
   - Server queues job and returns job ID
   - App polls `/jobs/{id}` for progress
   - On completion, downloads result from `/results/{filename}`

4. **Testing**: When testing locally, ensure:
   - Python server is running
   - iOS simulator/device can reach the server (use machine's IP, not localhost, for device testing)
   - Sufficient GPU memory is available for model

## Code Style Guidelines

- **Swift**: Follow existing SwiftUI patterns, use @StateObject/@State appropriately
- **Python**: FastAPI async patterns, proper error handling
- **UI**: Keep visual changes subtle and integrated with existing design
- **Comments**: Minimal - code should be self-documenting

## Recent Changes

- Added server health check monitoring with visual status indicator
- Implemented model unload functionality with subtle UI button
- Added automatic health checks on app foreground
- Integrated history system with grid view and detail viewer

## Known Issues & TODOs

- Consider adding model preload option for better first-request performance
- Could add queue position indicator when multiple jobs are pending
- Potential for adding different model options in future