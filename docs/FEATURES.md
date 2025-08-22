# ImageEdit - Features Documentation

## Overview

ImageEdit is an AI-powered image transformation app that allows users to modify images using natural language prompts. This document details all implemented features and how to use them.

## Core Features

### 🎨 AI Image Transformation

Transform any image using text descriptions:

- **Select Image**: Tap "Select Image" to choose from your photo library
- **Write Prompt**: Describe how you want to transform the image
  - Example: "make it a winter scene with snow"
  - Example: "convert to cyberpunk style with neon lights"
  - Multi-line prompts supported
- **Adjust Settings**:
  - **Steps** (10-75): Higher = better quality but slower
  - **Guidance Scale** (1.0-8.0): Higher = follows prompt more closely
- **Generate**: Tap the purple "Generate" button

**Status Indicators**:
- 🔵 Blue: Processing/Uploading
- 🟢 Green: Ready/Success
- 🔴 Red: Error occurred

### 📱 Full-Screen Image Viewing

Both input and output images support full-screen viewing:

- **Access**: Tap any image or use the expand icon (↗️)
- **Gestures**:
  - Pinch to zoom (0.5x - 4x)
  - Pan when zoomed in
  - Double-tap to quick zoom
- **Actions**:
  - Share image
  - Save to Photos
  - Reset zoom

### ⚙️ Settings

Customize your experience:

#### API Configuration
- **Endpoint URL**: Configure your AI server address
  - Default: `http://huginn:8000`
  - Supports HTTP and HTTPS
  - Real-time validation

#### Default Generation Settings
- **Default Steps**: Set your preferred quality level
- **Default Guidance Scale**: Set prompt adherence level
- **Reset to Defaults**: One-tap reset option

Access: Tap the gear icon (⚙️) in the top right

### 📚 History Gallery

Automatic history of all generated images:

- **Grid View**: Beautiful thumbnail grid layout
- **Metadata Preserved**:
  - Original prompt
  - Generation settings
  - Creation date/time
  - API endpoint used
- **Actions**:
  - Tap thumbnail to view full screen
  - Info button (ℹ️) shows generation details
  - Clear all history option

Access: Tap the clock icon (🕐) in the top right

### 💾 Saving & Sharing

Multiple ways to save and share results:

- **Save to Photos**: Direct save to device photo library
- **Share Image**: iOS share sheet for any app
- **Share URL**: Share direct link to image
- **Open in Browser**: View in Safari

### 🎯 Smart Features

#### Automatic Thumbnail Generation
- 200x200 thumbnails for fast loading
- Stored locally for offline viewing
- Full images loaded on demand

#### Progress Tracking
- Real-time percentage updates
- Visual progress bar
- Animated status changes

#### Error Recovery
- Graceful error messages
- Network failure handling
- Automatic retries where applicable

#### State Persistence
- Settings saved automatically
- History preserved between launches
- Current values maintained

## User Interface

### Modern Design Language

- **Card-Based Layout**: Clean, organized sections
- **Gradient Buttons**: Visual feedback for actions
- **System Integration**: Matches iOS design
- **Dark Mode Support**: Full-screen viewers

### Animations & Feedback

- **Smooth Transitions**: Sheet presentations
- **Loading States**: Clear processing indicators
- **Success Feedback**: "Saved!" confirmations
- **Error Display**: Red warning cards

## Workflow Examples

### Basic Image Transformation

1. Launch app
2. Tap "Select Image" → Choose photo
3. Enter prompt: "make it look like a painting"
4. Adjust steps to 50 (default)
5. Tap "Generate"
6. Wait for processing
7. Save or share result

### Using Custom Settings

1. Tap Settings (⚙️)
2. Change default steps to 75
3. Change guidance to 6.0
4. Update API endpoint if needed
5. Tap "Done"
6. New images will use these defaults

### Browsing History

1. Tap History (🕐)
2. Scroll through generated images
3. Tap any thumbnail
4. View full screen with zoom
5. Tap (ℹ️) for generation details
6. Share or save as needed

## Tips & Best Practices

### Writing Effective Prompts

- **Be Specific**: "add snow" → "add heavy snowfall with snow-covered trees"
- **Describe Style**: Include artistic style references
- **Multiple Elements**: Can combine multiple transformations
- **Avoid Negatives**: Say what you want, not what you don't

### Optimal Settings

- **Quick Preview**: Steps: 20-30, CFG: 3-4
- **Balanced Quality**: Steps: 50, CFG: 4-5
- **High Quality**: Steps: 75, CFG: 6-7
- **Precise Control**: Steps: 50+, CFG: 7-8

### Performance Tips

- **Image Size**: Larger images take longer
- **Network**: Faster on WiFi vs cellular
- **Battery**: High step counts use more battery
- **Storage**: Clear old history periodically

## Troubleshooting

### Common Issues

**"Upload Failed"**
- Check internet connection
- Verify API endpoint in settings
- Try smaller image

**"Job Failed"**
- Server may be busy
- Try simpler prompt
- Reduce step count

**Slow Generation**
- High steps = longer wait
- Server load affects speed
- 3-5 minutes is normal for high quality

**Can't Save Image**
- Check Photos permission
- Ensure enough storage
- Try share sheet instead

## Privacy & Data

- **Local Storage**: History saved on device only
- **Photo Access**: Only when you select
- **Network**: Images sent to configured API only
- **No Analytics**: No tracking or analytics

## Keyboard Shortcuts

When text field is active:
- **Return**: New line in prompt
- **Cmd+Return**: Submit (on iPad with keyboard)

## Accessibility

- **VoiceOver**: Full support
- **Dynamic Type**: Text scales with system
- **Reduce Motion**: Respects system setting
- **Color Contrast**: WCAG AA compliant

---

For technical details and development information, see [ARCHITECTURE.md](./ARCHITECTURE.md)