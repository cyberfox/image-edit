#!/usr/bin/env python3
"""
Manual testing script for the image-edit server API endpoints.

This script tests the server's request handling and multi-image logic
WITHOUT requiring the actual AI model to be loaded.

Usage:
    python manual_test.py

The script will:
1. Create mock test images
2. Test single, dual, and triple image uploads
3. Verify the server correctly processes multi-image requests
4. Check job status tracking

Note: Start the server with MODEL_SKIP_LOAD=1 to skip model loading:
    MODEL_SKIP_LOAD=1 python image-edit-server.py
"""

import io
import sys
import requests
from PIL import Image


def create_test_image(width=200, height=200, color=(255, 0, 0)):
    """Create a test image with specified color"""
    img = Image.new('RGB', (width, height), color)
    return img


def image_to_bytes(img, format='PNG'):
    """Convert PIL image to bytes"""
    buffer = io.BytesIO()
    img.save(buffer, format=format)
    buffer.seek(0)
    return buffer


def test_health_check(base_url):
    """Test the /health endpoint"""
    print("\n=== Testing /health endpoint ===")
    try:
        response = requests.get(f"{base_url}/health")
        data = response.json()
        print(f"✓ Health check passed")
        print(f"  Model: {data['model']}")
        print(f"  Model loaded: {data['model_loaded']}")
        print(f"  Timeout: {data['timeout_minutes']} minutes")
        return True
    except Exception as e:
        print(f"✗ Health check failed: {e}")
        return False


def test_single_image(base_url):
    """Test single image submission"""
    print("\n=== Testing single image submission ===")

    # Create a red test image
    img = create_test_image(color=(255, 0, 0))
    img_bytes = image_to_bytes(img)

    try:
        response = requests.post(
            f"{base_url}/edit",
            files={"file": ("test.png", img_bytes, "image/png")},
            data={
                "prompt": "make it beautiful",
                "num_inference_steps": 30,
                "true_cfg_scale": 4.0
            }
        )

        if response.status_code == 200:
            data = response.json()
            print(f"✓ Single image submission succeeded")
            print(f"  Job ID: {data['job_id']}")
            print(f"  Status: {data['status']}")
            return data['job_id']
        else:
            print(f"✗ Single image submission failed: {response.status_code}")
            print(f"  Response: {response.text}")
            return None

    except Exception as e:
        print(f"✗ Single image submission error: {e}")
        return None


def test_dual_image(base_url):
    """Test dual image submission"""
    print("\n=== Testing dual image submission ===")

    # Create two test images with different colors
    img1 = create_test_image(color=(255, 0, 0))  # Red
    img2 = create_test_image(color=(0, 255, 0))  # Green

    try:
        response = requests.post(
            f"{base_url}/edit",
            files={
                "file": ("img1.png", image_to_bytes(img1), "image/png"),
                "file2": ("img2.png", image_to_bytes(img2), "image/png")
            },
            data={
                "prompt": "combine the subject from image 1 with the background from image 2",
                "num_inference_steps": 50,
                "true_cfg_scale": 4.0
            }
        )

        if response.status_code == 200:
            data = response.json()
            print(f"✓ Dual image submission succeeded")
            print(f"  Job ID: {data['job_id']}")
            print(f"  Status: {data['status']}")
            return data['job_id']
        else:
            print(f"✗ Dual image submission failed: {response.status_code}")
            print(f"  Response: {response.text}")
            return None

    except Exception as e:
        print(f"✗ Dual image submission error: {e}")
        return None


def test_triple_image(base_url):
    """Test triple image submission (maximum)"""
    print("\n=== Testing triple image submission ===")

    # Create three test images with different colors
    img1 = create_test_image(color=(255, 0, 0))    # Red
    img2 = create_test_image(color=(0, 255, 0))    # Green
    img3 = create_test_image(color=(0, 0, 255))    # Blue

    try:
        response = requests.post(
            f"{base_url}/edit",
            files={
                "file": ("img1.png", image_to_bytes(img1), "image/png"),
                "file2": ("img2.png", image_to_bytes(img2), "image/png"),
                "file3": ("img3.png", image_to_bytes(img3), "image/png")
            },
            data={
                "prompt": "merge image 1, image 2, and image 3 together",
                "num_inference_steps": 50,
                "true_cfg_scale": 4.0,
                "seed": 42
            }
        )

        if response.status_code == 200:
            data = response.json()
            print(f"✓ Triple image submission succeeded")
            print(f"  Job ID: {data['job_id']}")
            print(f"  Status: {data['status']}")
            return data['job_id']
        else:
            print(f"✗ Triple image submission failed: {response.status_code}")
            print(f"  Response: {response.text}")
            return None

    except Exception as e:
        print(f"✗ Triple image submission error: {e}")
        return None


def test_job_status(base_url, job_id):
    """Test job status retrieval"""
    print(f"\n=== Testing job status for {job_id} ===")

    try:
        response = requests.get(f"{base_url}/jobs/{job_id}")

        if response.status_code == 200:
            data = response.json()
            print(f"✓ Job status retrieved")
            print(f"  ID: {data['id']}")
            print(f"  Status: {data['status']}")
            print(f"  Progress: {data['progress']}%")
            print(f"  Prompt: {data['prompt'][:50]}...")
            return True
        else:
            print(f"✗ Job status retrieval failed: {response.status_code}")
            return False

    except Exception as e:
        print(f"✗ Job status error: {e}")
        return False


def test_invalid_image(base_url):
    """Test that invalid images are rejected"""
    print("\n=== Testing invalid image handling ===")

    invalid_data = b"This is not an image file"

    try:
        response = requests.post(
            f"{base_url}/edit",
            files={"file": ("test.txt", io.BytesIO(invalid_data), "text/plain")},
            data={
                "prompt": "test",
                "num_inference_steps": 50,
                "true_cfg_scale": 4.0
            }
        )

        if response.status_code == 400:
            print(f"✓ Invalid image correctly rejected")
            print(f"  Error: {response.json()['detail']}")
            return True
        else:
            print(f"✗ Invalid image not rejected (status: {response.status_code})")
            return False

    except Exception as e:
        print(f"✗ Invalid image test error: {e}")
        return False


def test_missing_file(base_url):
    """Test that missing file is rejected"""
    print("\n=== Testing missing file handling ===")

    try:
        response = requests.post(
            f"{base_url}/edit",
            data={
                "prompt": "test",
                "num_inference_steps": 50,
                "true_cfg_scale": 4.0
            }
        )

        if response.status_code == 422:  # Validation error
            print(f"✓ Missing file correctly rejected")
            return True
        else:
            print(f"✗ Missing file not rejected (status: {response.status_code})")
            return False

    except Exception as e:
        print(f"✗ Missing file test error: {e}")
        return False


def main():
    """Run all tests"""
    base_url = "http://localhost:8000"

    print("=" * 60)
    print("Image Edit Server - Manual Test Suite")
    print("=" * 60)
    print(f"\nTesting server at: {base_url}")
    print("\nNote: Make sure the server is running!")
    print("      Use: MODEL_SKIP_LOAD=1 python image-edit-server.py")
    print("      to skip model loading during testing")

    # Test health check first
    if not test_health_check(base_url):
        print("\n⚠ Server not responding. Make sure it's running!")
        sys.exit(1)

    # Run all tests
    tests_passed = 0
    tests_total = 0

    # Test single image
    tests_total += 1
    job_id = test_single_image(base_url)
    if job_id:
        tests_passed += 1
        # Test job status
        tests_total += 1
        if test_job_status(base_url, job_id):
            tests_passed += 1

    # Test dual image
    tests_total += 1
    job_id = test_dual_image(base_url)
    if job_id:
        tests_passed += 1

    # Test triple image
    tests_total += 1
    job_id = test_triple_image(base_url)
    if job_id:
        tests_passed += 1

    # Test error handling
    tests_total += 1
    if test_invalid_image(base_url):
        tests_passed += 1

    tests_total += 1
    if test_missing_file(base_url):
        tests_passed += 1

    # Summary
    print("\n" + "=" * 60)
    print(f"Test Results: {tests_passed}/{tests_total} tests passed")
    print("=" * 60)

    if tests_passed == tests_total:
        print("✓ All tests passed!")
        return 0
    else:
        print(f"✗ {tests_total - tests_passed} test(s) failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
