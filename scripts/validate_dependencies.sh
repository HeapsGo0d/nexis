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

echo "Checking ComfyUI package structure..."
for critical_dir in utils app comfy model_management nodes execution; do
    full_path="$COMFYUI_PATH/$critical_dir"
    if [ -d "$full_path" ]; then
        if [ -f "$full_path/__init__.py" ]; then
            echo "✓ $critical_dir is a proper Python package"
        else
            echo "⚠ $critical_dir directory exists but missing __init__.py - fixing..."
            touch "$full_path/__init__.py"
            echo "✓ Created __init__.py for $critical_dir"
        fi
    else
        echo "✗ $critical_dir directory missing"
    fi
done

echo "Testing ComfyUI import with detailed error reporting..."
cd "$COMFYUI_PATH"
"$PYTHON" - <<'PY'
import sys
import os
sys.path.insert(0, '.')

print("Python path:")
for p in sys.path[:5]:  # First 5 entries
    print(f"  {p}")

print("Checking directory structure:")
critical_dirs = ['utils', 'app', 'comfy', 'model_management', 'nodes', 'execution']
for dirname in critical_dirs:
    if os.path.isdir(dirname):
        init_path = os.path.join(dirname, '__init__.py')
        if os.path.isfile(init_path):
            print(f"  ✓ {dirname}/ has __init__.py")
        else:
            print(f"  ✗ {dirname}/ missing __init__.py")
            # Create it
            with open(init_path, 'w') as f:
                pass
            print(f"  ✓ Created __init__.py for {dirname}")
    else:
        print(f"  ✗ {dirname}/ directory not found")

print("Testing individual imports:")
modules_to_test = [
    'utils.install_util',
    'app.frontend_management', 
    'execution',
    'server',
    'nodes',
    'model_management'
]

failed_imports = []
for module in modules_to_test:
    try:
        __import__(module)
        print(f"  ✓ {module}")
    except ImportError as e:
        print(f"  ✗ {module}: {e}")
        failed_imports.append((module, str(e)))

if failed_imports:
    print("\nDetailed import failure analysis:")
    for module, error in failed_imports:
        print(f"  {module}: {error}")
        # Try to provide helpful hints
        if "'utils' is not a package" in error:
            print("    → This suggests utils/__init__.py is missing or inaccessible")
        elif "cannot import name" in error:
            print("    → This suggests missing dependencies or circular imports")

# Final comprehensive test
try:
    import execution, server
    print('✓ ComfyUI core modules imported successfully')
except ImportError as e:
    print(f'✗ ComfyUI import failed: {e}')
    print("This indicates a structural issue with the ComfyUI installation")
    # Don't exit here, let's continue with other checks
PY

echo "Checking for dependency conflicts..."
"$PYTHON" - <<'PY'
import pkg_resources
pkgs = {}
for d in pkg_resources.working_set:
    n = d.project_name.lower()
    if n in pkgs:
        print(f'WARNING: duplicate package {n}: {pkgs[n]} and {d.version}')
    else:
        pkgs[n] = d.version
for a,b in [('torch','tensorflow'),('torchvision','tensorflow')]:
    if a in pkgs and b in pkgs:
        print(f'WARNING: potential conflict {a}({pkgs[a]}) vs {b}({pkgs[b]})')
print('Dependency conflict check complete')
PY

echo "=== Validation Complete ==="
echo "Note: Some import issues may resolve after ensuring proper package structure"