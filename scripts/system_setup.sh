#!/bin/bash

# --- GPU Detection ---
echo "--- GPU Information ---"
nvidia-smi
if [ $? -ne 0 ]; then
    echo "ERROR: nvidia-smi failed - GPU may not be properly configured"
    exit 1
fi
echo "---------------------"

# --- CUDA Validation ---
echo "--- CUDA Version ---"
nvcc --version
if [ $? -ne 0 ]; then
    echo "ERROR: nvcc not found - CUDA may not be properly installed"
    exit 1
fi
echo "--------------------"

# --- Directory Setup ---
echo "Setting up workspace directories..."
mkdir -p /home/comfyuser/workspace/models/checkpoints
mkdir -p /home/comfyuser/workspace/models/loras
mkdir -p /home/comfyuser/workspace/models/vae
mkdir -p /home/comfyuser/workspace/output
mkdir -p /home/comfyuser/workspace/input

# --- Symlink to ComfyUI ---
echo "Linking workspace to ComfyUI..."
ln -sfn /home/comfyuser/workspace/models/checkpoints /home/comfyuser/ComfyUI/models/checkpoints
ln -sfn /home/comfyuser/workspace/models/loras /home/comfyuser/ComfyUI/models/loras
ln -sfn /home/comfyuser/workspace/models/vae /home/comfyuser/ComfyUI/models/vae
ln -sfn /home/comfyuser/workspace/output /home/comfyuser/ComfyUI/output
ln -sfn /home/comfyuser/workspace/input /home/comfyuser/ComfyUI/input

echo "System setup complete."
exit 0