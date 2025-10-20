// API endpoints
const API_BASE = window.location.origin;

// State
let selectedFile = null;
let currentJobId = null;
let pollInterval = null;
let healthCheckInterval = null;

// Elements
const imageInput = document.getElementById('imageInput');
const uploadBtn = document.getElementById('uploadBtn');
const uploadBtnText = document.getElementById('uploadBtnText');
const imagePreview = document.getElementById('imagePreview');
const previewImg = document.getElementById('previewImg');
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
uploadBtn.addEventListener('click', () => imageInput.click());
imageInput.addEventListener('change', handleImageSelect);
stepsSlider.addEventListener('input', updateStepsValue);
cfgSlider.addEventListener('input', updateCfgValue);
generateBtn.addEventListener('click', generateImage);
downloadBtn.addEventListener('click', downloadResult);
newBtn.addEventListener('click', resetForNewEdit);
unloadBtn.addEventListener('click', unloadModel);

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    startHealthCheck();
});

// Functions
function handleImageSelect(e) {
    const file = e.target.files[0];
    if (file && file.type.startsWith('image/')) {
        selectedFile = file;
        const reader = new FileReader();
        reader.onload = (e) => {
            previewImg.src = e.target.result;
            imagePreview.classList.remove('hidden');
            uploadBtnText.textContent = 'Change Image';
            generateBtn.disabled = false;
        };
        reader.readAsDataURL(file);
        hideError();
    }
}

function updateStepsValue() {
    stepsValue.textContent = stepsSlider.value;
}

function updateCfgValue() {
    cfgValue.textContent = parseFloat(cfgSlider.value).toFixed(1);
}

async function generateImage() {
    if (!selectedFile) {
        showError('Please select an image first');
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

    // Prepare form data
    const formData = new FormData();
    formData.append('file', selectedFile);
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
    imageInput.disabled = isGenerating;
    uploadBtn.disabled = isGenerating;
    promptInput.disabled = isGenerating;
    stepsSlider.disabled = isGenerating;
    cfgSlider.disabled = isGenerating;
    
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