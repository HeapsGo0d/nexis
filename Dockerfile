# ──────────────────────────────────────────
# Build stage
# ──────────────────────────────────────────
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS build
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8

# System deps + Python 3.11
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.11 python3.11-venv python3.11-dev \
        build-essential gcc ninja-build \
        git curl jq aria2 git-lfs \
        ffmpeg libgl1 libglib2.0-0 wget vim && \
    printf "/usr/local/cuda-12.8/lib64\n/usr/local/cuda-12.8/targets/x86_64-linux/lib\n" \
        > /etc/ld.so.conf.d/cuda.conf && ldconfig && \
    rm -rf /var/lib/apt/lists/*

# Self-contained venv
RUN /usr/bin/python3.11 -m venv --copies /opt/venv && \
    cp -f /usr/bin/python3.11 /opt/venv/bin/python3.11 && \
    ln -sf /opt/venv/bin/python3.11 /opt/venv/bin/python && \
    /opt/venv/bin/python -V
ENV PATH="/opt/venv/bin:$PATH"

# PyTorch (CUDA 12.8 wheels)
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install \
        --index-url https://download.pytorch.org/whl/cu128 \
        torch==2.7.1+cu128 torchvision==0.22.1+cu128 torchaudio==2.7.1+cu128

# Quick import test
RUN python - <<'PY'
import torch, platform
print("torch", torch.__version__, "cuda", torch.version.cuda, "python", platform.python_version())
PY

# Base requirements (hash-stripped)
COPY config/requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    sed -E 's/ --hash=sha256:[a-f0-9]+//g' /tmp/requirements.txt > /tmp/requirements.nohash.txt && \
    python -m pip install -r /tmp/requirements.nohash.txt

# Build-time config
COPY config/versions.conf /tmp/versions.conf

# ComfyUI clone + proper package structure setup
RUN . /tmp/versions.conf && \
    mkdir -p /workspace && cd /workspace && \
    git clone "${COMFYUI_REPO}" && cd ComfyUI && git checkout "${COMFYUI_VERSION}" && \
    \
    # Ensure all directories that need to be Python packages have __init__.py
    find . -type d -name "*.py" -prune -o -type d -exec test -f "{}/__init__.py" \; -prune -o -type d -print | \
    while read -r dir; do \
        if [ -n "$(find "$dir" -maxdepth 1 -name "*.py" -print -quit)" ]; then \
            echo "Creating __init__.py in $dir"; \
            touch "$dir/__init__.py"; \
        fi; \
    done && \
    \
    # Specifically ensure critical ComfyUI package directories have __init__.py
    for pkg_dir in utils app comfy model_management nodes execution; do \
        if [ -d "$pkg_dir" ] && [ ! -f "$pkg_dir/__init__.py" ]; then \
            echo "Creating __init__.py in $pkg_dir"; \
            touch "$pkg_dir/__init__.py"; \
        fi; \
    done && \
    \
    # Install ComfyUI requirements without dependencies to avoid conflicts
    pip install --no-deps -r requirements.txt && \
    \
    # Install xformers separately with specific index
    pip install xformers --index-url "${XFORMERS_INDEX_URL}" || \
    echo "xformers wheel not available; continuing"

# ──────────────────────────────────────────
# Production stage
# ──────────────────────────────────────────
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS production
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 1. Copy self-contained venv
COPY --from=build /opt/venv /opt/venv
# 2. Copy std-lib directory required by the venv’s interpreter
COPY --from=build /usr/lib/python3.11 /usr/lib/python3.11

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
ENV PYTHON="${VIRTUAL_ENV}/bin/python"
ENV PIP="${VIRTUAL_ENV}/bin/pip"

# Runtime deps (no system Python package needed now)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        git curl jq aria2 git-lfs \
        ffmpeg libgl1 libglib2.0-0 && \
    printf "/usr/local/cuda-12.8/lib64\n/usr/local/cuda-12.8/targets/x86_64-linux/lib\n" \
        > /etc/ld.so.conf.d/cuda.conf && ldconfig && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# App user + workspace
RUN useradd -m comfyuser && \
    mkdir -p /home/comfyuser/workspace && \
    chown -R comfyuser:comfyuser /home/comfyuser

# ComfyUI
COPY --from=build --chown=comfyuser:comfyuser /workspace/ComfyUI /home/comfyuser/workspace/ComfyUI

# Ensure utils is treated as a package *after* any overwrites
RUN touch /home/comfyuser/workspace/ComfyUI/utils/__init__.py

# Scripts and configs
COPY --chown=comfyuser:comfyuser scripts/ /home/comfyuser/scripts/
COPY --chown=comfyuser:comfyuser entrypoint.sh /home/comfyuser/
COPY --chown=comfyuser:comfyuser config/ /home/comfyuser/config/

# Fix line endings, make executable, sanity-check venv
RUN set -euo pipefail; \
    shopt -s nullglob; \
    files=(/home/comfyuser/entrypoint.sh /home/comfyuser/scripts/*.sh); \
    for f in "${files[@]}"; do sed -i 's/\r$//' "$f"; chmod +x "$f"; done; \
    echo "PATH=$PATH"; "$PYTHON" -V; "$PIP" -V

WORKDIR /home/comfyuser
USER comfyuser

EXPOSE 8188 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=45s --retries=5 \
  CMD curl -fsS http://127.0.0.1:8188 || exit 1

ENTRYPOINT ["/home/comfyuser/entrypoint.sh"]
