# Nexis Changelog

## v1.0.0 - Initial Release

This is the first release of Nexis, a complete architectural rebuild of the Phoenix project. Nexis is a production-grade RunPod template for ComfyUI, designed for simplicity, performance, and maintainability.

### Key Differences from Phoenix

-   **Simplified Architecture**: Replaced the complex, monolithic entrypoint and scripts of Phoenix with a modular, single-purpose script design.
-   **Removed Features**: All non-essential features from Phoenix have been removed, including:
    -   Jupyter environment
    -   Extensive debugging and monitoring tools
    -   File integrity checks and forensic scripts
    -   Complex failure-tolerant mechanisms
-   **Production-Focused**: The entire project is designed for production deployment, with no debugging modes or testing scaffolding in the core logic.
-   **Performance Improvements**:
    -   Utilizes the latest NVIDIA PyTorch base image for optimal performance on modern GPUs (RTX 4090/5090).
    -   Optimized ComfyUI startup flags (`--bf16-unet`).
-   **Security Enhancements**:
    -   Runs as a non-root user (`comfyuser`).
    -   Minimal set of dependencies to reduce the attack surface.
    -   Pinned Python dependencies with SHA256 hashes for improved security and reproducibility.

### Future Roadmap

-   Integration with TensorRT for further performance optimization.
-   Enhanced health-checking and metrics for monitoring.
-   Support for additional model download sources.