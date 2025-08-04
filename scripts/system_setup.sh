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

# --- ComfyUI Path Setup ---
COMFYUI_PATH="/home/comfyuser/workspace/ComfyUI"
echo "Setting up ComfyUI at: $COMFYUI_PATH"

# Check if ComfyUI exists (should be installed during build)
if [ ! -d "$COMFYUI_PATH" ]; then
    echo "ERROR: ComfyUI not found at $COMFYUI_PATH"
    echo "ComfyUI should have been installed during the Docker build process"
    exit 1
fi

# --- Symlink to ComfyUI ---
echo "Linking workspace to ComfyUI..."
ln -sfn /home/comfyuser/workspace/models/checkpoints $COMFYUI_PATH/models/checkpoints
ln -sfn /home/comfyuser/workspace/models/loras $COMFYUI_PATH/models/loras
ln -sfn /home/comfyuser/workspace/models/vae $COMFYUI_PATH/models/vae
ln -sfn /home/comfyuser/workspace/output $COMFYUI_PATH/output
ln -sfn /home/comfyuser/workspace/input $COMFYUI_PATH/input

# --- Dependency Validation ---
echo "Running dependency validation..."
/home/comfyuser/scripts/validate_dependencies.sh
if [ $? -ne 0 ]; then
    echo "ERROR: Dependency validation failed"
    exit 1
fi

echo "System setup complete."
exit 0