#!/usr/bin/env bash
set -euo pipefail

echo "=== Dependency Validation ==="

# Prefer the venv interpreter; allow override via env
PYTHON="${PYTHON:-/opt/venv/bin/python}"
PIP="${PIP:-/opt/venv/bin/pip}"

if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "✗ Python not found at: $PYTHON"
  echo "PATH: $PATH"
  exit 127
fi

echo "Checking Python..."
echo "Python: $("$PYTHON" -V) at $(command -v "$PYTHON")"

echo "Checking PyTorch..."
"$PYTHON" - <<'PY'
import os, torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA version in wheel: {torch.version.cuda}')
skip = os.getenv("SKIP_CUDA_CHECK") == "1"
if skip:
    print("CUDA check skipped (SKIP_CUDA_CHECK=1)")
else:
    print(f'CUDA available: {torch.cuda.is_available()}')
    if torch.cuda.is_available():
        for i in range(torch.cuda.device_count()):
            print(f'GPU {i}: {torch.cuda.get_device_name(i)}')
PY


echo "Checking torchvision..."
"$PYTHON" - <<'PY'
import torchvision
print(f'Torchvision: {torchvision.__version__}')
PY

echo "Checking torchaudio..."
"$PYTHON" - <<'PY'
import torchaudio
print(f'Torchaudio: {torchaudio.__version__}')
PY

echo "Checking xformers..."
"$PYTHON" - <<'PY'
try:
    import xformers
    print(f'Xformers: {xformers.__version__}')
except Exception as e:
    print(f'Xformers not available: {e}')
PY

COMFYUI_PATH="/home/comfyuser/workspace/ComfyUI"
echo "Checking ComfyUI at ${COMFYUI_PATH}..."
if [ -d "$COMFYUI_PATH" ]; then
  echo "✓ directory exists"
  [ -f "$COMFYUI_PATH/main.py" ] && echo "✓ main.py found" || { echo "✗ main.py missing"; exit 1; }
  [ -f "$COMFYUI_PATH/requirements.txt" ] && echo "✓ requirements.txt found" || echo "✗ requirements.txt missing"
  for d in models models/checkpoints models/loras models/vae; do
    [ -d "$COMFYUI_PATH/$d" ] && echo "✓ $d present" || echo "✗ $d missing"
  done
else
  echo "✗ ComfyUI directory missing"; exit 1
fi

echo "Testing ComfyUI import..."
cd "$COMFYUI_PATH"
"$PYTHON" - <<'PY'
import sys
sys.path.insert(0, '.')
try:
    import execution, server
    print('✓ ComfyUI core modules import successfully')
except ImportError as e:
    print(f'✗ ComfyUI import failed: {e}')
    raise
PY

echo "Checking for dependency conflicts..."
"$PYTHON" - <<'PY'
import pkg_resources
pkgs = {}
for d in pkg_resources.working_set:
    n = d.project_name.lower()
    if n in pkgs:
        print(f'WARNING duplicate package {n}: {pkgs[n]} and {d.version}')
    else:
        pkgs[n] = d.version
for a,b in [('torch','tensorflow'),('torchvision','tensorflow')]:
    if a in pkgs and b in pkgs:
        print(f'WARNING potential conflict {a}({pkgs[a]}) vs {b}({pkgs[b]})')
print('Dependency conflict check complete')
PY

echo "=== Validation Complete ==="
