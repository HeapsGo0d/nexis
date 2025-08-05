#!/usr/bin/env bash
set -euo pipefail

# ---- Environment ----
export HOME=/home/comfyuser
export WORKSPACE=/home/comfyuser/workspace

# Prefer the venv for all Python invocations
export VIRTUAL_ENV="${VIRTUAL_ENV:-/opt/venv}"
export PATH="${VIRTUAL_ENV}/bin:${PATH}"
PYTHON="${PYTHON:-${VIRTUAL_ENV}/bin/python}"

# ---- Logging helper ----
log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

# ---- Signal handling ----
SERVICE_MANAGER_PID=""

forward_signal() {
  local sig="$1"
  log "Signal $sig received."
  if [[ -n "${SERVICE_MANAGER_PID}" ]] && kill -0 "${SERVICE_MANAGER_PID}" 2>/dev/null; then
    log "Forwarding $sig to service manager (pid=${SERVICE_MANAGER_PID})..."
    kill -"$sig" "${SERVICE_MANAGER_PID}" || true
    wait "${SERVICE_MANAGER_PID}" || true
  else
    log "Service manager not running; nothing to forward."
  fi
  exit 0
}
trap 'forward_signal TERM' TERM
trap 'forward_signal INT'  INT

# ---- Startup sequence ----
log "Starting Nexis Entrypoint..."
log "Using Python: $(command -v python 2>/dev/null || echo 'not-in-PATH'), $($PYTHON -V 2>/dev/null || echo 'venv-python not found')"
log "WORKSPACE: ${WORKSPACE}"

# One-time runtime patch: mark utils/ as a package if missing
# This is required because the ComfyUI installation process may overwrite the
# directory and remove the __init__.py file needed for 'utils' to be a package.
UTILS_INIT="${WORKSPACE}/ComfyUI/utils/__init__.py"
if [ ! -f "$UTILS_INIT" ]; then
  log "Patching missing ${UTILS_INIT}"
  # Create an empty file, creating the directory if it doesn't exist
  mkdir -p "$(dirname "$UTILS_INIT")"
  touch "$UTILS_INIT"
fi


# (Optional) runtime dependency check – only when a CUDA driver is present
# Decide whether to skip CUDA probe
if ! nvidia-smi >/dev/null 2>&1; then
  export SKIP_CUDA_CHECK=1
fi

/home/comfyuser/scripts/validate_dependencies.sh \
  || log "Dependency validation reported issues (continuing anyway)"


# 1) System setup (fail hard if this fails)
log "Running system setup..."
if ! /home/comfyuser/scripts/system_setup.sh; then
  log "System setup failed. Exiting."
  exit 1
fi

# 2) Ensure debug directory (use WORKSPACE, not /workspace)
mkdir -p "${WORKSPACE}/debug/failed_downloads"

# 3) Model downloads (soft-fail)
log "Running download manager..."
if ! /home/comfyuser/scripts/download_manager.sh; then
  log "Download manager failed. Continuing without models."
fi

# 4) File organization (soft-fail)
log "Running file organizer..."
if ! /home/comfyuser/scripts/file_organizer.sh; then
  log "File organizer failed. Continuing with existing files."
fi

# 5) Launch services
log "Starting service manager..."
/home/comfyuser/scripts/service_manager.sh &
SERVICE_MANAGER_PID=$!
log "Service manager started (pid=${SERVICE_MANAGER_PID})."

# ---- Health monitoring ----
while true; do
  if ! kill -0 "${SERVICE_MANAGER_PID}" 2>/dev/null; then
    log "Service manager has exited. Shutting down."
    exit 1
  fi
  sleep 30
done
