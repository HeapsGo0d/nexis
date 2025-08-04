# Nexis: A Production-Grade ComfyUI RunPod Template

Nexis is a lean, high-performance, and production-ready RunPod template for ComfyUI, optimized for modern NVIDIA GPUs like the RTX 4090 and 5090. It is a complete rebuild of the Phoenix project, focusing on simplicity, stability, and maintainability.

## Key Benefits

- **Minimalist and Focused**: No debugging tools, testing modes, or non-essential features. Just ComfyUI and FileBrowser.
- **High Performance**: Built on the official NVIDIA PyTorch image for optimal CUDA 12.x performance.
- **Production-Ready**: Secure, reproducible, and reliable for real-world workloads.
- **Easy to Maintain**: Simplified architecture with modular, single-purpose scripts.

## Quick Start: Deploying on RunPod

1.  **Use the Template**: Deploy this repository directly as a RunPod template.
2.  **Configure Environment Variables**: Set the required environment variables (see below).
3.  **Start the Pod**: Your ComfyUI and FileBrowser instances will be available at the specified ports.

## Port Configuration

-   **ComfyUI**: `http://<your-pod-ip>:8188`
-   **FileBrowser**: `http://<your-pod-ip>:8080`

## Environment Variables

### Basic Configuration

| Variable              | Description                                       | Default |
| --------------------- | ------------------------------------------------- | ------- |
| `CIVITAI_CHECKPOINTS_TO_DOWNLOAD` | Comma-separated list of Civitai model URLs for checkpoints. | `""`      |
| `CIVITAI_LORAS_TO_DOWNLOAD` | Comma-separated list of Civitai model URLs for LoRAs. | `""`      |
| `CIVITAI_VAES_TO_DOWNLOAD` | Comma-separated list of Civitai model URLs for VAEs. | `""`      |
| `HF_REPOS_TO_DOWNLOAD`   | Comma-separated list of HuggingFace repo IDs.     | `""`      |
| `HUGGINGFACE_TOKEN`            | Your HuggingFace read token for private models.   | `""`      |

### Advanced Configuration

| Variable              | Description                                       | Default      |
| --------------------- | ------------------------------------------------- | ------------ |
| `COMFYUI_FLAGS`       | Additional command-line flags for ComfyUI.        | `--bf16-unet` |
| `FILEBROWSER_CONFIG`  | Path to a custom FileBrowser configuration file.  | `""`           |
| `FB_USERNAME`         | Username for FileBrowser authentication.           | `""`           |
| `FB_PASSWORD`         | Password for FileBrowser authentication.           | `""`           |

## Model Download Examples

### Civitai Models

The system supports downloading different types of Civitai models into their respective directories. All Civitai variables expect **full download URLs**, not model IDs.

#### Checkpoints (Main Models)
Set `CIVITAI_CHECKPOINTS_TO_DOWNLOAD` to a comma-separated list of Civitai download URLs:
```
CIVITAI_CHECKPOINTS_TO_DOWNLOAD="https://civitai.com/api/download/models/12345,https://civitai.com/api/download/models/67890"
```

#### LoRAs
Set `CIVITAI_LORAS_TO_DOWNLOAD` to a comma-separated list of Civitai download URLs:
```
CIVITAI_LORAS_TO_DOWNLOAD="https://civitai.com/api/download/models/11111,https://civitai.com/api/download/models/22222"
```

#### VAEs
Set `CIVITAI_VAES_TO_DOWNLOAD` to a comma-separated list of Civitai download URLs:
```
CIVITAI_VAES_TO_DOWNLOAD="https://civitai.com/api/download/models/33333,https://civitai.com/api/download/models/44444"
```

**Note**: Civitai URLs must be the full download URLs (e.g., `https://civitai.com/api/download/models/XXXXX`), not model IDs or page URLs.

### HuggingFace Models

Set `HF_REPOS_TO_DOWNLOAD` to a comma-separated list of HuggingFace repository IDs. The script will use `git-lfs` to clone them.

```
HF_REPOS_TO_DOWNLOAD="stabilityai/stable-diffusion-xl-base-1.0,stabilityai/sdxl-vae"
```

**Note**: HuggingFace variables expect repository IDs (e.g., `username/model-name`), not full URLs.

## FileBrowser Authentication

FileBrowser supports basic authentication using username and password. To enable authentication:

1.  Set the `FB_USERNAME` environment variable to your desired username.
2.  Set the `FB_PASSWORD` environment variable to your desired password.

Example:
```
FB_USERNAME=admin
FB_PASSWORD=your_secure_password
```

**Security Notes**:
-   If either `FB_USERNAME` or `FB_PASSWORD` is not set, FileBrowser will run without authentication.
-   Use strong passwords and consider using RunPod's environment variable secrets for managing these credentials.
-   Authentication is applied to all FileBrowser access on port 8080.

## Troubleshooting

-   **502 Bad Gateway**: ComfyUI or FileBrowser may be starting up. Wait a few minutes and refresh.
-   **Download Failures**: Check your `HUGGINGFACE_TOKEN` and ensure the model URLs/IDs are correct.
-   **GPU Errors**: Ensure your pod is configured with a compatible NVIDIA GPU (RTX 4090/5090 series).

## Performance Optimization (RTX 5090)

The default `COMFYUI_FLAGS` are set to `--bf16-unet` for improved performance on modern GPUs. You can further optimize by:

-   Using TensorRT-optimized models.
-   Adjusting batch sizes in your workflows.
-   Experimenting with other ComfyUI performance flags.

## Security Considerations

-   **Non-Root User**: The container runs as a non-root user (`comfyuser`) for improved security.
-   **Minimal Dependencies**: The Docker image includes only essential system packages to reduce the attack surface.
-   **Secrets**: Use RunPod's environment variable secrets for managing `HUGGINGFACE_TOKEN`.

## Comparison with Phoenix

Nexis is a deliberate simplification of the Phoenix project. Here's what changed and why:

| Feature                       | Phoenix                                   | Nexis                                       | Rationale                                                              |
| ----------------------------- | ----------------------------------------- | ------------------------------------------- | ---------------------------------------------------------------------- |
| **Architecture**              | Monolithic entrypoint, complex scripts    | Modular, single-purpose scripts             | Improved maintainability and clarity.                                  |
| **Debugging**                 | Extensive debugging, monitoring, forensics | Removed                                     | Focus on production stability; debugging should be done in development. |
| **Entrypoint**                | 400+ lines, complex logic                 | <100 lines, simple orchestration            | Reduced complexity and improved reliability.                           |
| **Dependencies**              | Loosely pinned                            | Pinned with hashes (`requirements.txt`)     | Enhanced security and reproducibility.                                 |
| **Base Image**                | Older PyTorch image                       | Latest NVIDIA PyTorch image for CUDA 12.x   | Optimal performance and compatibility with modern GPUs.                |
