#!/bin/bash

# Test for network interruption recovery

echo "Starting network interruption recovery test..."

# Start the download in the background
export CIVITAI_CHECKPOINTS_TO_DOWNLOAD="133745"
export DEBUG_MODE=true
python3 /home/comfyuser/scripts/nexis_downloader.py &
DOWNLOAD_PID=$!

# Wait for a few seconds to let the download start
sleep 10

# Simulate a network interruption
echo "Simulating network interruption..."
iptables -A OUTPUT -d civitai.com -j DROP

# Wait for a few seconds
sleep 20

# Restore network access
echo "Restoring network access..."
iptables -D OUTPUT -d civitai.com -j DROP

# Wait for the download to complete
wait $DOWNLOAD_PID
EXIT_CODE=$?

# Check if the download was successful
if [ $EXIT_CODE -eq 0 ]; then
    echo "Network interruption recovery test PASSED!"
    exit 0
else
    echo "Network interruption recovery test FAILED!"
    exit 1
fi