#!/bin/bash

# Nexis RunPod Template Creation Script
# Enhanced with RunPod API integration

# --- Configuration ---
TEMPLATE_NAME="Nexis ComfyUI"
DOCKER_IMAGE="heapsgo0d/nexis:v1.0.0"
GPU_TYPES="NVIDIA RTX 5090"
CPU_CORES=4
MEMORY_GB=16
STORAGE_GB=50

# Environment Variables (configurable in RunPod UI)
ENV_VARS=(
    "CIVITAI_CHECKPOINTS_TO_DOWNLOAD="
    "CIVITAI_LORAS_TO_DOWNLOAD="
    "CIVITAI_VAES_TO_DOWNLOAD="
    "HF_REPOS_TO_DOWNLOAD="
    "HUGGINGFACE_TOKEN="
    "COMFYUI_FLAGS=--bf16-unet"
    "FB_USERNAME="
    "FB_PASSWORD="
)

# Port Mappings
PORTS="8188:8188,8080:8080"

# --- RunPod API Configuration ---
RUNPOD_API_KEY=${RUNPOD_API_KEY:-""}
RUNPOD_API_URL="https://api.runpod.io/graphql"
USE_API=false

# --- Functions ---
create_template_via_api() {
    local query='mutation {
        saveTemplate(
            input: {
                name: "'"$TEMPLATE_NAME"'"
                imageName: "'"$DOCKER_IMAGE"'"
                dockerArgs: ""
                containerDiskInGb: '"$STORAGE_GB"'
                volumeInGb: 0
                ports: "'"$PORTS"'"
                volumeMountPath: ""
                env: ['"$(printf "\"%s\"," "${ENV_VARS[@]}" | sed 's/,$//')"']
                isServerless: false
                gpuEnabled: true
                supportPublicIp: true
                templateGpuIds: ["'"$GPU_TYPES"'"]
                containerRegistryId: null
                dockerAuthentication: null
                minMemoryInGb: '"$MEMORY_GB"'
                minVcpuCount: '"$CPU_CORES"'
            }
        ) {
            id
            name
            imageName
        }
    }'

    local response=$(curl -s -X POST "$RUNPOD_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $RUNPOD_API_KEY" \
        -d "{\"query\": \"$query\"}")

    if [[ $(echo "$response" | jq -r '.data.saveTemplate.id') != "null" ]]; then
        echo "Template created successfully:"
        echo "$response" | jq -r '.data.saveTemplate'
        return 0
    else
        echo "Error creating template:"
        echo "$response" | jq -r '.errors[].message'
        return 1
    fi
}

create_template_via_cli() {
    echo -e "\nCreating template using RunPod CLI..."
    runpod template create "$TEMPLATE_NAME" \
        --image-name "$DOCKER_IMAGE" \
        --gpu-types "$GPU_TYPES" \
        --cpu-cores "$CPU_CORES" \
        --memory-gb "$MEMORY_GB" \
        --storage-gb "$STORAGE_GB" \
        --ports "$PORTS" \
        --env "$(IFS=,; echo "${ENV_VARS[*]}")"
}

# --- Main Execution ---
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

# Check for API key
if [[ -n "$RUNPOD_API_KEY" ]]; then
    echo -e "\nDetected RUNPOD_API_KEY - attempting API creation..."
    if command -v jq &> /dev/null && command -v curl &> /dev/null; then
        if create_template_via_api; then
            exit 0
        else
            echo "Falling back to CLI method..."
        fi
    else
        echo "Required tools (jq, curl) not found. Falling back to CLI method..."
    fi
fi

# Manual instructions if CLI not available
if ! command -v runpod &> /dev/null; then
    echo -e "\nRunPod CLI not found. You can:"
    echo "1. Install the RunPod CLI: npm install -g @runpod/cli"
    echo "2. Run this command manually:"
    echo "runpod template create \"$TEMPLATE_NAME\" --image-name \"$DOCKER_IMAGE\" --gpu-types \"$GPU_TYPES\" --cpu-cores $CPU_CORES --memory-gb $MEMORY_GB --storage-gb $STORAGE_GB --ports \"$PORTS\" --env \"$(IFS=,; echo "${ENV_VARS[*]}")\""
    echo "3. Or create the template manually via the RunPod web interface using the above specifications."
    exit 1
fi

create_template_via_cli