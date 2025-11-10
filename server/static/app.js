// API endpoints
const API_BASE = window.location.origin;

// State
let selectedFiles = [null, null, null]; // Support up to 3 images
let activeImageCount = 1; // Start with 1 image slot
let currentJobId = null;
let pollInterval = null;
let healthCheckInterval = null;

// Elements
const imageSlots = document.getElementById('imageSlots');
const addImageBtn = document.getElementById('addImageBtn');
const addImageBtnText = document.getElementById('addImageBtnText');
const multiImageTip = document.getElementById('multiImageTip');
const promptInput = document.getElementById('promptInput');
const stepsSlider = document.getElementById('stepsSlider');
const stepsValue = document.getElementById('stepsValue');
const cfgSlider = document.getElementById('cfgSlider');
const cfgValue = document.getElementById('cfgValue');
const generateBtn = document.getElementById('generateBtn');
const generateBtnText = document.getElementById('generateBtnText');
const progressCard = document.getElementById('progressCard');
const statusText = document.getElementById('statusText');
const statusIcon = document.getElementById('statusIcon');
const progressPercent = document.getElementById('progressPercent');
const progressFill = document.getElementById('progressFill');
const resultCard = document.getElementById('resultCard');
const resultImg = document.getElementById('resultImg');
const downloadBtn = document.getElementById('downloadBtn');
const newBtn = document.getElementById('newBtn');
const errorMessage = document.getElementById('errorMessage');
const errorText = document.getElementById('errorText');
const serverStatus = document.getElementById('serverStatus');
const unloadBtn = document.getElementById('unloadBtn');
const spinner = document.querySelector('.spinner');
const sparkleIcon = document.querySelector('.sparkle-icon');

// Event Listeners
stepsSlider.addEventListener('input', updateStepsValue);
cfgSlider.addEventListener('input', updateCfgValue);
generateBtn.addEventListener('click', generateImage);
downloadBtn.addEventListener('click', downloadResult);
newBtn.addEventListener('click', resetForNewEdit);
unloadBtn.addEventListener('click', unloadModel);
addImageBtn.addEventListener('click', addImageSlot);

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    initializeImageSlots();
    startHealthCheck();
});

// Image slot management functions
function initializeImageSlots() {
    // Create first image slot (required)
    createImageSlot(0);
    updateAddImageButton();
}

function createImageSlot(index) {
    const slotDiv = document.createElement('div');
    slotDiv.className = 'image-slot';
    slotDiv.id = `imageSlot${index}`;

    slotDiv.innerHTML = `
        <div class="image-slot-header">
            <h3>Image ${index + 1}</h3>
            ${index === 0 ? '<span class="required-badge">Required</span>' : ''}
            ${index > 0 ? `
                <button class="remove-image-btn" onclick="removeImageSlot(${index})" title="Remove image">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="3 6 5 6 21 6"/>
                        <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
                    </svg>
                </button>
            ` : ''}
        </div>
        <input type="file" id="imageInput${index}" accept="image/*" hidden>
        <button class="upload-btn" onclick="document.getElementById('imageInput${index}').click()">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
                <circle cx="8.5" cy="8.5" r="1.5"></circle>
                <polyline points="21 15 16 10 5 21"></polyline>
            </svg>
            <span id="uploadBtnText${index}">Select Image ${index + 1}</span>
        </button>
        <div id="imagePreview${index}" class="image-preview hidden">
            <img id="previewImg${index}" alt="Selected image ${index + 1}">
        </div>
    `;

    imageSlots.appendChild(slotDiv);

    // Add event listener for this slot
    document.getElementById(`imageInput${index}`).addEventListener('change', (e) => handleImageSelect(e, index));
}

function handleImageSelect(e, index) {
    const file = e.target.files[0];
    if (file && file.type.startsWith('image/')) {
        selectedFiles[index] = file;
        const reader = new FileReader();
        reader.onload = (e) => {
            const previewImg = document.getElementById(`previewImg${index}`);
            const imagePreview = document.getElementById(`imagePreview${index}`);
            const uploadBtnText = document.getElementById(`uploadBtnText${index}`);

            previewImg.src = e.target.result;
            imagePreview.classList.remove('hidden');
            uploadBtnText.textContent = `Change Image ${index + 1}`;

            // Enable generate button if first image is selected
            if (index === 0) {
                generateBtn.disabled = false;
            }

            // Show add button if this is the first slot and we don't have more slots yet
            updateAddImageButton();
        };
        reader.readAsDataURL(file);
        hideError();
    }
}

function addImageSlot() {
    if (activeImageCount < 3) {
        createImageSlot(activeImageCount);
        activeImageCount++;
        updateAddImageButton();
        updateMultiImageTip();
    }
}

function removeImageSlot(index) {
    if (index === 0) return; // Can't remove first image

    // Remove the slot element
    const slot = document.getElementById(`imageSlot${index}`);
    if (slot) {
        slot.remove();
    }

    // Shift files down
    for (let i = index; i < activeImageCount - 1; i++) {
        selectedFiles[i] = selectedFiles[i + 1];
    }
    selectedFiles[activeImageCount - 1] = null;

    activeImageCount--;

    // Recreate all slots to fix numbering
    imageSlots.innerHTML = '';
    for (let i = 0; i < activeImageCount; i++) {
        createImageSlot(i);
        // Restore the file if it exists
        if (selectedFiles[i]) {
            const reader = new FileReader();
            reader.onload = (e) => {
                const previewImg = document.getElementById(`previewImg${i}`);
                const imagePreview = document.getElementById(`imagePreview${i}`);
                const uploadBtnText = document.getElementById(`uploadBtnText${i}`);

                previewImg.src = e.target.result;
                imagePreview.classList.remove('hidden');
                uploadBtnText.textContent = `Change Image ${i + 1}`;
            };
            reader.readAsDataURL(selectedFiles[i]);
        }
    }

    updateAddImageButton();
    updateMultiImageTip();
}

function updateAddImageButton() {
    if (activeImageCount < 3 && selectedFiles[0] !== null) {
        addImageBtn.classList.remove('hidden');
        addImageBtnText.textContent = `Add Image (${activeImageCount + 1}/3)`;
    } else {
        addImageBtn.classList.add('hidden');
    }
}

function updateMultiImageTip() {
    if (activeImageCount > 1) {
        multiImageTip.classList.remove('hidden');
    } else {
        multiImageTip.classList.add('hidden');
    }
}

function updateStepsValue() {
    stepsValue.textContent = stepsSlider.value;
}

function updateCfgValue() {
    cfgValue.textContent = parseFloat(cfgSlider.value).toFixed(1);
}

async function generateImage() {
    if (!selectedFiles[0]) {
        showError('Please select at least one image');
        return;
    }

    const prompt = promptInput.value.trim();
    if (!prompt) {
        showError('Please enter a prompt');
        return;
    }

    // Disable controls
    setGenerating(true);
    hideError();
    resultCard.classList.add('hidden');

    // Prepare form data with multiple images
    const formData = new FormData();
    const fileFields = ['file', 'file2', 'file3'];

    // Add all non-null images
    selectedFiles.forEach((file, index) => {
        if (file) {
            formData.append(fileFields[index], file);
        }
    });

    formData.append('prompt', prompt);
    formData.append('num_inference_steps', stepsSlider.value);
    formData.append('true_cfg_scale', cfgSlider.value);

    try {
        // Submit job
        updateStatus('Uploading...', '⬆️');
        const response = await fetch(`${API_BASE}/edit`, {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            throw new Error('Failed to submit job');
        }

        const data = await response.json();
        currentJobId = data.job_id;

        // Start polling
        updateStatus('Queued', '⏳');
        startPolling();

    } catch (error) {
        showError('Failed to generate image: ' + error.message);
        setGenerating(false);
    }
}

function startPolling() {
    if (pollInterval) clearInterval(pollInterval);
    
    pollInterval = setInterval(async () => {
        try {
            const response = await fetch(`${API_BASE}/jobs/${currentJobId}`);
            if (!response.ok) throw new Error('Failed to fetch job status');
            
            const job = await response.json();
            updateProgress(job.progress);
            
            switch (job.status) {
                case 'queued':
                    updateStatus('Queued', '⏳');
                    break;
                case 'running':
                    updateStatus('Running', '⚡');
                    break;
                case 'succeeded':
                    updateStatus('Completed', '✅');
                    clearInterval(pollInterval);
                    await displayResult(job.result_url);
                    setGenerating(false);
                    setTimeout(() => progressCard.classList.add('hidden'), 2000);
                    break;
                case 'failed':
                    updateStatus('Failed', '❌');
                    clearInterval(pollInterval);
                    showError(job.error || 'Job failed');
                    setGenerating(false);
                    break;
            }
        } catch (error) {
            clearInterval(pollInterval);
            showError('Failed to poll job status');
            setGenerating(false);
        }
    }, 2000);
}

function updateStatus(text, icon) {
    statusText.textContent = text;
    statusIcon.textContent = icon;
    progressCard.classList.remove('hidden');
}

function updateProgress(progress) {
    const percent = Math.round(progress);
    progressPercent.textContent = `${percent}%`;
    progressFill.style.width = `${percent}%`;
}

async function displayResult(resultUrl) {
    const imageUrl = `${API_BASE}${resultUrl}`;
    resultImg.src = imageUrl;
    resultCard.classList.remove('hidden');
    
    // Set up download
    downloadBtn.onclick = () => {
        const a = document.createElement('a');
        a.href = imageUrl;
        a.download = `generated-${Date.now()}.png`;
        a.click();
    };
}

function setGenerating(isGenerating) {
    generateBtn.disabled = isGenerating;
    promptInput.disabled = isGenerating;
    stepsSlider.disabled = isGenerating;
    cfgSlider.disabled = isGenerating;
    addImageBtn.disabled = isGenerating;

    // Disable all image inputs
    for (let i = 0; i < activeImageCount; i++) {
        const input = document.getElementById(`imageInput${i}`);
        if (input) input.disabled = isGenerating;
    }

    if (isGenerating) {
        generateBtnText.textContent = 'Processing...';
        spinner.classList.remove('hidden');
        sparkleIcon.classList.add('hidden');
    } else {
        generateBtnText.textContent = 'Generate';
        spinner.classList.add('hidden');
        sparkleIcon.classList.remove('hidden');
    }
}

function resetForNewEdit() {
    // Keep the same image but reset other states
    promptInput.value = '';
    progressCard.classList.add('hidden');
    resultCard.classList.add('hidden');
    hideError();
    updateProgress(0);
}

function showError(message) {
    errorText.textContent = message;
    errorMessage.classList.remove('hidden');
}

function hideError() {
    errorMessage.classList.add('hidden');
}

// Health check functions
async function checkHealth() {
    try {
        const response = await fetch(`${API_BASE}/health`);
        if (!response.ok) return;
        
        const health = await response.json();
        updateServerStatus(health);
    } catch (error) {
        console.error('Health check failed:', error);
    }
}

function updateServerStatus(health) {
    const statusDot = serverStatus.querySelector('.status-dot');
    const statusTextEl = serverStatus.querySelector('.status-text');
    const statusTime = serverStatus.querySelector('.status-time');
    
    serverStatus.classList.remove('hidden');
    
    if (health.model_loaded) {
        statusDot.className = 'status-dot status-ready';
        statusTextEl.textContent = 'Model Ready';
        if (health.minutes_until_unload !== null) {
            statusTime.textContent = `(${Math.round(health.minutes_until_unload)}m)`;
        }
        unloadBtn.classList.remove('hidden');
    } else {
        statusDot.className = 'status-dot status-unloaded';
        statusTextEl.textContent = 'Model Unloaded';
        statusTime.textContent = '';
        unloadBtn.classList.add('hidden');
    }
}

function startHealthCheck() {
    checkHealth(); // Initial check
    healthCheckInterval = setInterval(checkHealth, 30000); // Check every 30 seconds
}

async function unloadModel() {
    try {
        const response = await fetch(`${API_BASE}/model/unload`, {
            method: 'POST'
        });
        if (response.ok) {
            setTimeout(checkHealth, 1000); // Check health after unload
        }
    } catch (error) {
        showError('Failed to unload model');
    }
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (pollInterval) clearInterval(pollInterval);
    if (healthCheckInterval) clearInterval(healthCheckInterval);
});