# Claude Development Guide for ImageEdit

## Project Overview
ImageEdit is an iOS app and web application that uses AI to transform images via a Python server running the Qwen-Image-Edit-2509 model. The application supports both single-image and multi-image editing (up to 3 images).

## Key Components

### iOS App (Swift/SwiftUI)
- **ContentView.swift**: Main UI with expandable multi-image picker, prompt input, and generation controls
- **APIClient**: Handles server communication (health checks, multi-image submission, model unload)
- **HistoryManager**: Tracks generation history with Core Data
- **Settings**: User preferences for API endpoint and generation defaults

### Web App (HTML/CSS/JavaScript)
- **static/index.html**: Web interface with dynamic multi-image upload
- **static/app.js**: Client-side logic for image management and API calls
- **static/style.css**: Modern, responsive styling

### Python Server
- **server/image-edit-server.py**: FastAPI server with model management
- Uses `QwenImageEditPlusPipeline` from `Qwen/Qwen-Image-Edit-2509`
- Auto-loads model on first request
- Auto-unloads after timeout (default 30 minutes)
- Endpoints: `/edit`, `/health`, `/model/unload`, `/jobs/{id}`, `/results/{filename}`
- Supports 1-3 images per request

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
   - User selects 1-3 images and enters prompt
   - App submits to `/edit` endpoint (with `file`, `file2`, `file3` as needed)
   - Server processes images as a list and passes to model
   - Server queues job and returns job ID
   - App polls `/jobs/{id}` for progress
   - On completion, downloads result from `/results/{filename}`

4. **Multi-Image Editing** (New Feature):
   - Users can add up to 3 images per edit
   - First image is required, additional images are optional
   - Reference images in prompts using "image 1", "image 2", "image 3"
   - UI provides add/remove buttons for managing image slots
   - Backward compatible with single-image workflows
   - See `docs/MULTI_IMAGE_EDITING.md` for detailed usage guide

5. **Testing**: When testing locally, ensure:
   - Python server is running
   - iOS simulator/device can reach the server (use machine's IP, not localhost, for device testing)
   - Sufficient GPU memory is available for model

## Code Style Guidelines

- **Swift**: Follow existing SwiftUI patterns, use @StateObject/@State appropriately
- **Python**: FastAPI async patterns, proper error handling
- **UI**: Keep visual changes subtle and integrated with existing design
- **Comments**: Minimal - code should be self-documenting

## Recent Changes

- **Multi-Image Editing Support**: Upgraded to Qwen-Image-Edit-2509 model with support for 1-3 images per edit
  - iOS: Expandable image list with add/remove functionality
  - Web: Dynamic image slots with trash icons for removal
  - Smart UI hints for referencing multiple images in prompts
  - Full backward compatibility with single-image workflows
- Added server health check monitoring with visual status indicator
- Implemented model unload functionality with subtle UI button
- Added automatic health checks on app foreground
- Integrated history system with grid view and detail viewer

## Known Issues & TODOs

- Consider adding model preload option for better first-request performance
- Could add queue position indicator when multiple jobs are pending
- Potential for adding different model options in future