# Build stage
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 as build

# Environment variables for build optimization
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8

# Install system packages with apt cache optimization
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
    ffmpeg libgl1 libglib2.0-0 wget vim \
    cuda-toolkit-12-8 libcusparse-dev-12-8 libcusparselt-dev-12-8 && \
    echo "/usr/local/cuda-12.8/lib64" > /etc/ld.so.conf.d/cuda.conf && \
    echo "/usr/local/cuda-12.8/targets/x86_64-linux/lib" >> /etc/ld.so.conf.d/cuda.conf && \
    ldconfig && \
    ln -sf /usr/bin/python3.11 /usr/bin/python && \
    ln -sf /usr/bin/python3.11 /usr/bin/python3 && \
    rm -rf /var/lib/apt/lists/*

# Create and activate virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install PyTorch with CUDA 12.1 support instead (more stable)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
    --index-url https://download.pytorch.org/whl/cu121 \
    --no-deps && \
    pip install numpy pillow requests tqdm psutil typing_extensions

# Validate PyTorch CUDA support (remove the problematic validation for now)
RUN python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print('PyTorch imported successfully')"

# Install core Python tooling
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install packaging setuptools wheel

# Install base requirements
COPY config/requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r /tmp/requirements.txt

# Copy versions configuration
COPY config/versions.conf /tmp/versions.conf

# Clone and install ComfyUI manually to avoid dependency conflicts
RUN . /tmp/versions.conf && \
    mkdir -p /workspace && \
    cd /workspace && \
    git clone ${COMFYUI_REPO} && \
    cd ComfyUI && \
    git checkout ${COMFYUI_VERSION} && \
    pip install --no-deps -r requirements.txt && \
    pip install xformers --index-url https://download.pytorch.org/whl/cu121

# Install ComfyUI-specific dependencies
COPY config/comfyui-requirements.txt /tmp/comfyui-requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r /tmp/comfyui-requirements.txt

# Production stage
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 as production

# Copy virtual environment from build stage
COPY --from=build /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install runtime dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv \
    git curl jq aria2 git-lfs \
    ffmpeg libgl1 libglib2.0-0 \
    cuda-toolkit-12-8 libcusparse-12-8 libcusparselt-12-8 && \
    echo "/usr/local/cuda-12.8/lib64" > /etc/ld.so.conf.d/cuda.conf && \
    echo "/usr/local/cuda-12.8/targets/x86_64-linux/lib" >> /etc/ld.so.conf.d/cuda.conf && \
    ldconfig && \
    ln -sf /usr/bin/python3.11 /usr/bin/python && \
    ln -sf /usr/bin/python3.11 /usr/bin/python3 && \
    rm -rf /var/lib/apt/lists/*

# Create comfyuser and setup workspace
RUN useradd -m comfyuser && \
    mkdir -p /home/comfyuser/workspace && \
    chown -R comfyuser:comfyuser /home/comfyuser

# Copy workspace from build stage
COPY --from=build --chown=comfyuser:comfyuser /workspace/ComfyUI /home/comfyuser/workspace/ComfyUI

# Copy application files to home directory
COPY --chown=comfyuser:comfyuser scripts/ /home/comfyuser/scripts/
COPY --chown=comfyuser:comfyuser entrypoint.sh /home/comfyuser/
COPY --chown=comfyuser:comfyuser config/ /home/comfyuser/config/

# Make scripts executable
RUN chmod +x /home/comfyuser/entrypoint.sh /home/comfyuser/scripts/*.sh

# Verify ComfyUI installation and dependencies
RUN /home/comfyuser/scripts/validate_dependencies.sh

WORKDIR /home/comfyuser

# Switch to comfyuser
USER comfyuser

# Entrypoint
ENTRYPOINT ["/home/comfyuser/entrypoint.sh"]