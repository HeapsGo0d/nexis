#!/bin/bash

# --- Signal Handling ---
trap 'echo "SIGTERM received, forwarding to service manager..."; kill -TERM $SERVICE_MANAGER_PID; wait $SERVICE_MANAGER_PID' SIGTERM
trap 'echo "SIGINT received, forwarding to service manager..."; kill -INT $SERVICE_MANAGER_PID; wait $SERVICE_MANAGER_PID' SIGINT

# --- Security Defaults ---
umask 002
# Disable core dumps
ulimit -c 0

# --- Environment ---
export HOME=/home/comfyuser
export WORKSPACE=/home/comfyuser/workspace

# --- Startup Sequence ---
echo "Starting Nexis Entrypoint..."

# 1. System Setup
echo "Running system setup..."
/home/comfyuser/scripts/system_setup.sh
if [ $? -ne 0 ]; then
    echo "System setup failed. Exiting."
    exit 1
fi

# 2. Model Downloads
echo "Running download manager..."
/home/comfyuser/scripts/download_manager.sh
if [ $? -ne 0 ]; then
    echo "Download manager failed. Continuing without models."
fi

# 3. Start Services
echo "Running service manager..."
/home/comfyuser/scripts/service_manager.sh &
SERVICE_MANAGER_PID=$!

# --- Health Monitoring ---
while true; do
    # Basic health check: ensure the service manager is running
    if ! kill -0 $SERVICE_MANAGER_PID 2>/dev/null; then
        echo "Service manager has died. Exiting."
        exit 1
    fi
    sleep 30
done