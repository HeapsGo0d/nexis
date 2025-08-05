#!/bin/bash

set -e

TEST_IMAGE="nexis-e2e-test"
TEST_CONTAINER="nexis-e2e-container"
COMFYUI_PORT=8188
FILEBROWSER_PORT=8080

cleanup() {
    echo "Cleaning up..."
    docker rm -f $TEST_CONTAINER || true
    docker rmi -f $TEST_IMAGE || true
    docker rmi -f nexis:build-stage || true
}
trap cleanup EXIT

# Step 1: Test production build process
echo "Step 1: Testing production build process..."
start_time=$(date +%s)

# Test build stage (CPU compatible)
echo "Building build stage (CPU compatible)..."
docker build --target build -t nexis:build-stage .
build_stage_end=$(date +%s)
build_stage_duration=$((build_stage_end - start_time))
echo "✅ Build stage completed in ${build_stage_duration}s (CPU compatible)"

# Test production stage
echo "Building production stage..."
docker build --target production -t $TEST_IMAGE .
build_end_time=$(date +%s)
total_build_duration=$((build_end_time - start_time))
echo "✅ Production build completed in ${total_build_duration}s"

# Step 2: Start with production-hardened configuration
echo "Step 2: Starting with production configuration..."
container_start_time=$(date +%s)
docker run -d --name $TEST_CONTAINER \
    --gpus all \
    -p ${COMFYUI_PORT}:8188 \
    -p ${FILEBROWSER_PORT}:8080 \
    -e DEBUG_MODE=true \
    -e COMFYUI_FLAGS="--bf16-unet" \
    -e FB_USERNAME="admin" \
    -e FB_PASSWORD="testpass123" \
    -e VIRTUAL_ENV="/opt/venv" \
    -e PYTHON="/opt/venv/bin/python" \
    -e HF_REPOS_TO_DOWNLOAD="microsoft/DialoGPT-small" \
    -e CIVITAI_CHECKPOINTS_TO_DOWNLOAD="1569593" \
    -e CIVITAI_LORAS_TO_DOWNLOAD="182404" \
    $TEST_IMAGE

# Step 3: Monitor enhanced startup with structured logging
echo "Step 3: Monitoring startup with enhanced logging..."

# Wait for structured log entries
echo "Waiting for structured logging to start..."
for i in {1..12}; do
    if docker logs $TEST_CONTAINER 2>&1 | grep -E '\[20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\]' >/dev/null; then
        echo "✅ Structured logging detected"
        break
    fi
    if [ $i -eq 12 ]; then
        echo "❌ Structured logging not detected"
        docker logs $TEST_CONTAINER | head -10
        exit 1
    fi
    sleep 5
done

# Monitor dependency validation
echo "Monitoring dependency validation..."
for i in {1..24}; do
    if docker logs $TEST_CONTAINER 2>&1 | grep -q "Validation Complete"; then
        echo "✅ Dependency validation completed"
        break
    fi
    if [ $i -eq 24 ]; then
        echo "❌ Dependency validation did not complete"
        docker logs $TEST_CONTAINER
        exit 1
    fi
    sleep 5
done
total_startup_time=$(( $(date +%s) - container_start_time ))

# Step 4: Validate virtual environment in production
echo "Step 4: Validating production virtual environment..."
docker exec $TEST_CONTAINER bash -c "
echo 'Testing venv isolation...'
echo \"VIRTUAL_ENV: \$VIRTUAL_ENV\"
echo \"PATH: \$PATH\"
echo \"Python executable: \$(which python)\"
echo \"Python version: \$(python -V)\"

echo 'Testing PyTorch in venv...'
python -c '
import torch
print(f\"PyTorch: {torch.__version__}\")
print(f\"CUDA compiled version: {torch.version.cuda}\")
# Only test CUDA availability if driver present
import os
if os.getenv(\"SKIP_CUDA_CHECK\") != \"1\":
    print(f\"CUDA available: {torch.cuda.is_available()}\")
else:
    print(\"CUDA check skipped (no driver)\")
'

echo 'Testing standard library access...'
python -c 'import encodings, json, urllib.request; print(\"✅ Standard library accessible\")'  
"

# Step 5: Validate services are running
echo "Step 5: Validating services..."
# ComfyUI
if curl -s --fail http://localhost:${COMFYUI_PORT}/ >/dev/null; then
    echo "✅ ComfyUI is running"
else
    echo "❌ ComfyUI is not running"
    exit 1
fi
# Filebrowser
if curl -s --fail http://localhost:${FILEBROWSER_PORT}/ >/dev/null; then
    echo "✅ Filebrowser is running"
else
    echo "❌ Filebrowser is not running"
    exit 1
fi

# Step 6: Validate production service patterns
echo "Step 6: Validating production service patterns..."

# Test service manager PID tracking
docker exec $TEST_CONTAINER bash -c "
echo 'Checking service manager PID tracking...'
ps aux | grep -E 'service_manager.sh' | grep -v grep
echo 'Checking service processes...'
ps aux | grep -E '(python.*main.py|filebrowser)' | grep -v grep
"

# Test health check endpoint
echo "Testing health check endpoint..."
health_response=$(curl -s http://localhost:${COMFYUI_PORT}/ || echo "HEALTH_ERROR")
if echo "$health_response" | grep -q "ComfyUI"; then
    echo "✅ Health check endpoint responding"
else
    echo "❌ Health check endpoint not responding correctly"
fi

# Step 7: Validate downloaded content
echo "Step 7: Validating downloaded content..."
docker exec $TEST_CONTAINER ls /workspace/storage/models/huggingface/microsoft/DialoGPT-small
docker exec $TEST_CONTAINER ls /workspace/storage/models/checkpoints
docker exec $TEST_CONTAINER ls /workspace/storage/models/loras

# Step 8: Test production shutdown patterns
echo "Step 8: Testing production shutdown..."

# Test graceful shutdown with signal forwarding
echo "Testing graceful shutdown with signal forwarding..."
shutdown_start=$(date +%s)
docker kill --signal=TERM $TEST_CONTAINER

# Monitor shutdown logs
for i in {1..${E2E_SHUTDOWN_TIMEOUT:-15}}; do
    if ! docker ps | grep -q $TEST_CONTAINER; then
        shutdown_end=$(date +%s)
        shutdown_duration=$((shutdown_end - shutdown_start))
        echo "✅ Graceful shutdown completed in ${shutdown_duration}s"
        break
    fi
    if [ $i -eq ${E2E_SHUTDOWN_TIMEOUT:-15} ]; then
        echo "❌ Graceful shutdown timeout"
        docker logs $TEST_CONTAINER | tail -20
        exit 1
    fi
    sleep 2
done

# Check shutdown logs for proper signal handling
if docker logs $TEST_CONTAINER 2>&1 | grep -q "Signal.*received"; then
    echo "✅ Signal handling logged correctly"
else
    echo "❌ Signal handling not logged"
fi

echo "📊 Production Performance Summary:"
echo "   - Build stage time: ${build_stage_duration}s (CPU compatible)"
echo "   - Total build time: ${total_build_duration}s"
echo "   - Startup time: ${total_startup_time}s"
echo "   - Shutdown time: ${shutdown_duration}s"
echo "   - Virtual environment: Self-contained (/opt/venv)"
echo "   - CUDA compatibility: Runtime detection"