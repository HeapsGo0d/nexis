# Nexis Production Implementation Notes

This document captures the real-world challenges encountered during Nexis development and the production-tested solutions implemented.

## Build Challenges and Solutions

### 1. CUDA Runtime Library Issues

**Problem**: The `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04` base image didn't include `libcusparseLt.so.0` that PyTorch 2.7.1+cu128 expects.

**Symptoms**:
```
OSError: libcusparseLt.so.0: cannot open shared object file: No such file or directory
```

**Solution**: Let PyTorch wheels bring their own CUDA libraries instead of relying on system packages.

**Implementation**:
```dockerfile
# OLD (problematic):
# RUN apt-get install -y cuda-toolkit-12-8 libcusparse-dev-12-8

# NEW (working):
RUN python -m pip install \
    --index-url https://download.pytorch.org/whl/cu128 \
    torch==2.7.1+cu128 torchvision==0.22.1+cu128 torchaudio==2.7.1+cu128
```

### 2. CI/CD CPU-Only Build Compatibility

**Problem**: Build hosts without NVIDIA drivers caused any `torch.cuda` calls to fail during Docker build.

**Symptoms**:
```
RuntimeError: Found no NVIDIA driver on your system
```

**Solution**: Conditional CUDA validation that skips GPU checks when no driver is present.

**Implementation**:
```bash
# In entrypoint.sh
if ! nvidia-smi >/dev/null 2>&1; then
  export SKIP_CUDA_CHECK=1
fi

# In validate_dependencies.sh
# (Python script)
import os
skip = os.getenv("SKIP_CUDA_CHECK") == "1"
if skip:
    print("CUDA check skipped (SKIP_CUDA_CHECK=1)")
else:
    print(f'CUDA available: {torch.cuda.is_available()}')
```

### 3. Python Virtual Environment Issues

**Problem**: Runtime stage copied `/opt/venv` but not `/usr/lib/python3.11`, causing `ModuleNotFoundError` for standard library modules like 'encodings'.

**Symptoms**:
```
ModuleNotFoundError: No module named 'encodings'
```

**Solution**: Create self-contained virtual environment with `--copies` flag and explicitly copy Python standard library.

**Implementation**:
```dockerfile
# Build stage - self-contained venv
RUN /usr/bin/python3.11 -m venv --copies /opt/venv && \
    cp -f /usr/bin/python3.11 /opt/venv/bin/python3.11

# Production stage - copy both venv and stdlib
COPY --from=build /opt/venv /opt/venv
COPY --from=build /usr/lib/python3.11 /usr/lib/python3.11
```

### 4. Script Compatibility Issues

**Problem**: Windows CRLF line endings made shell scripts non-executable inside containers.

**Symptoms**:
```
bash: ./script.sh: /bin/bash^M: bad interpreter
```

**Solution**: Automatically fix line endings and permissions in Dockerfile.

**Implementation**:
```dockerfile
RUN set -euo pipefail; \
    shopt -s nullglob; \
    files=(/home/comfyuser/entrypoint.sh /home/comfyuser/scripts/*.sh); \
    for f in "${files[@]}"; do sed -i 's/\r$//' "$f"; chmod +x "$f"; done
```

## Production Hardening Implemented

### Enhanced Signal Handling

**Problem**: Container didn't handle shutdown signals gracefully.

**Solution**: Proper signal forwarding from entrypoint to service manager.

```bash
# In entrypoint.sh
forward_signal() {
  local sig="$1"
  log "Signal $sig received."
  if [[ -n "${SERVICE_MANAGER_PID}" ]] && kill -0 "${SERVICE_MANAGER_PID}" 2>/dev/null; then
    log "Forwarding $sig to service manager (pid=${SERVICE_MANAGER_PID})..."
    kill -"$sig" "${SERVICE_MANAGER_PID}" || true
    wait "${SERVICE_MANAGER_PID}" || true
  fi
  exit 0
}
trap 'forward_signal TERM' TERM
trap 'forward_signal INT'  INT
```

### Structured Logging

**Problem**: Inconsistent log formats made debugging difficult.

**Solution**: ISO 8601 timestamps with consistent format.

```bash
# In entrypoint.sh and other scripts
log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }
```

### Health Monitoring

**Problem**: No way to detect service failures or container health.

**Solution**: Docker health checks with proper startup periods.

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=45s --retries=5 \
  CMD curl -fsS http://127.0.0.1:8188 || exit 1
```

## Build Optimization Strategies

### Multi-Stage Build Benefits

1.  **Smaller Production Images**: Build tools and dev dependencies stay in build stage.
2.  **Better Caching**: Separate stages allow better Docker layer caching.
3.  **Security**: Production stage has minimal attack surface.

### Cache Mount Optimization

```dockerfile
# APT cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && apt-get install -y ...

# Pip cache
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

### Hash Stripping for Flexibility

```dockerfile
# Remove pip hashes for easier dependency updates
RUN sed -E 's/ --hash=sha256:[a-f0-9]+//g' /tmp/requirements.txt > /tmp/requirements.nohash.txt
```

## Testing Strategy

### CPU-Only CI Testing

```bash
# Test build stage on CPU-only hosts
docker build --target build -t nexis:build-test .

# Skip CUDA validation in tests
export SKIP_CUDA_CHECK=1
./tests/test_docker_build.sh
```

### GPU Runtime Testing

```bash
# Full GPU testing on GPU-enabled hosts
./tests/run_all_tests.sh
```

## Performance Optimizations

### Virtual Environment Efficiency

-   **`--copies` flag**: Makes venv relocatable between build and runtime stages.
-   **Explicit interpreter copying**: Ensures consistent Python executable.
-   **Standard library copying**: Provides complete Python environment.

### Download Optimization

-   **Parallel downloads**: `aria2c` with 8 connections.
-   **Resume capability**: `--continue=true` for interrupted downloads.
-   **Organized staging**: Downloads to temp directory before organization.

### Service Management

-   **Health check loops**: Automatic service restart on failure.
-   **Graceful shutdown**: Proper signal handling for clean termination.
-   **Resource monitoring**: Process and port monitoring.

## Deployment Considerations

### RunPod Template Configuration

```json
{
  "containerDiskInGb": 150,
  "dockerArgs": "--security-opt=no-new-privileges --cap-drop=ALL --dns=8.8.8.8",
  "env": [
    { "key": "DEBUG_MODE", "value": "false" },
    { "key": "COMFYUI_FLAGS", "value": "--bf16-unet" },
    { "key": "HUGGINGFACE_TOKEN", "value": "{{ RUNPOD_SECRET_huggingface.co }}" },
    { "key": "CIVITAI_TOKEN", "value": "{{ RUNPOD_SECRET_civitai.com }}" }
  ]
}
```

### Security Hardening

-   **No new privileges**: `--security-opt=no-new-privileges`
-   **Capability dropping**: `--cap-drop=ALL`
-   **Custom DNS**: Avoid DNS issues with `--dns=8.8.8.8`
-   **Non-root user**: All services run as `comfyuser`.

## Monitoring and Debugging

### Log Analysis

```bash
# Check structured logs
docker logs container_name | grep -E '\[20[0-9]{2}-[0-9]{2}-[0-9]{2}T'

# Monitor service health
docker exec container_name curl -s http://localhost:8188/system_stats
```

### Debug Mode

```bash
# Enable detailed logging
docker run -e DEBUG_MODE=true nexis:latest

# Check debug folder
docker exec container_name find /workspace/debug -type f
```

### Performance Monitoring

```bash
# Resource usage
docker stats container_name

# GPU utilization
docker exec container_name nvidia-smi
```

## Lessons Learned

1.  **Test on CPU-only hosts early**: Many CI/CD systems don't have GPUs.
2.  **Virtual environments need careful handling**: Standard library dependencies matter.
3.  **CUDA libraries are complex**: Let PyTorch wheels handle CUDA dependencies.
4.  **Signal handling is critical**: Proper shutdown prevents data loss.
5.  **Structured logging saves time**: Consistent formats enable better debugging.
6.  **Multi-stage builds are worth it**: Better caching and smaller production images.
7.  **Line endings matter**: Always handle Windows/Unix compatibility.
8.  **Health checks are essential**: Early detection of service failures.

## Future Improvements

1.  **Automated testing**: CI/CD pipeline with both CPU and GPU testing.
2.  **Metrics collection**: Prometheus/Grafana integration for monitoring.
3.  **Configuration management**: External config files for easier customization.
4.  **Security scanning**: Regular vulnerability assessments.
5.  **Performance profiling**: Detailed performance analysis and optimization.