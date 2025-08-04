#!/usr/bin/env bash
set -euo pipefail

# ==================================================================================
# NEXIS: RUNPOD TEMPLATE DEPLOYMENT SCRIPT
# ==================================================================================
# This script creates or updates the RunPod template for Nexis ComfyUI.
# Follows Phoenix's proven RunPod API patterns for reliable template deployment.

# ─── Configuration ──────────────────────────────────────────────────────────
readonly IMAGE_NAME="heapsgo0d/nexis:v1.0.0"
readonly TEMPLATE_NAME="Nexis ComfyUI (CUDA 12.8 + Model IDs)"
readonly CUSTOM_DNS_SERVERS="${CUSTOM_DNS_SERVERS:-"8.8.8.8,1.1.1.1"}"

# ─── Pre-flight Checks ──────────────────────────────────────────────────────
if [[ -z "${RUNPOD_API_KEY:-}" ]]; then
  echo "❌ Error: RUNPOD_API_KEY environment variable is not set." >&2
  echo "   Please set it with: export RUNPOD_API_KEY='your_api_key'" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo "❌ Error: This script requires 'jq' and 'curl'. Please install them." >&2
  exit 1
fi

echo "✅ Pre-flight checks passed."

# ─── Embedded README ─────────────────────────────────────────────────────────
README_CONTENT=$(cat <<'EOF'
# Nexis ComfyUI (CUDA 12.8 + Model IDs)

A lean, high-performance, and production-ready RunPod template for ComfyUI, optimized for modern NVIDIA GPUs. Built on NVIDIA CUDA 12.8.1 base image with manually installed PyTorch for optimal performance.

### 🌟 Key Features:
- **CUDA 12.8 Optimized**: Built on nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 with manual PyTorch installation
- **Model ID Support**: Uses CivitAI model IDs (not URLs) for reliable downloads via API
- **Debug Folder**: Failed downloads preserved in /workspace/debug/failed_downloads/
- **Simplified Architecture**: Modular, single-purpose scripts for maintainability

### 🖥️ Services & Ports:
- **ComfyUI**: Port `8188`
- **FileBrowser**: Port `8080`

### ⚙️ Environment Variables (See Template Options):
- **Downloads**: `CIVITAI_CHECKPOINTS_TO_DOWNLOAD`, `HF_REPOS_TO_DOWNLOAD`, etc.
- **Tokens**: `HUGGINGFACE_TOKEN`, `CIVITAI_TOKEN` (use RunPod Secrets)
- **Debug**: `DEBUG_MODE` for detailed logging

### 🧰 Technical Specifications:
- **Base Image**: `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04`
- **Default Temp Storage**: 150 GB
EOF
)

# ─── GraphQL Query ───────────────────────────────────────────────────────────
GRAPHQL_QUERY=$(cat <<'EOF'
mutation saveTemplate($input: SaveTemplateInput!) {
  saveTemplate(input: $input) {
    id
    name
    imageName
  }
}
EOF
)

# ─── Build Docker Arguments ─────────────────────────────────────────────────
# Build the docker arguments string dynamically
docker_args="--security-opt=no-new-privileges --cap-drop=ALL"
IFS=',' read -ra dns_servers <<< "$CUSTOM_DNS_SERVERS"
for server in "${dns_servers[@]}"; do
  docker_args+=" --dns=$server"
done

# ─── Build Payload ──────────────────────────────────────────────────────────
PAYLOAD=$(jq -n \
  --arg name "$TEMPLATE_NAME" \
  --arg imageName "$IMAGE_NAME" \
  --argjson cDisk 150 \
  --argjson vGb 0 \
  --arg vPath "/runpod-volume" \
  --arg dArgs "$docker_args" \
  --arg ports "8188/http,8080/http" \
  --arg readme "$README_CONTENT" \
  --arg query "$GRAPHQL_QUERY" \
  '{
    "query": $query,
    "variables": {
      "input": {
        "name": $name,
        "imageName": $imageName,
        "containerDiskInGb": $cDisk,
        "volumeInGb": $vGb,
        "volumeMountPath": $vPath,
        "dockerArgs": $dArgs,
        "ports": $ports,
        "readme": $readme,
        "env": [
          { "key": "DEBUG_MODE", "value": "false" },
          { "key": "COMFYUI_FLAGS", "value": "--bf16-unet" },
          { "key": "FB_USERNAME", "value": "admin" },
          { "key": "FB_PASSWORD", "value": "{{ RUNPOD_SECRET_FILEBROWSER_PASSWORD }}" },
          { "key": "HUGGINGFACE_TOKEN", "value": "{{ RUNPOD_SECRET_huggingface.co }}" },
          { "key": "CIVITAI_TOKEN", "value": "{{ RUNPOD_SECRET_civitai.com }}" },
          { "key": "HF_REPOS_TO_DOWNLOAD", "value": "black-forest-labs/FLUX.1-dev" },
          { "key": "CIVITAI_CHECKPOINTS_TO_DOWNLOAD", "value": "1569593,919063,450105" },
          { "key": "CIVITAI_LORAS_TO_DOWNLOAD", "value": "182404,445135,871108" },
          { "key": "CIVITAI_VAES_TO_DOWNLOAD", "value": "1674314" }
        ]
      }
    }
  }')

# ─── API Request ─────────────────────────────────────────────────────────────
echo "🚀 Deploying Nexis template to RunPod..."

response=$(curl -s -w "\n%{http_code}" \
  -X POST "https://api.runpod.io/graphql" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
  -H "User-Agent: Nexis-Deploy/1.0" \
  -d "$PAYLOAD")

# ─── Response Handling ──────────────────────────────────────────────────────
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -ne 200 ]; then
  echo "❌ HTTP $http_code returned from RunPod API." >&2
  echo "$body" | jq . >&2
  exit 1
fi

template_id=$(echo "$body" | jq -r '.data.saveTemplate.id')
if [ -z "$template_id" ] || [ "$template_id" = "null" ]; then
  echo "❌ Error: Template creation failed. Response from API:" >&2
  echo "$body" | jq . >&2
  exit 1
fi

# ─── Success ─────────────────────────────────────────────────────────────────
template_name=$(echo "$body" | jq -r '.data.saveTemplate.name')
image_name=$(echo "$body" | jq -r '.data.saveTemplate.imageName')

echo "✅ Template deployed successfully!"
echo "   Template ID: $template_id"
echo "   Template Name: $template_name"
echo "   Image: $image_name"
echo ""
echo "🎯 Next steps:"
echo "   1. Visit https://runpod.io/console/deploy"
echo "   2. Select your '$template_name' template"
echo "   3. Configure your desired GPU and deploy!"