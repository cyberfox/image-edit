# Testing the Image Edit Server

This guide explains how to test the server-side code without requiring the actual AI model to be loaded.

## Overview

The server can be tested in several ways:
1. **Manual testing** - Interactive testing with a running server
2. **Automated tests** - Unit and integration tests with pytest
3. **API testing** - Direct HTTP requests with curl or Postman

## Quick Start: Manual Testing

The easiest way to test without the model is using the manual test script:

### 1. Start the Server (Skip Model Loading)

```bash
cd server
MODEL_SKIP_LOAD=1 python image-edit-server.py
```

**Note**: The `MODEL_SKIP_LOAD` environment variable tells the server to skip loading the heavy AI model. This allows you to test all the API logic, request handling, and multi-image processing without GPU requirements.

### 2. Run the Manual Test Suite

In another terminal:

```bash
cd server
python manual_test.py
```

This will test:
- ✓ Health check endpoint
- ✓ Single image submission
- ✓ Dual image submission (multi-image feature)
- ✓ Triple image submission (max 3 images)
- ✓ Job status tracking
- ✓ Error handling (invalid images, missing files)

### Expected Output

```
============================================================
Image Edit Server - Manual Test Suite
============================================================

=== Testing /health endpoint ===
✓ Health check passed
  Model: Qwen/Qwen-Image-Edit-2509
  Model loaded: False
  Timeout: 30.0 minutes

=== Testing single image submission ===
✓ Single image submission succeeded
  Job ID: abc123...
  Status: queued

=== Testing dual image submission ===
✓ Dual image submission succeeded
  Job ID: def456...
  Status: queued

...

============================================================
Test Results: 7/7 tests passed
============================================================
✓ All tests passed!
```

## Testing with curl

You can also test endpoints manually with curl:

### Health Check
```bash
curl http://localhost:8000/health | jq
```

### Single Image
```bash
# Create a test image
convert -size 200x200 xc:red test.png

# Submit for editing
curl -X POST http://localhost:8000/edit \
  -F "file=@test.png" \
  -F "prompt=make it blue" \
  -F "num_inference_steps=30" \
  -F "true_cfg_scale=4.0"
```

### Multiple Images
```bash
# Create test images
convert -size 200x200 xc:red img1.png
convert -size 200x200 xc:green img2.png

# Submit multiple images
curl -X POST http://localhost:8000/edit \
  -F "file=@img1.png" \
  -F "file2=@img2.png" \
  -F "prompt=combine image 1 and image 2" \
  -F "num_inference_steps=50" \
  -F "true_cfg_scale=4.0"
```

### Check Job Status
```bash
curl http://localhost:8000/jobs/YOUR_JOB_ID | jq
```

## Automated Testing with pytest

For more comprehensive testing:

### 1. Install Test Dependencies

```bash
cd server
pip install -r test_requirements.txt
```

### 2. Run Tests

```bash
pytest test_server.py -v
```

### Test Coverage

The test suite covers:
- **API Endpoints**: All `/edit`, `/health`, `/jobs`, `/results` endpoints
- **Multi-Image Handling**: 1, 2, and 3 image submissions
- **Request Validation**: Required fields, invalid data, error handling
- **Job Management**: Job creation, status tracking, result retrieval
- **Backward Compatibility**: Single-image requests still work

## Testing Strategy

### What Gets Tested WITHOUT the Model

✓ **Request parsing** - Multipart form data with 1-3 images
✓ **Image validation** - Valid image files vs invalid data
✓ **API logic** - Endpoint routing, parameter validation
✓ **Job queuing** - Job creation and status tracking
✓ **Multi-image flow** - Correct number of images passed through
✓ **Error handling** - Missing files, invalid formats, etc.

### What Requires the Model

✗ Actual image generation
✗ Model inference performance
✗ Output quality

The model can be mocked in tests, allowing you to verify that:
- Images are correctly parsed and passed to the model
- The pipeline is called with the right parameters
- Results are properly saved and returned

## Testing Multi-Image Functionality

### Test Case: Two Images

```python
# The server should:
# 1. Accept file and file2 parameters
# 2. Parse both images successfully
# 3. Pass them as a list to the model
# 4. Return a single job ID

import requests

response = requests.post(
    "http://localhost:8000/edit",
    files={
        "file": ("img1.png", open("img1.png", "rb"), "image/png"),
        "file2": ("img2.png", open("img2.png", "rb"), "image/png")
    },
    data={
        "prompt": "combine these images",
        "num_inference_steps": 50,
        "true_cfg_scale": 4.0
    }
)

assert response.status_code == 200
data = response.json()
assert "job_id" in data
assert data["status"] == "queued"
```

### Test Case: Maximum Images (3)

```python
# Test the 3-image limit
response = requests.post(
    "http://localhost:8000/edit",
    files={
        "file": ("img1.png", img1_bytes, "image/png"),
        "file2": ("img2.png", img2_bytes, "image/png"),
        "file3": ("img3.png", img3_bytes, "image/png")
    },
    data={
        "prompt": "merge all three",
        "num_inference_steps": 50,
        "true_cfg_scale": 4.0
    }
)

assert response.status_code == 200
```

## Debugging Tips

### Check Server Logs

When testing, watch the server output for:
- Image parsing messages
- Job queue status
- Error messages

### Use Verbose Mode

```bash
uvicorn image-edit-server:app --reload --log-level debug
```

### Test Individual Endpoints

Test one endpoint at a time to isolate issues:

```bash
# Just health
curl http://localhost:8000/health

# Just single image
python -c "
import requests
from PIL import Image
import io

img = Image.new('RGB', (100, 100), (255, 0, 0))
buf = io.BytesIO()
img.save(buf, 'PNG')
buf.seek(0)

r = requests.post('http://localhost:8000/edit',
    files={'file': ('test.png', buf, 'image/png')},
    data={'prompt': 'test', 'num_inference_steps': 30, 'true_cfg_scale': 4.0})
print(r.json())
"
```

## Common Issues

### Issue: Tests fail with "Connection refused"
**Solution**: Make sure the server is running on port 8000

### Issue: Tests pass but no images generated
**Solution**: This is expected when MODEL_SKIP_LOAD=1. The tests verify API logic only.

### Issue: "Invalid image" errors
**Solution**: Ensure you're sending valid PNG/JPEG files with proper MIME types

### Issue: Jobs stuck in "queued" status
**Solution**: Without the model loaded, jobs won't progress. This is normal for testing.

## Next Steps

Once API testing passes:

1. **Load the actual model** - Remove MODEL_SKIP_LOAD
2. **Test with real images** - Use actual photos
3. **Verify outputs** - Check generated image quality
4. **Performance testing** - Test with multiple concurrent requests

## See Also

- [Multi-Image Editing Guide](../docs/MULTI_IMAGE_EDITING.md)
- [API Documentation](../docs/api.md)
- [Server README](README.md)
