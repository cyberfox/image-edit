# Web Application Documentation

## Overview

The ImageEdit web application provides a browser-based interface for AI-powered image editing, mirroring the functionality of the iOS app. It connects to the same Python server backend and offers real-time image transformation using the Qwen-Image-Edit model.

## Features

### Core Functionality
- **Image Upload**: Drag-and-drop or click to upload images
- **AI Transformation**: Enter natural language prompts to describe desired changes
- **Real-time Progress**: Monitor generation progress with live updates
- **Result Management**: View and download generated images

### Advanced Features
- **Server Health Monitoring**: Real-time model status indicator
- **Model Management**: Manual unload button to free GPU memory
- **Adjustable Parameters**:
  - Steps (10-75): Controls generation quality vs speed
  - Guidance Scale (1.0-8.0): Controls prompt adherence

## User Interface

### Layout Components

1. **Header Section**
   - Application title and subtitle
   - Server status indicator (green = model loaded, orange = unloaded)
   - Time until auto-unload display
   - Model unload button (moon icon)

2. **Image Upload Card**
   - Large upload button with visual feedback
   - Image preview with automatic resizing
   - Support for common image formats (JPG, PNG, etc.)

3. **Prompt Input Card**
   - Multi-line text area for transformation instructions
   - Auto-expanding based on content

4. **Settings Card**
   - Steps slider with real-time value display
   - Guidance scale slider with decimal precision
   - Visual feedback for current values

5. **Generate Button**
   - Disabled state when no image is selected
   - Loading animation during processing
   - Visual transformation on hover

6. **Progress Card** (appears during generation)
   - Status text with emoji indicators
   - Percentage complete
   - Animated progress bar

7. **Result Card** (appears after generation)
   - Full-size result preview
   - Download button for saving locally
   - "New Edit" button to reset with same image

## Technical Architecture

### Frontend Stack
- **HTML5**: Semantic structure with accessibility considerations
- **CSS3**: Modern styling with gradients, animations, and responsive design
- **Vanilla JavaScript**: No framework dependencies for maximum compatibility

### API Integration
- **REST API**: Communication with FastAPI backend
- **Polling**: Status updates every 2 seconds during generation
- **Health Checks**: Server status updates every 30 seconds

### File Structure
```
server/
├── static/
│   ├── index.html      # Main HTML structure
│   ├── app.js          # Application logic
│   └── style.css       # Styling and animations
├── image-edit-server.py # Backend server
└── requirements.txt     # Python dependencies
```

## Usage Guide

### Starting the Web App

1. **Install Dependencies**
   ```bash
   cd server
   pip install -r requirements.txt
   ```

2. **Start the Server**
   ```bash
   uvicorn image-edit-server:app --host 0.0.0.0 --port 8000
   ```

3. **Access the Interface**
   - Open browser to `http://localhost:8000`
   - Or use machine IP for network access: `http://[YOUR-IP]:8000`

### Basic Workflow

1. **Upload an Image**
   - Click "Select Image" button
   - Choose an image file from your device
   - Preview appears automatically

2. **Enter Transformation Prompt**
   - Describe the desired changes in natural language
   - Examples:
     - "Make it a winter scene with snow"
     - "Change the background to a beach"
     - "Add a sunset in the background"

3. **Adjust Settings** (Optional)
   - **Steps**: Higher = better quality but slower
   - **Guidance Scale**: Higher = stricter prompt following

4. **Generate**
   - Click "Generate" button
   - Monitor progress in real-time
   - Wait for completion (typically 30-60 seconds)

5. **Save Results**
   - Click "Download" to save the generated image
   - Click "New Edit" to try another transformation

### Advanced Features

#### Model Management
- **Check Status**: Look at the header status indicator
- **Manual Unload**: Click moon icon when model is loaded
- **Auto-unload**: Model unloads after 30 minutes of inactivity

#### Keyboard Shortcuts
- `Enter` in prompt field: Start generation (when image is loaded)
- `Escape`: Cancel current operation (if supported by browser)

## Browser Compatibility

### Supported Browsers
- Chrome 90+ (Recommended)
- Safari 14+
- Firefox 88+
- Edge 90+

### Mobile Support
- Responsive design for phones and tablets
- Touch-optimized controls
- Automatic viewport adjustment

## Performance Considerations

### Client-Side
- Images are compressed before upload
- Lazy loading for result images
- Efficient DOM updates

### Network
- Automatic retry on connection failure
- Progress preserved during brief disconnections
- Compressed responses from server

## Troubleshooting

### Common Issues

1. **"Failed to submit job"**
   - Check server is running
   - Verify network connectivity
   - Ensure image format is supported

2. **Model Not Loading**
   - Check GPU memory availability
   - Verify CUDA installation
   - Review server logs for errors

3. **Slow Generation**
   - Normal for high step counts
   - Model loads on first request (30-60s)
   - Consider reducing steps for faster results

### Debug Mode
Open browser console to see:
- API request/response details
- Health check status
- Error messages with stack traces

## Security Notes

- No user data is permanently stored
- Images are processed in memory
- Results are stored temporarily in `results/` directory
- CORS configured for development (restrict in production)

## Comparison with iOS App

| Feature | Web App | iOS App |
|---------|---------|---------|
| Image Selection | File picker | Photos library |
| Progress Display | Progress bar | Progress bar |
| Result Saving | Download | Photos library |
| History | Not implemented | Core Data storage |
| Offline Support | No | No |
| Model Status | ✓ | ✓ |
| Manual Unload | ✓ | ✓ |

## Future Enhancements

- Batch processing support
- Image history with local storage
- Preset prompt templates
- Advanced editing tools (crop, rotate)
- WebSocket for real-time updates
- PWA support for offline capability