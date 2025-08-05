#!/usr/bin/env bash
set -euo pipefail

# ---------- Config (overridable by env) ----------
PYTHON="${PYTHON:-/opt/venv/bin/python}"

COMFYUI_DIR="${COMFYUI_DIR:-/home/comfyuser/workspace/ComfyUI}"
COMFYUI_HOST="${COMFYUI_HOST:-0.0.0.0}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
# Space-separated flags are allowed; will be split safely below
COMFYUI_FLAGS="${COMFYUI_FLAGS:---disable-auto-launch --disable-metadata-preview}"

FILEBROWSER_BIN="${FILEBROWSER_BIN:-/home/comfyuser/filebrowser}"
FILEBROWSER_ROOT="${FILEBROWSER_ROOT:-/home/comfyuser/workspace}"
FILEBROWSER_HOST="${FILEBROWSER_HOST:-0.0.0.0}"
FILEBROWSER_PORT="${FILEBROWSER_PORT:-8080}"

COMFYUI_URL="http://127.0.0.1:${COMFYUI_PORT}"
FILEBROWSER_URL="http://127.0.0.1:${FILEBROWSER_PORT}"

HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-30}"   # seconds between liveness checks
HEALTH_RETRIES_START="${HEALTH_RETRIES_START:-30}"     # seconds to wait for initial readiness

PID_COMFYUI=""
PID_FILEBROWSER=""
SHUTDOWN_REQUESTED=false

# ---------- Helpers ----------
log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { log "Missing command: $1"; exit 127; }; }
health_check() { curl -fsS -m 2 "$1" >/dev/null; }

wait_healthy() {
  local url=$1 name=$2 retries=${3:-$HEALTH_RETRIES_START}
  for ((i=1; i<=retries; i++)); do
    if health_check "$url"; then return 0; fi
    sleep 1
  done
  log "$name did not become healthy at $url in ${retries}s"
  return 1
}

start_service() {
  local name=$1; shift
  local url=$1; shift
  log "Starting $name..."
  "$@" &
  local pid=$!
  log "$name pid=${pid}; waiting for readiness..."
  if wait_healthy "$url" "$name"; then
    log "$name ready at $url"
    echo "$pid"
    return 0
  else
    kill -9 "$pid" 2>/dev/null || true
    return 1
  fi
}

# ---------- Signals ----------
handle_signal() {
  local sig="${1:-TERM}"
  log "Received $sig; stopping services..."
  SHUTDOWN_REQUESTED=true
  [[ -n "$PID_COMFYUI" ]]    && kill -TERM "$PID_COMFYUI" 2>/dev/null || true
  [[ -n "$PID_FILEBROWSER" ]]&& kill -TERM "$PID_FILEBROWSER" 2>/dev/null || true
}
trap 'handle_signal TERM' TERM
trap 'handle_signal INT'  INT

# ---------- Pre-flight ----------
require_cmd curl
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  log "Python not found at $PYTHON"; exit 127
fi
if [[ ! -f "$COMFYUI_DIR/main.py" ]]; then
  log "ComfyUI main.py not found at: $COMFYUI_DIR/main.py"; exit 1
fi

# ---------- Start ComfyUI ----------
# Split COMFYUI_FLAGS on spaces into an array safely (SC2206 ok here)
# shellcheck disable=SC2206
EXTRA_FLAGS=( $COMFYUI_FLAGS )
COMFY_CMD=( "$PYTHON" "$COMFYUI_DIR/main.py" --listen "$COMFYUI_HOST" --port "$COMFYUI_PORT" )
COMFY_CMD+=( "${EXTRA_FLAGS[@]}" )
PID_COMFYUI=$(start_service "ComfyUI" "$COMFYUI_URL" "${COMFY_CMD[@]}") || exit 1

# ---------- Start FileBrowser (optional) ----------
if [[ -x "$FILEBROWSER_BIN" ]]; then
  FB_CMD=( "$FILEBROWSER_BIN" -r "$FILEBROWSER_ROOT" -a "$FILEBROWSER_HOST" -p "$FILEBROWSER_PORT" )
  if [[ -n "${FB_USERNAME:-}" && -n "${FB_PASSWORD:-}" ]]; then
    FB_CMD+=( --username "$FB_USERNAME" --password "$FB_PASSWORD" )
  fi
  PID_FILEBROWSER=$(start_service "FileBrowser" "$FILEBROWSER_URL" "${FB_CMD[@]}") || {
    log "FileB
