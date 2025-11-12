"""
Test suite for image-edit-server.py

Tests the API endpoints and multi-image handling without requiring the actual model.
Run with: pytest test_server.py -v
"""

import pytest
import io
import os
import time
from PIL import Image
from fastapi.testclient import TestClient
from unittest.mock import Mock, patch, MagicMock
import sys
import importlib.util

# Create mock modules for diffusers and torch
mock_diffusers = MagicMock()
mock_torch = MagicMock()

# Add QwenImageEditPlusPipeline to the mock
mock_diffusers.QwenImageEditPlusPipeline = MagicMock()

sys.modules['diffusers'] = mock_diffusers
sys.modules['torch'] = mock_torch

# Import the server module using importlib since it has a hyphen in the name
spec = importlib.util.spec_from_file_location("image_edit_server", "image-edit-server.py")
server = importlib.util.module_from_spec(spec)

# Execute the module - this will run load_model() in test mode due to MODEL_SKIP_LOAD
os.environ['MODEL_SKIP_LOAD'] = '1'
spec.loader.exec_module(server)

app = server.app
JOBS = server.JOBS
JOBS_LOCK = server.JOBS_LOCK


@pytest.fixture
def client():
    """Create a test client"""
    return TestClient(app)


@pytest.fixture
def mock_pipeline():
    """Create a mock pipeline that simulates model behavior"""
    mock = Mock()

    # Mock the return value of the pipeline call
    mock_output = Mock()
    mock_output.images = [create_test_image()]
    mock.return_value = mock_output

    return mock


@pytest.fixture
def sample_image():
    """Create a sample PIL image for testing"""
    return create_test_image()


@pytest.fixture
def sample_image_bytes():
    """Create sample image bytes for upload"""
    img = create_test_image()
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='PNG')
    img_bytes.seek(0)
    return img_bytes


def create_test_image(width=100, height=100, color=(255, 0, 0)):
    """Helper to create a test image"""
    img = Image.new('RGB', (width, height), color)
    return img


def image_to_bytes(img):
    """Convert PIL image to bytes"""
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='PNG')
    img_bytes.seek(0)
    return img_bytes.getvalue()


class TestHealthEndpoint:
    """Test the /health endpoint"""

    def test_health_check(self, client):
        """Test basic health check"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["ok"] is True
        assert data["model"] == "Qwen/Qwen-Image-Edit-2509"
        assert "model_loaded" in data
        assert "timeout_minutes" in data

    def test_health_check_model_loaded(self, client):
        """Test health check shows model status"""
        with patch.object(server, 'PIPELINE', None):
            response = client.get("/health")
            data = response.json()
            assert data["model_loaded"] is False
            assert data["minutes_until_unload"] is None


class TestModelUnload:
    """Test the /model/unload endpoint"""

    def test_unload_when_loaded(self, client, mock_pipeline):
        """Test unloading when model is loaded"""
        with patch.object(server, 'PIPELINE', mock_pipeline):
            response = client.post("/model/unload")
            assert response.status_code == 200
            data = response.json()
            assert "unload" in data["status"].lower()

    def test_unload_when_not_loaded(self, client):
        """Test unloading when model is not loaded"""
        with patch.object(server, 'PIPELINE', None):
            response = client.post("/model/unload")
            assert response.status_code == 200
            data = response.json()
            assert "not loaded" in data["status"].lower()


class TestEditEndpoint:
    """Test the /edit endpoint with various image configurations"""

    def test_single_image_submission(self, client, sample_image_bytes):
        """Test submitting a single image"""
        with patch.object(server.EXECUTOR, 'submit') as mock_submit:
            response = client.post(
                "/edit",
                files={"file": ("test.png", sample_image_bytes, "image/png")},
                data={
                    "prompt": "make it blue",
                    "num_inference_steps": 30,
                    "true_cfg_scale": 4.0
                }
            )

            assert response.status_code == 200
            data = response.json()
            assert "job_id" in data
            assert data["status"] == "queued"

            # Verify the job was submitted
            mock_submit.assert_called_once()

            # Check the arguments passed to _run_edit
            # EXECUTOR.submit is called with (_run_edit, job_id, images, prompt, ...)
            args = mock_submit.call_args[0]
            # Skip the first arg (the function itself)
            _func, job_id, images, prompt, negative_prompt, steps, cfg, seed = args

            # Should have 1 image in the list
            assert len(images) == 1
            assert isinstance(images[0], Image.Image)
            assert prompt == "make it blue"
            assert steps == 30
            assert cfg == 4.0

    def test_two_images_submission(self, client):
        """Test submitting two images"""
        img1_bytes = image_to_bytes(create_test_image(color=(255, 0, 0)))
        img2_bytes = image_to_bytes(create_test_image(color=(0, 255, 0)))

        with patch.object(server.EXECUTOR, 'submit') as mock_submit:
            response = client.post(
                "/edit",
                files={
                    "file": ("img1.png", io.BytesIO(img1_bytes), "image/png"),
                    "file2": ("img2.png", io.BytesIO(img2_bytes), "image/png")
                },
                data={
                    "prompt": "combine image 1 and image 2",
                    "num_inference_steps": 50,
                    "true_cfg_scale": 4.0
                }
            )

            assert response.status_code == 200
            data = response.json()
            assert "job_id" in data

            # Check the arguments
            args = mock_submit.call_args[0]
            _func, job_id, images, prompt, negative_prompt, steps, cfg, seed = args

            # Should have 2 images
            assert len(images) == 2
            assert all(isinstance(img, Image.Image) for img in images)
            assert prompt == "combine image 1 and image 2"

    def test_three_images_submission(self, client):
        """Test submitting three images (maximum)"""
        img1_bytes = image_to_bytes(create_test_image(color=(255, 0, 0)))
        img2_bytes = image_to_bytes(create_test_image(color=(0, 255, 0)))
        img3_bytes = image_to_bytes(create_test_image(color=(0, 0, 255)))

        with patch.object(server.EXECUTOR, 'submit') as mock_submit:
            response = client.post(
                "/edit",
                files={
                    "file": ("img1.png", io.BytesIO(img1_bytes), "image/png"),
                    "file2": ("img2.png", io.BytesIO(img2_bytes), "image/png"),
                    "file3": ("img3.png", io.BytesIO(img3_bytes), "image/png")
                },
                data={
                    "prompt": "merge all three images",
                    "num_inference_steps": 50,
                    "true_cfg_scale": 4.0
                }
            )

            assert response.status_code == 200

            # Check the arguments
            args = mock_submit.call_args[0]
            _func, job_id, images, prompt, negative_prompt, steps, cfg, seed = args

            # Should have 3 images
            assert len(images) == 3
            assert all(isinstance(img, Image.Image) for img in images)

    def test_missing_required_image(self, client):
        """Test that first image is required"""
        response = client.post(
            "/edit",
            data={
                "prompt": "test",
                "num_inference_steps": 50,
                "true_cfg_scale": 4.0
            }
        )

        # Should return 422 (validation error) because 'file' is required
        assert response.status_code == 422

    def test_invalid_image_file(self, client):
        """Test submitting an invalid image file"""
        invalid_data = b"not an image"

        response = client.post(
            "/edit",
            files={"file": ("test.txt", io.BytesIO(invalid_data), "text/plain")},
            data={
                "prompt": "test",
                "num_inference_steps": 50,
                "true_cfg_scale": 4.0
            }
        )

        assert response.status_code == 400
        assert "Invalid image" in response.json()["detail"]

    def test_optional_parameters(self, client, sample_image_bytes):
        """Test optional parameters like seed"""
        with patch.object(server.EXECUTOR, 'submit') as mock_submit:
            response = client.post(
                "/edit",
                files={"file": ("test.png", sample_image_bytes, "image/png")},
                data={
                    "prompt": "test",
                    "num_inference_steps": 25,
                    "true_cfg_scale": 3.5,
                    "seed": 42
                }
            )

            assert response.status_code == 200

            # Check seed was passed
            args = mock_submit.call_args[0]
            # args[0] is the function, seed is at index 7
            seed = args[7]
            assert seed == 42


class TestJobStatus:
    """Test job status tracking"""

    def test_job_status_queued(self, client, sample_image_bytes):
        """Test checking status of a queued job"""
        with patch.object(server.EXECUTOR, 'submit'):
            # Submit a job
            response = client.post(
                "/edit",
                files={"file": ("test.png", sample_image_bytes, "image/png")},
                data={"prompt": "test", "num_inference_steps": 50, "true_cfg_scale": 4.0}
            )

            job_id = response.json()["job_id"]

            # Check job status
            response = client.get(f"/jobs/{job_id}")
            assert response.status_code == 200
            data = response.json()
            assert data["id"] == job_id
            assert data["status"] == "queued"
            assert data["prompt"] == "test"

    def test_job_not_found(self, client):
        """Test requesting a non-existent job"""
        response = client.get("/jobs/nonexistent")
        assert response.status_code == 404


class TestImageProcessing:
    """Test image processing logic"""

    def test_image_count_tracking(self, client):
        """Test that image_count field correctly reflects number of images submitted"""
        # Test single image
        img1_bytes = image_to_bytes(create_test_image(color=(255, 0, 0)))

        with patch.object(server.EXECUTOR, 'submit'):
            response = client.post(
                "/edit",
                files={"file": ("img1.png", io.BytesIO(img1_bytes), "image/png")},
                data={"prompt": "test", "num_inference_steps": 50, "true_cfg_scale": 4.0}
            )
            job_id_1 = response.json()["job_id"]

            # Check job reports 1 image
            job_response = client.get(f"/jobs/{job_id_1}")
            assert job_response.json()["image_count"] == 1

        # Test two images
        img2_bytes = image_to_bytes(create_test_image(color=(0, 255, 0)))

        with patch.object(server.EXECUTOR, 'submit'):
            response = client.post(
                "/edit",
                files={
                    "file": ("img1.png", io.BytesIO(img1_bytes), "image/png"),
                    "file2": ("img2.png", io.BytesIO(img2_bytes), "image/png")
                },
                data={"prompt": "test", "num_inference_steps": 50, "true_cfg_scale": 4.0}
            )
            job_id_2 = response.json()["job_id"]

            # Check job reports 2 images
            job_response = client.get(f"/jobs/{job_id_2}")
            assert job_response.json()["image_count"] == 2

        # Test three images
        img3_bytes = image_to_bytes(create_test_image(color=(0, 0, 255)))

        with patch.object(server.EXECUTOR, 'submit'):
            response = client.post(
                "/edit",
                files={
                    "file": ("img1.png", io.BytesIO(img1_bytes), "image/png"),
                    "file2": ("img2.png", io.BytesIO(img2_bytes), "image/png"),
                    "file3": ("img3.png", io.BytesIO(img3_bytes), "image/png")
                },
                data={"prompt": "test", "num_inference_steps": 50, "true_cfg_scale": 4.0}
            )
            job_id_3 = response.json()["job_id"]

            # Check job reports 3 images
            job_response = client.get(f"/jobs/{job_id_3}")
            assert job_response.json()["image_count"] == 3


class TestMultiImageIntegration:
    """Integration tests for multi-image workflow"""

    def test_full_workflow_single_image(self, client):
        """Test complete workflow with single image"""
        img_bytes = image_to_bytes(create_test_image())

        with patch.object(server.EXECUTOR, 'submit'):
            # Submit job
            response = client.post(
                "/edit",
                files={"file": ("test.png", io.BytesIO(img_bytes), "image/png")},
                data={"prompt": "make it pretty", "num_inference_steps": 30, "true_cfg_scale": 4.0}
            )

            assert response.status_code == 200
            job_id = response.json()["job_id"]

            # Check initial status
            response = client.get(f"/jobs/{job_id}")
            assert response.status_code == 200
            job_data = response.json()
            assert job_data["status"] == "queued"
            assert job_data["image_count"] == 1

    def test_full_workflow_multi_image(self, client):
        """Test complete workflow with multiple images"""
        img1_bytes = image_to_bytes(create_test_image(color=(255, 0, 0)))
        img2_bytes = image_to_bytes(create_test_image(color=(0, 255, 0)))
        img3_bytes = image_to_bytes(create_test_image(color=(0, 0, 255)))

        with patch.object(server.EXECUTOR, 'submit') as mock_submit:
            # Submit job with 3 images
            response = client.post(
                "/edit",
                files={
                    "file": ("img1.png", io.BytesIO(img1_bytes), "image/png"),
                    "file2": ("img2.png", io.BytesIO(img2_bytes), "image/png"),
                    "file3": ("img3.png", io.BytesIO(img3_bytes), "image/png")
                },
                data={
                    "prompt": "combine all images",
                    "num_inference_steps": 50,
                    "true_cfg_scale": 4.0
                }
            )

            assert response.status_code == 200
            job_id = response.json()["job_id"]

            # Verify job was created
            response = client.get(f"/jobs/{job_id}")
            assert response.status_code == 200
            job_data = response.json()
            assert job_data["prompt"] == "combine all images"
            assert job_data["image_count"] == 3

            # Verify correct number of images were passed
            args = mock_submit.call_args[0]
            _func, job_id, images = args[0], args[1], args[2]
            assert len(images) == 3


class TestBackwardCompatibility:
    """Test that old single-image clients still work"""

    def test_legacy_single_image_request(self, client, sample_image_bytes):
        """Test that old-style single image requests work"""
        with patch.object(server.EXECUTOR, 'submit') as mock_submit:
            response = client.post(
                "/edit",
                files={"file": ("image.png", sample_image_bytes, "image/png")},
                data={
                    "prompt": "enhance",
                    "num_inference_steps": 50,
                    "true_cfg_scale": 4.0
                }
            )

            assert response.status_code == 200

            # Should still work with 1 image in list
            args = mock_submit.call_args[0]
            _func, job_id, images = args[0], args[1], args[2]
            assert len(images) == 1
            assert isinstance(images[0], Image.Image)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
