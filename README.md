# Nexis: A Production-Grade ComfyUI RunPod Template

Nexis is a lean, high-performance, and production-ready RunPod template for ComfyUI, optimized for modern NVIDIA GPUs like the RTX 4090 and 5090. Built on NVIDIA CUDA 12.8.1 base image with manually installed PyTorch, following proven patterns from the Phoenix project for optimal RunPod integration.

## Key Benefits

- **CUDA 12.8 Optimized**: Built on nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 with manual PyTorch installation for optimal performance.
- **Phoenix-Inspired API Integration**: Uses proven RunPod API patterns with GraphQL mutations and comprehensive error handling.
- **Production-Ready**: Secure, reproducible, and reliable for real-world workloads with debug folder preservation.
- **Easy to Maintain**: Simplified architecture with modular, single-purpose scripts inspired by Phoenix's successful approach.

## Quick Start: Deploying on RunPod

1.  **Use the Template**: Deploy this repository directly as a RunPod template.
2.  **Configure Environment Variables**: Set the required environment variables (see below).
3.  **Start the Pod**: Your ComfyUI and FileBrowser instances will be available at the specified ports.

## Template Deployment

### Using the Template Script

Deploy this template using the included script that follows Phoenix's proven RunPod API patterns:

```bash
# Set your RunPod API key
export RUNPOD_API_KEY="your_api_key_here"

# Run the template deployment script
./template.sh
```

The script will:
- Validate prerequisites (jq, curl, API key)
- Create/update the RunPod template via GraphQL API
- Include embedded documentation and working default values
- Apply security-focused Docker arguments

### Manual Deployment

You can also deploy manually via the RunPod web interface using the specifications in `template.sh`.

## Port Configuration

-   **ComfyUI**: `http://<your-pod-ip>:8188`
-   **FileBrowser**: `http://<your-pod-ip>:8080`

## Environment Variables

### Basic Configuration

| Variable              | Description                                       | Default |
| --------------------- | ------------------------------------------------- | ------- |
| `CIVITAI_CHECKPOINTS_TO_DOWNLOAD` | Comma-separated list of CivitAI model IDs for checkpoints. | `"1569593,919063,450105"` |
| `CIVITAI_LORAS_TO_DOWNLOAD` | Comma-separated list of CivitAI model IDs for LoRAs. | `"182404,445135,871108"` |
| `CIVITAI_VAES_TO_DOWNLOAD` | Comma-separated list of CivitAI model IDs for VAEs. | `"1674314"` |
| `HF_REPOS_TO_DOWNLOAD`   | Comma-separated list of HuggingFace repo IDs.     | `"black-forest-labs/FLUX.1-dev"` |
| `HUGGINGFACE_TOKEN`            | Your HuggingFace read token (use RunPod Secrets).   | `"{{ RUNPOD_SECRET_huggingface.co }}"` |
| `CIVITAI_TOKEN`              | Your CivitAI API token (use RunPod Secrets).        | `"{{ RUNPOD_SECRET_civitai.com }}"` |

### Advanced Configuration

| Variable              | Description                                       | Default      |
| --------------------- | ------------------------------------------------- | ------------ |
| `DEBUG_MODE`          | Enable detailed logging for downloads and organization. | `false` |
| `COMFYUI_FLAGS`       | Additional command-line flags for ComfyUI.        | `--bf16-unet` |
| `FB_USERNAME`         | Username for FileBrowser authentication.           | `admin` |
| `FB_PASSWORD`         | Password for FileBrowser (use RunPod Secrets).     | `"{{ RUNPOD_SECRET_FILEBROWSER_PASSWORD }}"` |

## Model Download Examples

### CivitAI Models

The system supports downloading CivitAI models using **model IDs** (not URLs). Model IDs are extracted from CivitAI URLs - for example, from `https://civitai.com/models/123456`, the model ID is `123456`.

#### Working Examples (Included as Defaults)

The template includes these proven working model IDs:

**Checkpoints:**
```
CIVITAI_CHECKPOINTS_TO_DOWNLOAD="1569593,919063,450105"
```

**LoRAs:**
```
CIVITAI_LORAS_TO_DOWNLOAD="182404,445135,871108"
```

**VAEs:**
```
CIVITAI_VAES_TO_DOWNLOAD="1674314"
```

**Note**: Use model IDs (numbers), not full URLs. The system automatically constructs the proper download URLs using the CivitAI API.

### HuggingFace Models

Set `HF_REPOS_TO_DOWNLOAD` to comma-separated repository IDs:
```
HF_REPOS_TO_DOWNLOAD="black-forest-labs/FLUX.1-dev,stabilityai/stable-diffusion-xl-base-1.0"
```

## RunPod Secrets Integration

For security, tokens are configured to use RunPod Secrets. Set up these secrets in your RunPod account:

- **`huggingface.co`**: Your HuggingFace read token
- **`civitai.com`**: Your CivitAI API token  
- **`FILEBROWSER_PASSWORD`**: Your desired FileBrowser password

The template automatically references these secrets using the `{{ RUNPOD_SECRET_name }}` syntax.

## Debug and Troubleshooting

### Debug Mode

Enable detailed logging by setting `DEBUG_MODE=true`. This provides:
- Detailed download progress and file sizes
- API request/response information
- File organization summaries
- Checksum verification details

### Failed Downloads Debug Folder

Files that fail to download or organize are preserved in `/workspace/debug/failed_downloads/` with the following structure:
- `checkpoints/` - Failed checkpoint downloads
- `loras/` - Failed LoRA downloads  
- `vae/` - Failed VAE downloads
- `huggingface/` - Failed HuggingFace model downloads

This allows you to:
- Inspect partial downloads
- Retry failed downloads manually
- Debug download issues without losing progress

**Note**: Failed downloads are never automatically deleted, ensuring no data loss during troubleshooting.

### Common Issues

- **Download Failures**: Check your tokens and ensure the model IDs are correct. Use `DEBUG_MODE=true` for detailed error information.
- **Model ID Issues**: Ensure CivitAI model IDs are numeric (e.g., `123456`) and HuggingFace repo IDs follow the `username/model-name` format.
- **Template Deployment**: Ensure you have `jq` and `curl` installed, and your `RUNPOD_API_KEY` is set correctly.

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
| **Architecture**              | Comprehensive with debugging features     | Simplified, production-focused              | Focus on core functionality while adopting Phoenix's proven patterns. |
| **API Integration**           | Advanced GraphQL with comprehensive error handling | Adopts Phoenix's proven API patterns       | Leverages Phoenix's successful RunPod integration approach.            |
| **Base Image**                | NVIDIA PyTorch image                      | NVIDIA CUDA 12.8.1 with manual PyTorch     | Optimal performance and compatibility with modern GPUs.                |
| **Debug Features**            | Extensive forensic cleanup and monitoring | Simplified debug folder preservation        | Essential debugging without complexity overhead.                       |
