#!/bin/bash

# --- URL Validation and Sanitization Functions ---
validate_civitai_url() {
    [[ "$1" =~ ^https://civitai\.com/ ]] || { echo "Invalid Civitai URL: $1"; return 1; }
}

sanitize_filename() {
    local filename=$(basename "$1")
    # Remove any path components and special characters
    filename="${filename//[^a-zA-Z0-9._-]/_}"
    # Ensure filename isn't empty
    [[ -n "$filename" ]] || { echo "Invalid filename"; return 1; }
    echo "$filename"
}

# --- Setup Git Credentials for HuggingFace ---
setup_huggingface_credentials() {
    if [ -n "$HUGGINGFACE_TOKEN" ]; then
        echo "Setting up HuggingFace credentials using git credential helper..."
        
        # Configure git to use credential helper
        git config --global credential.helper store
        
        # Set up credentials for huggingface.co
        echo "protocol=https
host=huggingface.co
username=hf_user
password=$HUGGINGFACE_TOKEN" | git credential approve
        
        # Also configure git to use the token for HuggingFace operations
        git config --global url."https://huggingface.co/".insteadOf "https://USER:$HUGGINGFACE_TOKEN@huggingface.co/"
        
        echo "HuggingFace credentials configured securely"
    fi
}

# --- Clean up Git Credentials ---
cleanup_huggingface_credentials() {
    if [ -n "$HUGGINGFACE_TOKEN" ]; then
        echo "Cleaning up HuggingFace credentials..."
        
        # Remove credentials from git credential store
        echo "protocol=https
host=huggingface.co
username=hf_user" | git credential reject
        
        echo "HuggingFace credentials cleaned up"
    fi
}

# --- HuggingFace Downloader ---
if [ -n "$HF_REPOS_TO_DOWNLOAD" ]; then
    echo "--- Downloading HuggingFace Models ---"
    
    # Setup credentials before downloading
    setup_huggingface_credentials
    
    IFS=',' read -ra HF_REPOS <<< "$HF_REPOS_TO_DOWNLOAD"
    for repo in "${HF_REPOS[@]}"; do
        echo "Downloading $repo..."
        # Use secure URL without embedded credentials
        HF_URL="https://huggingface.co/$repo"
        
        # Retry logic with exponential backoff
        MAX_RETRIES=3
        RETRY_DELAY=5
        attempt=0
        while [ $attempt -lt $MAX_RETRIES ]; do
            if GIT_LFS_SKIP_SMUDGE=1 git clone $HF_URL /home/comfyuser/workspace/models/$(basename $repo) && \
               (cd /home/comfyuser/workspace/models/$(basename $repo) && git lfs pull); then
                # Verify download was successful
                if [ -d "/home/comfyuser/workspace/models/$(basename $repo)" ]; then
                    echo "Successfully downloaded $repo"
                    break
                fi
            fi
            
            attempt=$((attempt + 1))
            echo "Attempt $attempt failed, retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))
            
            # Cleanup partial download on failure
            rm -rf "/home/comfyuser/workspace/models/$(basename $repo)"
        done
        
        if [ $attempt -eq $MAX_RETRIES ]; then
            echo "Failed to download $repo after $MAX_RETRIES attempts"
            # Clean up credentials before exiting
            cleanup_huggingface_credentials
            exit 1
        fi
    done
    
    # Clean up credentials after all downloads are complete
    cleanup_huggingface_credentials
fi

# --- Civitai Downloader ---
if [ -n "$CIVITAI_CHECKPOINTS_TO_DOWNLOAD" ]; then
    echo "--- Downloading Civitai Checkpoints ---"
    IFS=',' read -ra CIVITAI_URLS <<< "$CIVITAI_CHECKPOINTS_TO_DOWNLOAD"
    for url in "${CIVITAI_URLS[@]}"; do
        echo "Downloading from $url..."
        if ! validate_civitai_url "$url"; then
            echo "Skipping invalid Civitai URL"
            continue
        fi
        filename=$(sanitize_filename "$url") || { echo "Invalid filename for URL: $url"; continue; }
        output_path="/home/comfyuser/workspace/models/checkpoints/$filename"
        
        # Retry logic with exponential backoff
        MAX_RETRIES=3
        RETRY_DELAY=5
        attempt=0
        while [ $attempt -lt $MAX_RETRIES ]; do
            if aria2c --console-log-level=error -c -x 16 -s 16 -k 1M -d /home/comfyuser/workspace/models/checkpoints -o "$filename" "$url"; then
                # Basic file verification
                if [ -f "$output_path" ] && [ -s "$output_path" ]; then
                    echo "Successfully downloaded $filename"
                    break
                fi
            fi
            
            attempt=$((attempt + 1))
            echo "Attempt $attempt failed, retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))
            
            # Cleanup partial download on failure
            rm -f "$output_path"
        done
        
        if [ $attempt -eq $MAX_RETRIES ]; then
            echo "Failed to download $filename after $MAX_RETRIES attempts"
            exit 1
        fi
    done
fi

# --- Civitai LoRAs Downloader ---
if [ -n "$CIVITAI_LORAS_TO_DOWNLOAD" ]; then
    echo "--- Downloading Civitai LoRAs ---"
    IFS=',' read -ra CIVITAI_URLS <<< "$CIVITAI_LORAS_TO_DOWNLOAD"
    for url in "${CIVITAI_URLS[@]}"; do
        echo "Downloading from $url..."
        if ! validate_civitai_url "$url"; then
            echo "Skipping invalid Civitai URL"
            continue
        fi
        filename=$(sanitize_filename "$url") || { echo "Invalid filename for URL: $url"; continue; }
        output_path="/home/comfyuser/workspace/models/loras/$filename"
        
        # Retry logic with exponential backoff
        MAX_RETRIES=3
        RETRY_DELAY=5
        attempt=0
        while [ $attempt -lt $MAX_RETRIES ]; do
            if aria2c --console-log-level=error -c -x 16 -s 16 -k 1M -d /home/comfyuser/workspace/models/loras -o "$filename" "$url"; then
                # Basic file verification
                if [ -f "$output_path" ] && [ -s "$output_path" ]; then
                    echo "Successfully downloaded $filename"
                    break
                fi
            fi
            
            attempt=$((attempt + 1))
            echo "Attempt $attempt failed, retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))
            
            # Cleanup partial download on failure
            rm -f "$output_path"
        done
        
        if [ $attempt -eq $MAX_RETRIES ]; then
            echo "Failed to download $filename after $MAX_RETRIES attempts"
            exit 1
        fi
    done
fi

# --- Civitai VAEs Downloader ---
if [ -n "$CIVITAI_VAES_TO_DOWNLOAD" ]; then
    echo "--- Downloading Civitai VAEs ---"
    IFS=',' read -ra CIVITAI_URLS <<< "$CIVITAI_VAES_TO_DOWNLOAD"
    for url in "${CIVITAI_URLS[@]}"; do
        echo "Downloading from $url..."
        if ! validate_civitai_url "$url"; then
            echo "Skipping invalid Civitai URL"
            continue
        fi
        filename=$(sanitize_filename "$url") || { echo "Invalid filename for URL: $url"; continue; }
        output_path="/home/comfyuser/workspace/models/vae/$filename"
        
        # Retry logic with exponential backoff
        MAX_RETRIES=3
        RETRY_DELAY=5
        attempt=0
        while [ $attempt -lt $MAX_RETRIES ]; do
            if aria2c --console-log-level=error -c -x 16 -s 16 -k 1M -d /home/comfyuser/workspace/models/vae -o "$filename" "$url"; then
                # Basic file verification
                if [ -f "$output_path" ] && [ -s "$output_path" ]; then
                    echo "Successfully downloaded $filename"
                    break
                fi
            fi
            
            attempt=$((attempt + 1))
            echo "Attempt $attempt failed, retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))
            
            # Cleanup partial download on failure
            rm -f "$output_path"
        done
        
        if [ $attempt -eq $MAX_RETRIES ]; then
            echo "Failed to download $filename after $MAX_RETRIES attempts"
            exit 1
        fi
    done
fi

echo "Download manager finished successfully."
exit 0