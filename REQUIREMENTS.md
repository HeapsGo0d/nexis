# Nexis Project Requirements

## 1. Project Goals

The primary goal of Nexis is to create a production-grade, high-performance, and maintainable RunPod template for ComfyUI. It is designed for stability and efficiency, targeting modern NVIDIA GPUs (RTX 4090/5090 series) and CUDA 12.x.

## 2. Scope

### 2.1. In-Scope Features

- **ComfyUI**: The core component for image generation.
- **FileBrowser**: A web-based file manager for easy data management.
- **Model Downloading**: Efficient model downloading from HuggingFace and Civitai.
- **Production-Optimized Docker Image**: A minimal, secure, and performant Docker image.
- **RunPod Template**: A ready-to-deploy RunPod template script.

### 2.2. Out-of-Scope Features (Non-Goals)

- **Jupyter Environment**: No built-in Jupyter or notebook support.
- **Complex Debugging Infrastructure**: All debugging modes, file monitoring, and forensic tools from Phoenix are removed.
- **Testing Scaffolding**: No built-in testing modes or frameworks in the entrypoint.
- **Failure-Tolerant Mechanisms**: Complex auto-recovery and failure tolerance are replaced with simple, reliable service management.

## 3. Technical Specifications

- **Base Image**: `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04` (or newer compatible version).
- **GPU Compatibility**: NVIDIA RTX 4090 / RTX 5090.
- **CUDA Version**: 12.x.
- **Python Version**: 3.11.
- **Dependency Management**: Pinned versions via `requirements.txt` with SHA256 hashes.

## 4. RunPod Deployment

- **Ports**: 
  - `8188`: ComfyUI
  - `8080`: FileBrowser
- **Storage**: Configurable volume mounts for models and data.
- **Environment Variables**: A clearly defined set of environment variables for configuration (see `README.md`).

## 5. Performance Targets

- **Fast Startup**: Minimize container initialization time.
- **Low Overhead**: Minimal resource consumption from non-essential services.
- **Optimized Inference**: Leverage GPU-specific optimizations for ComfyUI (e.g., `--bf16-unet`).

## 6. Architecture

The architecture is based on a collection of modular, single-purpose scripts orchestrated by a lean entrypoint. This design prioritizes clarity, maintainability, and reliability over the complex, feature-rich approach of the Phoenix project.