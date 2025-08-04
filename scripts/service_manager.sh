#!/bin/bash
set -euo pipefail

# Default configuration
COMFYUI_FLAGS="${COMFYUI_FLAGS:---disable-auto-launch --disable-metadata-preview}"
COMFYUI_URL="http://localhost:8188"
FILEBROWSER_URL="http://localhost:8080"
HEALTH_CHECK_INTERVAL=30
PID_COMFYUI=""
PID_FILEBROWSER=""
SHUTDOWN_REQUESTED=false

# Signal handler for graceful shutdown
handle_signal() {
    echo "Shutting down services..."
    SHUTDOWN_REQUESTED=true
    kill -TERM $PID_COMFYUI $PID_FILEBROWSER 2>/dev/null
}
trap handle_signal SIGTERM SIGINT

# Check if service is running
check_service() {
    local pid=$1
    local url=$2
    local name=$3
    
    if ! kill -0 $pid 2>/dev/null; then
        echo "$name process not running (PID: $pid)"
        return 1
    fi
    
    if ! curl -s --head --fail "$url" >/dev/null; then
        echo "$name health check failed (URL: $url)"
        return 1
    fi
    
    return 0
}

# Start a service with basic error handling
start_service() {
    local command=$1
    local name=$2
    local url=$3
    
    echo "Starting $name..."
    if ! eval "$command &"; then
        echo "Failed to start $name" >&2
        return 1
    fi
    local pid=$!
    
    sleep 5
    if check_service $pid "$url" "$name"; then
        echo "$name started (PID: $pid)"
        echo $pid
        return 0
    else
        kill -9 $pid 2>/dev/null
        return 1
    fi
}

# Main execution
PID_COMFYUI=$(start_service "python /home/comfyuser/ComfyUI/main.py --listen 0.0.0.0 --port 8188 ${COMFYUI_FLAGS}" "ComfyUI" "$COMFYUI_URL") || exit 1

FILEBROWSER_CMD="/home/comfyuser/filebrowser -r /home/comfyuser/workspace -a 0.0.0.0 -p 8080"
[ -n "$FB_USERNAME" ] && [ -n "$FB_PASSWORD" ] && FILEBROWSER_CMD="$FILEBROWSER_CMD --username $FB_USERNAME --password $FB_PASSWORD"

PID_FILEBROWSER=$(start_service "$FILEBROWSER_CMD" "FileBrowser" "$FILEBROWSER_URL") || {
    kill -TERM $PID_COMFYUI 2>/dev/null
    exit 1
}

# Health monitoring loop
while ! $SHUTDOWN_REQUESTED; do
    check_service $PID_COMFYUI "$COMFYUI_URL" "ComfyUI" || {
        echo "Restarting ComfyUI..."
        PID_COMFYUI=$(start_service "python /home/comfyuser/ComfyUI/main.py --listen 0.0.0.0 --port 8188 ${COMFYUI_FLAGS}" "ComfyUI" "$COMFYUI_URL") || exit 1
    }
    
    check_service $PID_FILEBROWSER "$FILEBROWSER_URL" "FileBrowser" || {
        echo "Restarting FileBrowser..."
        PID_FILEBROWSER=$(start_service "$FILEBROWSER_CMD" "FileBrowser" "$FILEBROWSER_URL") || exit 1
    }
    
    sleep $HEALTH_CHECK_INTERVAL
done

wait $PID_COMFYUI
wait $PID_FILEBROWSER
echo "Services stopped"