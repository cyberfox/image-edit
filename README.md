# ImageEdit

An AI-powered image editing application with iOS and web interfaces that uses natural language prompts to transform images.

## Features

- 🎨 **Natural Language Editing**: Describe changes in plain English
- 📱 **iOS App**: Native SwiftUI application with full Photos integration
- 🌐 **Web App**: Browser-based interface accessible from any device
- 🤖 **Powered by Qwen-Image-Edit**: State-of-the-art AI model for image transformation
- 📊 **Real-time Progress**: Monitor generation status and progress
- 💾 **Smart Memory Management**: Automatic model loading/unloading to optimize GPU usage
- 🕐 **History Tracking**: Keep track of all your edits (iOS only)

## Quick Start

### Server Setup

1. **Install Python dependencies:**
   ```bash
   cd server
   pip install -r requirements.txt
   ```

2. **Start the server:**
   ```bash
   uvicorn image-edit-server:app --host 0.0.0.0 --port 8000
   ```

3. **Access the web app:**
   Open your browser to `http://localhost:8000`

### iOS App

1. Open `ImageEdit.xcodeproj` in Xcode
2. Build and run on simulator or device
3. Configure server endpoint in Settings if needed

## Project Structure

```
ImageEdit/
├── ImageEdit/              # iOS app source code
│   ├── ContentView.swift   # Main UI
│   ├── HistoryManager.swift # Edit history
│   └── Settings.swift      # User preferences
├── server/                 # Python backend
│   ├── image-edit-server.py # FastAPI server
│   ├── static/            # Web app files
│   │   ├── index.html     # Web interface
│   │   ├── app.js         # JavaScript logic
│   │   └── style.css      # Styling
│   └── requirements.txt   # Python dependencies
└── docs/                  # Documentation
    ├── architecture.md    # System design
    ├── api.md            # API reference
    └── web-app.md        # Web app guide
```

## System Requirements

### Server
- Python 3.8+
- CUDA-capable GPU (8GB+ VRAM recommended)
- 16GB+ system RAM

### iOS App
- iOS 18.5+
- iPhone or iPad
- Xcode 15+ for development

### Web App
- Modern web browser (Chrome, Safari, Firefox, Edge)
- JavaScript enabled

## Key Features

### Model Management
- **Auto-load**: Model loads on first request
- **Auto-unload**: Frees GPU memory after 30 minutes of inactivity
- **Manual control**: Unload button in both iOS and web interfaces
- **Status monitoring**: Real-time model status display

### Image Processing
- Supports common formats (JPEG, PNG)
- Configurable generation parameters
- Progress tracking with percentage updates
- Queue system for multiple requests

## API Endpoints

- `GET /` - Web application
- `GET /health` - Server and model status
- `POST /edit` - Submit image for editing
- `GET /jobs/{id}` - Check job status
- `GET /results/{filename}` - Download result
- `POST /model/unload` - Manually unload model

## Environment Variables

- `MODEL_TIMEOUT_MINUTES` - Minutes before auto-unload (default: 30)

## Development

See [CLAUDE.md](CLAUDE.md) for AI assistant development guidelines.

## Documentation

- [Architecture Overview](docs/architecture.md)
- [API Documentation](docs/api.md)
- [Web App Guide](docs/web-app.md)

## License

MIT