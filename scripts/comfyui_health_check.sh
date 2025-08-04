#!/bin/bash

# ComfyUI Health Check Script
# Performs a comprehensive health check of the ComfyUI installation

set -e

echo "=== ComfyUI Health Check ==="

COMFYUI_PATH="/home/comfyuser/workspace/ComfyUI"
cd "$COMFYUI_PATH"

# Test basic ComfyUI functionality
echo "Testing ComfyUI basic functionality..."
timeout 30 python -c "
import sys
sys.path.insert(0, '.')

# Test core imports
try:
    import execution
    import server
    import nodes
    import model_management
    print('✓ Core ComfyUI modules imported successfully')
except ImportError as e:
    print(f'✗ Failed to import core modules: {e}')
    sys.exit(1)

# Test model management
try:
    import model_management
    print(f'✓ Model management available')
    print(f'  - Memory management: {model_management.get_torch_device()}')
    print(f'  - VRAM state: {model_management.get_free_memory()}MB free')
except Exception as e:
    print(f'✗ Model management test failed: {e}')

# Test node loading
try:
    import nodes
    node_list = nodes.NODE_CLASS_MAPPINGS
    print(f'✓ Node system loaded: {len(node_list)} node types available')
except Exception as e:
    print(f'✗ Node loading failed: {e}')
    sys.exit(1)

print('✓ ComfyUI health check passed')
" || {
    echo "✗ ComfyUI health check failed"
    exit 1
}

# Check for common issues
echo "Checking for common configuration issues..."

# Check model directories
for dir in models/checkpoints models/loras models/vae models/upscale_models models/embeddings; do
    if [ ! -d "$dir" ]; then
        echo "⚠ Warning: $dir directory missing, creating..."
        mkdir -p "$dir"
    else
        echo "✓ $dir directory exists"
    fi
done

# Check permissions
echo "Checking file permissions..."
if [ -w "$COMFYUI_PATH" ]; then
    echo "✓ ComfyUI directory is writable"
else
    echo "✗ ComfyUI directory is not writable"
    exit 1
fi

# Check for conflicting packages
echo "Checking for package conflicts..."
python -c "
import pkg_resources
import sys

# Known problematic combinations
conflicts = [
    ('torch', '2.0.0', 'xformers', '0.0.16'),  # Example conflict
]

installed = {dist.project_name.lower(): dist.version for dist in pkg_resources.working_set}

for pkg1, ver1, pkg2, ver2 in conflicts:
    if pkg1 in installed and pkg2 in installed:
        if installed[pkg1].startswith(ver1) and installed[pkg2].startswith(ver2):
            print(f'⚠ Warning: Potential conflict between {pkg1} {installed[pkg1]} and {pkg2} {installed[pkg2]}')

print('✓ Package conflict check complete')
"

echo "=== Health Check Complete ==="
echo "ComfyUI is ready for use!"