"""
Test suite for image-edit-server.py

Tests the API endpoints and multi-image handling without requiring the actual model.
Run with: pytest test_server.py -v
"""

import pytest
import io
import time
from PIL import Image
from fastapi.testclient import TestClient
from unittest.mock import Mock, patch, MagicMock
import sys

# Mock the diffusers import before importing the server
sys.modules['diffusers'] = MagicMock()

# Now we can import the server module
# We'll need to patch PIPELINE before the server loads the model
with patch('image-edit-server.load_model'):
    with patch('image-edit-server.ensure_model_loaded'):
        import image_edit_server as server
        from image_edit_server import app, JOBS, JOBS_LOCK


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
        with patch('image_edit_server.PIPELINE', None):
            response = client.get("/health")
            data = response.json()
            assert data["model_loaded"] is False
            assert data["minutes_until_unload"] is None


class TestModelUnload:
    """Test the /model/unload endpoint"""

    def test_unload_when_loaded(self, client, mock_pipeline):
        """Test unloading when model is loaded"""
        with patch('image_edit_server.PIPELINE', mock_pipeline):
            response = client.post("/model/unload")
            assert response.status_code == 200
            data = response.json()
            assert "unload" in data["status"].lower()

    def test_unload_when_not_loaded(self, client):
        """Test unloading when model is not loaded"""
        with patch('image_edit_server.PIPELINE', None):
            response = client.post("/model/unload")
            assert response.status_code == 200
            data = response.json()
            assert "not loaded" in data["status"].lower()


class TestEditEndpoint:
    """Test the /edit endpoint with various image configurations"""

    def test_single_image_submission(self, client, sample_image_bytes):
        """Test submitting a single image"""
        with patch('image_edit_server.EXECUTOR.submit') as mock_submit:
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
            args = mock_submit.call_args[0]
            job_id, images, prompt, negative_prompt, steps, cfg, seed = args

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

        with patch('image_edit_server.EXECUTOR.submit') as mock_submit:
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
            job_id, images, prompt, negative_prompt, steps, cfg, seed = args

            # Should have 2 images
            assert len(images) == 2
            assert all(isinstance(img, Image.Image) for img in images)
            assert prompt == "combine image 1 and image 2"

    def test_three_images_submission(self, client):
        """Test submitting three images (maximum)"""
        img1_bytes = image_to_bytes(create_test_image(color=(255, 0, 0)))
        img2_bytes = image_to_bytes(create_test_image(color=(0, 255, 0)))
        img3_bytes = image_to_bytes(create_test_image(color=(0, 0, 255)))

        with patch('image_edit_server.EXECUTOR.submit') as mock_submit:
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
            job_id, images, prompt, negative_prompt, steps, cfg, seed = args

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
        with patch('image_edit_server.EXECUTOR.submit') as mock_submit:
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
            seed = args[6]
            assert seed == 42


class TestJobStatus:
    """Test job status tracking"""

    def test_job_status_queued(self, client, sample_image_bytes):
        """Test checking status of a queued job"""
        with patch('image_edit_server.EXECUTOR.submit'):
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

    def test_image_list_handling(self):
        """Test that images are correctly converted to list"""
        from image_edit_server import _run_edit

        # Create test images
        img1 = create_test_image(color=(255, 0, 0))
        img2 = create_test_image(color=(0, 255, 0))
        images = [img1, img2]

        job_id = "test_job"

        # Mock the pipeline and job setting
        mock_pipeline = Mock()
        mock_output = Mock()
        mock_output.images = [create_test_image()]
        mock_pipeline.return_value = mock_output

        with patch('image_edit_server.PIPELINE', mock_pipeline):
            with patch('image_edit_server._set_job'):
                with patch('image_edit_server._save_pil') as mock_save:
                    with patch('image_edit_server.ensure_model_loaded'):
                        mock_save.return_value = "/tmp/result.png"

                        _run_edit(
                            job_id, images, "test prompt", "", 50, 4.0, None
                        )

                        # Check pipeline was called with list of images
                        assert mock_pipeline.called
                        call_kwargs = mock_pipeline.call_args[1]

                        # Should receive a list of RGB images
                        assert 'image' in call_kwargs
                        processed_images = call_kwargs['image']
                        assert isinstance(processed_images, list)
                        assert len(processed_images) == 2
                        assert all(img.mode == 'RGB' for img in processed_images)


class TestMultiImageIntegration:
    """Integration tests for multi-image workflow"""

    def test_full_workflow_single_image(self, client):
        """Test complete workflow with single image"""
        img_bytes = image_to_bytes(create_test_image())

        with patch('image_edit_server.EXECUTOR.submit'):
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
            assert response.json()["status"] == "queued"

    def test_full_workflow_multi_image(self, client):
        """Test complete workflow with multiple images"""
        img1_bytes = image_to_bytes(create_test_image(color=(255, 0, 0)))
        img2_bytes = image_to_bytes(create_test_image(color=(0, 255, 0)))
        img3_bytes = image_to_bytes(create_test_image(color=(0, 0, 255)))

        with patch('image_edit_server.EXECUTOR.submit') as mock_submit:
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

            # Verify correct number of images were passed
            args = mock_submit.call_args[0]
            images = args[1]
            assert len(images) == 3


class TestBackwardCompatibility:
    """Test that old single-image clients still work"""

    def test_legacy_single_image_request(self, client, sample_image_bytes):
        """Test that old-style single image requests work"""
        with patch('image_edit_server.EXECUTOR.submit') as mock_submit:
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
            images = args[1]
            assert len(images) == 1
            assert isinstance(images[0], Image.Image)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
