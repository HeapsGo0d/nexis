#!/bin/bash
set -e

# Test aria2c download
echo "Testing aria2c download..."
aria2c -x 16 -s 16 -k 1M https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth -d /tmp -o control.pth
if [ -f /tmp/control.pth ]; then
    echo "aria2c download successful."
    rm /tmp/control.pth
else
    echo "aria2c download failed."
    exit 1
fi

# Test git-lfs download
echo "Testing git-lfs download..."
git lfs install
git clone https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0 /tmp/sdxl
if [ -d /tmp/sdxl/.git ]; then
    echo "git-lfs clone successful."
    rm -rf /tmp/sdxl
else
    echo "git-lfs clone failed."
    exit 1
fi

echo "All download tests passed!"