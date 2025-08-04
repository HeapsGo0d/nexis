#!/bin/bash

# --- Start ComfyUI ---
echo "Starting ComfyUI..."
python /home/comfyuser/ComfyUI/main.py --listen 0.0.0.0 --port 8188 ${COMFYUI_FLAGS} &
PID_COMFYUI=$!

# --- Start FileBrowser ---
echo "Starting FileBrowser..."
filebrowser -r /home/comfyuser/workspace -a 0.0.0.0 -p 8080 &
PID_FILEBROWSER=$!

# --- Wait for services to exit ---
wait $PID_COMFYUI
wait $PID_FILEBROWSER