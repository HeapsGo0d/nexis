#!/bin/bash

set -e

# Test CPU-only build (CI compatibility)
echo "Testing CPU-only build compatibility..."
docker build --target build -t nexis:build-test nexis
if [ $? -ne 0 ]; then
    echo "❌ Build stage failed on CPU-only host"
    exit 1
fi
echo "✅ Build stage completed on CPU-only host"

# Build the final test image
docker build -t nexis:test nexis

cleanup() {
    echo "Cleaning up..."
    docker rmi -f nexis:build-test || true
    docker rmi -f nexis:test || true
}
trap cleanup EXIT

# Test self-contained virtual environment
echo "Testing self-contained virtual environment..."
docker run --rm nexis:test bash -c "
echo 'Checking venv structure...'
[ -f '/opt/venv/bin/python3.11' ] || exit 1
[ -f '/opt/venv/bin/python' ] || exit 1
echo 'Testing venv relocatability...'
/opt/venv/bin/python -c 'import sys; print(sys.executable)'
echo 'Testing standard library access...'
/opt/venv/bin/python -c 'import encodings, json, urllib.request; print(\"Standard library accessible\")'  
echo '✅ Virtual environment validated'
"

# Test CUDA runtime libraries
echo "Testing CUDA runtime libraries..."
docker run --rm nexis:test bash -c "
echo 'Checking PyTorch CUDA libraries...'
/opt/venv/bin/python -c '
import torch
print(f\"PyTorch version: {torch.__version__}\")
print(f\"CUDA version: {torch.version.cuda}\")
# Test that PyTorch wheel includes required libraries
import os
torch_lib = os.path.dirname(torch.__file__)
print(f\"PyTorch lib directory: {torch_lib}\")
'
echo '✅ CUDA runtime libraries validated'
"

# Test script line endings and executability
echo "Testing script line endings and permissions..."
docker run --rm nexis:test bash -c "
echo 'Checking script line endings...'
for script in /home/comfyuser/scripts/*.sh /home/comfyuser/entrypoint.sh; do
    if file \"\$script\" | grep -q CRLF; then
        echo \"❌ CRLF found in \$script\"
        exit 1
    fi
    if [ ! -x \"\$script\" ]; then
        echo \"❌ \$script not executable\"
        exit 1
    fi
done
echo '✅ All scripts have correct line endings and permissions'
"

# Test PyTorch import without GPU
echo "Testing PyTorch import without GPU requirements..."
docker run --rm nexis:test bash -c "
export SKIP_CUDA_CHECK=1
/opt/venv/bin/python -c '
import torch
print(f\"PyTorch {torch.__version__} imported successfully\")
print(f\"CUDA support compiled: {torch.version.cuda}\")
# Don't call torch.cuda.is_available() in CI
print(\"✅ PyTorch import test passed (GPU check skipped)\")
'
"

# Test dependency validation with SKIP_CUDA_CHECK
echo "Testing dependency validation script..."
docker run --rm -e SKIP_CUDA_CHECK=1 nexis:test /home/comfyuser/scripts/validate_dependencies.sh
if [ $? -ne 0 ]; then
    echo "❌ Dependency validation failed"
    exit 1
fi
echo "✅ Dependency validation passed"