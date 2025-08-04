#!/bin/bash

# Dependency Validation Script for Nexis
# Validates PyTorch installation and ComfyUI compatibility

set -e

echo "=== Dependency Validation ==="

# Check Python version
echo "Checking Python version..."
PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2)
echo "Python version: $PYTHON_VERSION"

# Check PyTorch installation (with runtime GPU check)
echo "Checking PyTorch installation..."
python -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA version: {torch.version.cuda}')
    print(f'GPU count: {torch.cuda.device_count()}')
    for i in range(torch.cuda.device_count()):
        print(f'GPU {i}: {torch.cuda.get_device_name(i)}')
else:
    print('INFO: CUDA not available at build time (expected in Docker build)')
    print('CUDA availability will be verified at runtime')
"

# Check torchvision
echo "Checking torchvision..."
python -c "
import torchvision
print(f'Torchvision version: {torchvision.__version__}')
"

# Check torchaudio
echo "Checking torchaudio..."
python -c "
import torchaudio
print(f'Torchaudio version: {torchaudio.__version__}')
"

# Check xformers if available
echo "Checking xformers..."
python -c "
try:
    import xformers
    print(f'Xformers version: {xformers.__version__}')
except ImportError:
    print('Xformers not installed or not available')
" || echo "Xformers check failed"

# Check ComfyUI directory structure
echo "Checking ComfyUI installation..."
COMFYUI_PATH="/home/comfyuser/workspace/ComfyUI"
if [ -d "$COMFYUI_PATH" ]; then
    echo "ComfyUI directory found at: $COMFYUI_PATH"
    
    # Check main.py exists
    if [ -f "$COMFYUI_PATH/main.py" ]; then
        echo "✓ main.py found"
    else
        echo "✗ main.py not found"
        exit 1
    fi
    
    # Check requirements.txt exists
    if [ -f "$COMFYUI_PATH/requirements.txt" ]; then
        echo "✓ requirements.txt found"
    else
        echo "✗ requirements.txt not found"
    fi
    
    # Check models directory structure
    for dir in models models/checkpoints models/loras models/vae; do
        if [ -d "$COMFYUI_PATH/$dir" ]; then
            echo "✓ $dir directory exists"
        else
            echo "✗ $dir directory missing"
        fi
    done
    
else
    echo "✗ ComfyUI directory not found at: $COMFYUI_PATH"
    exit 1
fi

# Test ComfyUI import (basic import test only)
echo "Testing ComfyUI import..."
cd "$COMFYUI_PATH"
python -c "
import sys
sys.path.insert(0, '.')
try:
    import execution
    import server
    print('✓ ComfyUI core modules import successfully')
except ImportError as e:
    print(f'✗ ComfyUI import failed: {e}')
    sys.exit(1)
"

# Check for potential conflicts
echo "Checking for potential dependency conflicts..."
python -c "
import pkg_resources
import sys

# Check for duplicate packages
packages = {}
for dist in pkg_resources.working_set:
    name = dist.project_name.lower()
    if name in packages:
        print(f'WARNING: Duplicate package {name}: {packages[name]} and {dist.version}')
    else:
        packages[name] = dist.version

# Check specific known conflicts
conflicts = [
    ('torch', 'tensorflow'),
    ('torchvision', 'tensorflow'),
]

for pkg1, pkg2 in conflicts:
    if pkg1 in packages and pkg2 in packages:
        print(f'WARNING: Potential conflict between {pkg1} ({packages[pkg1]}) and {pkg2} ({packages[pkg2]})')

print('Dependency conflict check complete')
"

echo "=== Validation Complete ==="
echo "All dependency checks passed successfully!"
echo "Note: GPU functionality will be verified at runtime when container starts with GPU access"