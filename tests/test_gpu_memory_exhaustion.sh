#!/bin/bash

# Test for GPU memory exhaustion

echo "Starting GPU memory exhaustion test..."

# Allocate all available GPU memory
python3 -c "import torch; torch.ones((2**30,), device='cuda')" &
ALLOC_PID=$!

# Wait for a moment to ensure memory is allocated
sleep 5

# Run the application
/home/comfyuser/scripts/service_manager.sh &
APP_PID=$!

# Wait for the application to start
sleep 30

# Check if the application is still running
if kill -0 $APP_PID; then
    echo "GPU memory exhaustion test PASSED!"
    kill $APP_PID
    kill $ALLOC_PID
    exit 0
else
    echo "GPU memory exhaustion test FAILED!"
    kill $ALLOC_PID
    exit 1
fi