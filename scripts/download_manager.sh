#!/bin/bash

# --- HuggingFace Downloader ---
if [ -n "$HF_MODEL_DOWNLOAD" ]; then
    echo "--- Downloading HuggingFace Models ---"
    IFS=',' read -ra HF_REPOS <<< "$HF_MODEL_DOWNLOAD"
    for repo in "${HF_REPOS[@]}"; do
        echo "Downloading $repo..."
        GIT_LFS_SKIP_SMUDGE=1 git clone https://huggingface.co/$repo /home/comfyuser/workspace/models/$(basename $repo)
        (cd /home/comfyuser/workspace/models/$(basename $repo) && git lfs pull)
    done
fi

# --- Civitai Downloader ---
if [ -n "$CIVITAI_MODEL_DOWNLOAD" ]; then
    echo "--- Downloading Civitai Models ---"
    IFS=',' read -ra CIVITAI_URLS <<< "$CIVITAI_MODEL_DOWNLOAD"
    for url in "${CIVITAI_URLS[@]}"; do
        echo "Downloading from $url..."
        aria2c --console-log-level=error -c -x 16 -s 16 -k 1M -d /home/comfyuser/workspace/models/checkpoints -o $(basename $url) "$url"
    done
fi

echo "Download manager finished."
exit 0