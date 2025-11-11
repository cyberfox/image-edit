import io
import os
import uuid
import threading
import time
from datetime import datetime, timedelta
from typing import Optional, Dict, Any

from PIL import Image
import torch
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from concurrent.futures import ThreadPoolExecutor

from diffusers import QwenImageEditPlusPipeline

# -----------------------
# Config
# -----------------------
RESULTS_DIR = os.path.abspath("./results")
os.makedirs(RESULTS_DIR, exist_ok=True)

# Model timeout configuration (in minutes)
MODEL_TIMEOUT_MINUTES = float(os.environ.get("MODEL_TIMEOUT_MINUTES", "30"))

# Limit concurrent jobs; start with 1 to avoid OOM, raise to 2 if GPUs can handle it.
EXECUTOR = ThreadPoolExecutor(max_workers=1)

# -----------------------
# Shared job state
# -----------------------
class Job(BaseModel):
    id: str
    status: str            # "queued" | "running" | "succeeded" | "failed"
    progress: float = 0.0  # 0..100
    prompt: str
    created_at: str
    error: Optional[str] = None
    result_path: Optional[str] = None
    steps: int = 50

JOBS: Dict[str, Job] = {}
JOBS_LOCK = threading.Lock()

# -----------------------
# Model management
# -----------------------
PIPELINE: Optional[QwenImageEditPlusPipeline] = None
PIPELINE_LOCK = threading.Lock()
LAST_REQUEST_TIME = time.time()
UNLOAD_TIMER = None

def load_model():
    global PIPELINE
    print(f"Loading model... (timeout set to {MODEL_TIMEOUT_MINUTES} minutes)")
    PIPELINE = QwenImageEditPlusPipeline.from_pretrained(
        "Qwen/Qwen-Image-Edit-2509",
        torch_dtype=torch.bfloat16,
        device_map="balanced",     # or "auto", "balanced_low_0"
        # max_memory={0: "20GiB", 1: "20GiB"},  # uncomment/tune if needed
    )
    
    # Optional memory savers
    PIPELINE.enable_attention_slicing()
    PIPELINE.vae.enable_slicing()
    PIPELINE.vae.enable_tiling()
    # If you have xFormers and want it:
    # PIPELINE.enable_xformers_memory_efficient_attention()
    print("Model loaded successfully")

def unload_model():
    global PIPELINE
    if PIPELINE is not None:
        print("Unloading model from GPU memory...")
        del PIPELINE
        PIPELINE = None
        torch.cuda.empty_cache()
        print("Model unloaded successfully")

def check_and_unload_model():
    global UNLOAD_TIMER
    with PIPELINE_LOCK:
        current_time = time.time()
        if current_time - LAST_REQUEST_TIME >= MODEL_TIMEOUT_MINUTES * 60:
            unload_model()
        else:
            # Schedule next check
            schedule_unload_check()

def schedule_unload_check():
    global UNLOAD_TIMER
    if UNLOAD_TIMER is not None:
        UNLOAD_TIMER.cancel()
    UNLOAD_TIMER = threading.Timer(MODEL_TIMEOUT_MINUTES * 60, check_and_unload_model)
    UNLOAD_TIMER.daemon = True
    UNLOAD_TIMER.start()

def ensure_model_loaded():
    global LAST_REQUEST_TIME
    with PIPELINE_LOCK:
        LAST_REQUEST_TIME = time.time()
        if PIPELINE is None:
            load_model()
        schedule_unload_check()

# Load model on startup
ensure_model_loaded()

app = FastAPI(title="Qwen Image Edit API")

# Add CORS middleware for web app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for web interface
if os.path.exists("./static"):
    app.mount("/static", StaticFiles(directory="static", html=True), name="static")
    
    # Redirect root to web app
    from fastapi.responses import RedirectResponse
    
    @app.get("/")
    def read_root():
        return RedirectResponse(url="/static/index.html")

# -----------------------
# Helpers
# -----------------------
def _set_job(job_id: str, **updates: Any) -> None:
    with JOBS_LOCK:
        j = JOBS[job_id]
        for k, v in updates.items():
            setattr(j, k, v)

def _save_pil(img: Image.Image, job_id: str) -> str:
    filename = f"{job_id}.png"
    out_path = os.path.join(RESULTS_DIR, filename)
    img.save(out_path)
    return out_path

import inspect

def _run_edit(job_id, images, prompt, negative_prompt, steps, true_cfg_scale, seed):
    try:
        _set_job(job_id, status="running", progress=0.0)

        # Ensure model is loaded before processing
        ensure_model_loaded()

        gen = torch.manual_seed(seed) if seed is not None else torch.Generator(device="cuda")

        # discover what tensors the pipeline allows to pass into the callback
        allowed = []
        if hasattr(PIPELINE, "_callback_tensor_inputs"):
            # Common choices you'd want if present
            for name in ["latents", "prompt_embeds", "negative_prompt_embeds"]:
                if name in PIPELINE._callback_tensor_inputs:
                    allowed.append(name)

        # progress callback (fires every denoise step)
        def on_step_end(pipe, step, timestep, cb_kwargs):
            # step is 0-indexed; convert to percentage based on your requested steps
            pct = (step + 1) / max(steps, 1) * 100.0
            _set_job(job_id, progress=min(100.0, round(pct, 1)))
            return cb_kwargs  # important: must return this dict

        # Convert images to RGB - handle both single image and list
        if isinstance(images, list):
            processed_images = [img.convert("RGB") for img in images]
        else:
            processed_images = [images.convert("RGB")]

        call_kwargs = dict(
            image=processed_images,
            prompt=prompt,
            negative_prompt=negative_prompt,
            num_inference_steps=steps,
            true_cfg_scale=true_cfg_scale,
            generator=gen,
            callback_on_step_end=on_step_end,
        )
        # Only pass tensor list if we have any valid names; otherwise omit it.
        if allowed:
            call_kwargs["callback_on_step_end_tensor_inputs"] = allowed

        out = PIPELINE(**call_kwargs)

        img = out.images[0]
        path = _save_pil(img, job_id)
        _set_job(job_id, status="succeeded", result_path=path, progress=100.0)

    except Exception as e:
        _set_job(job_id, status="failed", error=str(e))

def old_run_edit(
    job_id: str,
    image: Image.Image,
    prompt: str,
    negative_prompt: str,
    steps: int,
    true_cfg_scale: float,
    seed: Optional[int],
):
    try:
        _set_job(job_id, status="running", progress=0.0)

        gen = torch.manual_seed(seed) if seed is not None else torch.Generator(device="cuda")

        # progress callback
        def cb(step: int, timestep: int, _latents):
            # step starts at 0; convert to percentage
            pct = (step + 1) / max(steps, 1) * 100.0
            _set_job(job_id, progress=min(100.0, pct))

        out = PIPELINE(
            image=image.convert("RGB"),
            prompt=prompt,
            negative_prompt=negative_prompt,
            num_inference_steps=steps,
            true_cfg_scale=true_cfg_scale,
            generator=gen,
            callback_on_step_end=lambda step, timestep, kwargs: _set_job(job_id, progress=(step+1)/steps*100),
            callback_on_step_end_tensor_inputs=["latents"],  # typical requirement
        )

        img = out.images[0]
        path = _save_pil(img, job_id)
        _set_job(job_id, status="succeeded", result_path=path, progress=100.0)

    except Exception as e:
        _set_job(job_id, status="failed", error=str(e))

# -----------------------
# Routes
# -----------------------
@app.get("/health")
def health():
    with PIPELINE_LOCK:
        model_loaded = PIPELINE is not None
        time_since_last_request = time.time() - LAST_REQUEST_TIME
        minutes_since_last_request = time_since_last_request / 60
    
    return {
        "ok": True,
        "model": "Qwen/Qwen-Image-Edit-2509",
        "model_loaded": model_loaded,
        "timeout_minutes": MODEL_TIMEOUT_MINUTES,
        "minutes_since_last_request": round(minutes_since_last_request, 2),
        "minutes_until_unload": round(max(0, MODEL_TIMEOUT_MINUTES - minutes_since_last_request), 2) if model_loaded else None
    }

@app.post("/model/unload")
def manual_unload():
    with PIPELINE_LOCK:
        if PIPELINE is not None:
            unload_model()
            return {"status": "Model unloaded successfully"}
        else:
            return {"status": "Model was not loaded"}

class SubmitResponse(BaseModel):
    job_id: str
    status: str

@app.post("/edit", response_model=SubmitResponse)
async def submit_edit(
    file: UploadFile = File(..., description="Input image (required)"),
    file2: Optional[UploadFile] = File(None, description="Optional second image"),
    file3: Optional[UploadFile] = File(None, description="Optional third image"),
    prompt: str = Form(...),
    negative_prompt: str = Form(" "),
    num_inference_steps: int = Form(50),
    true_cfg_scale: float = Form(4.0),
    seed: Optional[int] = Form(None),
):
    # Read images into PIL - build a list
    images = []

    # First image is required
    data = await file.read()
    try:
        image = Image.open(io.BytesIO(data)).convert("RGB")
        images.append(image)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image")

    # Second image is optional
    if file2:
        data2 = await file2.read()
        try:
            image2 = Image.open(io.BytesIO(data2)).convert("RGB")
            images.append(image2)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid second image")

    # Third image is optional
    if file3:
        data3 = await file3.read()
        try:
            image3 = Image.open(io.BytesIO(data3)).convert("RGB")
            images.append(image3)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid third image")

    job_id = uuid.uuid4().hex
    job = Job(
        id=job_id,
        status="queued",
        prompt=prompt,
        created_at=datetime.utcnow().isoformat(),
        steps=num_inference_steps,
    )
    with JOBS_LOCK:
        JOBS[job_id] = job

    # Enqueue work
    EXECUTOR.submit(
        _run_edit,
        job_id,
        images,
        prompt,
        negative_prompt,
        num_inference_steps,
        true_cfg_scale,
        seed,
    )

    return SubmitResponse(job_id=job_id, status="queued")

@app.get("/jobs/{job_id}")
def get_job(job_id: str):
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="job not found")
        # Don’t leak internal paths in public schema; include a public URL if done.
        payload = job.dict()
        if job.result_path and os.path.exists(job.result_path):
            filename = os.path.basename(job.result_path)
            payload["result_url"] = f"/results/{filename}"
        return JSONResponse(payload)

@app.get("/results/{filename}")
def get_result(filename: str):
    path = os.path.join(RESULTS_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="file not found")
    return FileResponse(path, media_type="image/png")
