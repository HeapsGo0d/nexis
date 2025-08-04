#!/bin/bash

# Nexis RunPod Template Creation Script

# --- Template Configuration ---
TEMPLATE_NAME="Nexis ComfyUI"
DOCKER_IMAGE="your_dockerhub_username/nexis:latest" # Replace with your actual image
GPU_TYPES="NVIDIA RTX 5090, NVIDIA RTX 4090"
CPU_CORES=4
MEMORY_GB=16
STORAGE_GB=50

# --- Environment Variables ---
# These will be configurable in the RunPod template UI
ENV_VARS=(
    "CIVITAI_MODEL_DOWNLOAD="
    "HF_MODEL_DOWNLOAD="
    "HF_TOKEN="
    "COMFYUI_FLAGS=--bf16-unet"
)

# --- Port Mappings ---
PORTS="8188:8188,8080:8080"

# --- RunPod CLI Command (for reference) ---
echo "--- RunPod Template Definition ---"
echo "Template Name: $TEMPLATE_NAME"
echo "Docker Image: $DOCKER_IMAGE"
echo "GPU Types: $GPU_TYPES"
echo "CPU Cores: $CPU_CORES"
echo "Memory (GB): $MEMORY_GB"
echo "Storage (GB): $STORAGE_GB"
echo "Ports: $PORTS"
echo "Environment Variables:"
for var in "${ENV_VARS[@]}"; do
    echo "  - $var"
done

echo -e "\nTo create this template using the RunPod CLI, you would use a command similar to:"
echo "runpod template create \"$TEMPLATE_NAME\" --image-name \"$DOCKER_IMAGE\" --gpu-types \"$GPU_TYPES\" --cpu-cores $CPU_CORES --memory-gb $MEMORY_GB --storage-gb $STORAGE_GB --ports \"$PORTS\" --env \"$(IFS=,; echo "${ENV_VARS[*]}")\""