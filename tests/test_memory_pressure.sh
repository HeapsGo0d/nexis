#!/bin/bash

# Test for memory pressure

echo "Starting memory pressure test..."

# Allocate a large amount of memory (e.g., 4GB)
python3 -c "import numpy as np; a = np.zeros((1024, 1024, 1024, 4), dtype=np.uint8); input('Press Enter to release memory')" &
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
    echo "Memory pressure test PASSED!"
    kill $APP_PID
    kill $ALLOC_PID
    exit 0
else
    echo "Memory pressure test FAILED!"
    kill $ALLOC_PID
    exit 1
fi