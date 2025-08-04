# Nexis Dockerfile
# Base Image: NVIDIA PyTorch for CUDA 12.x
FROM nvcr.io/nvidia/pytorch:24.04-py3 AS base

# Stage 1: Build Environment
FROM base AS build

# System Dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    jq \
    aria2 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash comfyuser
USER comfyuser
WORKDIR /home/comfyuser

# Copy configuration
COPY --chown=comfyuser:comfyuser config/ /home/comfyuser/config/

# Install ComfyUI
ARG COMFYUI_VERSION
RUN git clone --branch ${COMFYUI_VERSION} https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip install --no-cache-dir -r requirements.txt

# Install FileBrowser
ARG FILEBROWSER_VERSION
RUN curl -fsSL https://github.com/filebrowser/filebrowser/releases/download/v${FILEBROWSER_VERSION}/linux-amd64-filebrowser.tar.gz | tar -C /home/comfyuser/ -xzvf -

# Stage 2: Production Image
FROM base

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash comfyuser
USER comfyuser
WORKDIR /home/comfyuser

# Copy from build stage
COPY --from=build --chown=comfyuser:comfyuser /home/comfyuser/ComfyUI /home/comfyuser/ComfyUI
COPY --from=build --chown=comfyuser:comfyuser /home/comfyuser/filebrowser /usr/local/bin/filebrowser
COPY --chown=comfyuser:comfyuser scripts/ /home/comfyuser/scripts/
COPY --chown=comfyuser:comfyuser entrypoint.sh /home/comfyuser/entrypoint.sh

# Set up workspace
RUN mkdir -p /home/comfyuser/workspace/models && \
    ln -s /home/comfyuser/workspace/models /home/comfyuser/ComfyUI/models && \
    chmod +x /home/comfyuser/entrypoint.sh && \
    chmod +x /home/comfyuser/scripts/*.sh

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5m --retries=3 \
  CMD curl --fail http://localhost:8188/ || exit 1

# Entrypoint
ENTRYPOINT ["/home/comfyuser/entrypoint.sh"]