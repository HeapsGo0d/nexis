#!/bin/bash

set -e

TEST_CONTAINER="nexis-service-test-$(date +%s)"
COMFYUI_PORT=$(comm -23 <(seq 8000 9000) <(ss -tan | awk 'NR>1 {print $4}' | cut -d':' -f2) | shuf | head -n 1)

# Start the container
echo "Starting test container..."
docker run -d --name $TEST_CONTAINER --rm -p ${COMFYUI_PORT}:8188 nexis:test

cleanup() {
    echo "Cleaning up..."
    docker rm -f $TEST_CONTAINER || true
}
trap cleanup EXIT

# Test that services use venv Python
echo "Testing service Python environment..."
docker exec $TEST_CONTAINER bash -c "
echo 'Checking Python path in running services...'
ps aux | grep -E 'python.*main.py' | grep -v grep
echo 'Verifying venv usage...'
pgrep -f 'python.*main.py' | head -1 | xargs -I {} cat /proc/{}/environ | tr '\\0' '\\n' | grep -E '^(PATH|VIRTUAL_ENV)='
"

# Test CUDA check skipping
echo "Testing CUDA check behavior..."
docker exec $TEST_CONTAINER bash -c "
if nvidia-smi >/dev/null 2>&1; then
    echo 'NVIDIA driver available - CUDA checks should run'
else
    echo 'No NVIDIA driver - CUDA checks should be skipped'
    if [ \"\$SKIP_CUDA_CHECK\" = \"1\" ]; then
        echo '✅ SKIP_CUDA_CHECK properly set'
    else
        echo '❌ SKIP_CUDA_CHECK not set when expected'
    fi
fi
"

# Test Docker health check
echo "Testing Docker health check..."
for i in {1..${SERVICE_HEALTH_TIMEOUT:-10}}; do
    health_status=$(docker inspect $TEST_CONTAINER --format='{{.State.Health.Status}}')
    echo "Health status: $health_status (attempt $i/${SERVICE_HEALTH_TIMEOUT:-10})"
    
    if [ "$health_status" = "healthy" ]; then
        echo "✅ Container health check passed"
        break
    elif [ "$health_status" = "unhealthy" ]; then
        echo "❌ Container health check failed"
        docker inspect $TEST_CONTAINER --format='{{range .State.Health.Log}}{{.Output}}{{end}}'
        exit 1
    fi
    
    if [ $i -eq ${SERVICE_HEALTH_TIMEOUT:-10} ]; then
        echo "❌ Health check did not become healthy within timeout"
        exit 1
    fi
    sleep 5
done

# Test service recovery
echo "Testing service recovery..."

# Kill ComfyUI process and see if it restarts
docker exec $TEST_CONTAINER bash -c "
echo 'Killing ComfyUI process to test recovery...'
pkill -f 'python.*main.py' || echo 'ComfyUI process not found'
"

# Wait for restart
sleep 10

# Check if ComfyUI is back up
if curl -s --fail http://localhost:${COMFYUI_PORT}/ >/dev/null; then
    echo "✅ ComfyUI recovered successfully"
else
    echo "❌ ComfyUI did not recover"
    docker logs $TEST_CONTAINER | tail -20
    exit 1
fi

# Test enhanced logging format
echo "Testing enhanced logging format..."
docker logs $TEST_CONTAINER 2>&1 | grep -E '\[20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\]' > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Structured logging format detected"
else
    echo "❌ Enhanced logging format not found"
    echo "Sample logs:"
    docker logs $TEST_CONTAINER 2>&1 | head -10
fi

# Test graceful shutdown with enhanced signal handling
echo "Testing enhanced signal handling..."

# Start container and get service manager PID
docker exec $TEST_CONTAINER bash -c "
echo 'Getting service manager PID...'
pgrep -f service_manager.sh || echo 'Service manager not found'
ps aux | grep -E '(service_manager|comfyui|filebrowser)' | grep -v grep
"

# Test SIGTERM forwarding
echo "Testing SIGTERM forwarding..."
docker kill --signal=TERM $TEST_CONTAINER

# Wait for graceful shutdown
for i in {1..${SERVICE_SHUTDOWN_TIMEOUT:-10}}; do
    if ! docker ps | grep -q $TEST_CONTAINER; then
        echo "✅ Container stopped gracefully via SIGTERM"
        break
    fi
    if [ $i -eq ${SERVICE_SHUTDOWN_TIMEOUT:-10} ]; then
        echo "❌ Container did not stop gracefully"
        docker logs $TEST_CONTAINER | tail -20
        exit 1
    fi
    sleep 2
done