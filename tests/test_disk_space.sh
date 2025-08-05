#!/bin/bash

# Test for disk space handling

echo "Starting disk space handling test..."

# Create a large file to fill up the disk
DUMMY_FILE="/workspace/dummy_file"
# Create a 10GB file
dd if=/dev/zero of=$DUMMY_FILE bs=1G count=10

# Attempt to download a file
export CIVITAI_CHECKPOINTS_TO_DOWNLOAD="133745"
export DEBUG_MODE=true
python3 /home/comfyuser/scripts/nexis_downloader.py
EXIT_CODE=$?

# Clean up the dummy file
rm $DUMMY_FILE

# Check if the downloader exited with an error
if [ $EXIT_CODE -ne 0 ]; then
    echo "Disk space handling test PASSED!"
    exit 0
else
    echo "Disk space handling test FAILED!"
    exit 1
fi