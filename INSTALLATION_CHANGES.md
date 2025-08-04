# ComfyUI Installation Changes

## Overview

This document describes the changes made to improve ComfyUI dependency management and resolve PyTorch installation conflicts.

## Problem

The previous installation approach used `comfy-cli` which could conflict with existing PyTorch installations, leading to:
- Version conflicts between PyTorch installations
- Unpredictable dependency resolution
- Potential runtime issues with CUDA compatibility

## Solution

### 1. Explicit PyTorch Version Management

**Before:**
```dockerfile
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

**After:**
```dockerfile
RUN pip install torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
    --index-url https://download.pytorch.org/whl/cu121 \
    --no-deps && \
    pip install numpy pillow requests tqdm psutil
```

### 2. Manual ComfyUI Installation

**Before:**
```dockerfile
RUN echo "y" | comfy --workspace /workspace/ComfyUI install
```

**After:**
```dockerfile
RUN mkdir -p /workspace && \
    cd /workspace && \
    git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    git checkout v0.3.48 && \
    pip install --no-deps -r requirements.txt && \
    pip install xformers --index-url https://download.pytorch.org/whl/cu121
```

### 3. Dependency Validation

Added comprehensive validation scripts:
- `validate_dependencies.sh` - Validates PyTorch and ComfyUI installation
- `comfyui_health_check.sh` - Performs runtime health checks

## Key Changes

### Files Modified

1. **Dockerfile**
   - Explicit PyTorch version pinning
   - Manual ComfyUI installation via git clone
   - Added dependency validation during build

2. **config/requirements.txt**
   - Removed `comfy-cli` to avoid conflicts
   - Updated comments to reflect new approach

3. **config/versions.conf**
   - Added explicit version variables for all PyTorch components
   - Added ComfyUI repository URL

4. **scripts/system_setup.sh**
   - Added dependency validation call
   - Improved error handling for ComfyUI path

### New Files

1. **scripts/validate_dependencies.sh**
   - Validates PyTorch installation and CUDA availability
   - Checks ComfyUI directory structure
   - Tests ComfyUI module imports
   - Detects potential dependency conflicts

2. **scripts/comfyui_health_check.sh**
   - Comprehensive ComfyUI functionality test
   - Model management validation
   - Node system verification
   - Permission and configuration checks

3. **tests/test_installation_approach.sh**
   - Validates the new installation approach
   - Tests Dockerfile syntax and requirements
   - Verifies dependency resolution strategy

## Benefits

1. **Predictable Dependencies**: Explicit version pinning ensures consistent installations
2. **Conflict Resolution**: Manual installation avoids CLI tool conflicts
3. **Better Validation**: Comprehensive health checks catch issues early
4. **Maintainability**: Clear separation of concerns and better documentation

## Version Compatibility

- **CUDA**: 12.8.1 (compatible with 12.1 PyTorch builds)
- **PyTorch**: 2.5.1+cu121
- **Torchvision**: 0.20.1+cu121
- **Torchaudio**: 2.5.1+cu121
- **ComfyUI**: v0.3.48
- **Python**: 3.11

## Testing

Run the validation test:
```bash
cd nexis/tests
./test_installation_approach.sh
```

This will validate:
- Dockerfile syntax
- Requirements file format
- Version compatibility
- Script syntax and permissions
- Dependency resolution strategy

## Migration Notes

When building with these changes:
1. The build process will take slightly longer due to git clone
2. Dependency validation runs during build and startup
3. All scripts are properly validated for syntax and permissions
4. ComfyUI is installed to `/home/comfyuser/workspace/ComfyUI`

## Troubleshooting

If you encounter issues:
1. Check the validation script output during build
2. Review dependency validation logs during startup
3. Run the health check script manually if needed
4. Ensure all version constraints are compatible with your base image