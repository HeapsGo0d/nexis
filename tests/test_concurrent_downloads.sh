#!/bin/bash

# Test for concurrent downloads

echo "Starting concurrent download test..."

# Set up a temporary directory for downloads
DOWNLOAD_DIR="/workspace/downloads_tmp_concurrent_test"
mkdir -p $DOWNLOAD_DIR

# List of model IDs to download concurrently
MODEL_IDS=(
    "133745"
    "128344"
    "129857"
)

# Run the downloader for each model in the background
for model_id in "${MODEL_IDS[@]}"; do
    echo "Starting download for model ID: $model_id"
    (
        export CIVITAI_CHECKPOINTS_TO_DOWNLOAD=$model_id
        export DEBUG_MODE=true
        python3 /home/comfyuser/scripts/nexis_downloader.py
    ) &
done

# Wait for all background jobs to finish
wait

# Check if all files were downloaded
all_files_downloaded=true
for model_id in "${MODEL_IDS[@]}"; do
    # This is a simplified check. A more robust check would get the filename from the API.
    # For now, we assume the presence of any file for the given model is a success.
    if ! ls $DOWNLOAD_DIR/checkpoints/*${model_id}* 1> /dev/null 2>&1; then
        echo "File for model ID $model_id not found!"
        all_files_downloaded=false
    fi
done

# Clean up
rm -rf $DOWNLOAD_DIR

if [ "$all_files_downloaded" = true ]; then
    echo "Concurrent download test PASSED!"
    exit 0
else
    echo "Concurrent download test FAILED!"
    exit 1
fi