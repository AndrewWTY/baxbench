#!/usr/bin/env bash
#
# deploy_model.sh - One-click download & deploy a HuggingFace model with vLLM
# for use with BaxBench evaluation pipeline.
#
# Usage:
#   ./deploy_model.sh <model_id> [--gpu <gpu_id>] [--port <port>] [--dtype <dtype>] [--max-model-len <len>]
#
# Examples:
#   ./deploy_model.sh Qwen/Qwen2.5-Coder-7B-Instruct --gpu 5 --port 8000
#   ./deploy_model.sh SecCoderX/Qwen2.5_Coder_7B_SecCoderX_aligned --gpu 6 --port 8001
#
#   # Then run BaxBench generation:
#   cd src && python3 main.py \
#     --models "Qwen/Qwen2.5-Coder-7B-Instruct" \
#     --mode generate --vllm --vllm_port 8000 \
#     --envs Python-Flask --scenarios login --n_samples 1
#
set -euo pipefail

# ======================== Defaults ========================
GPU_ID=5
PORT=8000
DTYPE="auto"
MAX_MODEL_LEN=32768
TENSOR_PARALLEL=1
CACHE_DIR="${HF_HOME:-$HOME/.cache/huggingface}"
TRUST_REMOTE_CODE=true

# ======================== Parse Args ========================
usage() {
    cat <<'USAGE'
Usage: deploy_model.sh <model_id> [OPTIONS]

Arguments:
  model_id                 HuggingFace model ID (e.g. Qwen/Qwen2.5-Coder-7B-Instruct)

Options:
  --gpu <id>               GPU device ID (default: 5)
  --port <port>            vLLM server port (default: 8000)
  --dtype <type>           Data type: auto, half, float16, bfloat16 (default: auto)
  --max-model-len <len>    Max sequence length (default: 32768)
  --tensor-parallel <n>    Number of GPUs for tensor parallelism (default: 1)
  --cache-dir <path>       HuggingFace cache directory (default: ~/.cache/huggingface)
  --download-only          Only download the model, don't start the server
  --help                   Show this help message

After deployment, use with BaxBench:
  cd src && python3 main.py \\
    --models "<model_id>" --mode generate \\
    --vllm --vllm_port <port> \\
    --envs Python-Flask --scenarios login --n_samples 1
USAGE
    exit 0
}

if [[ $# -lt 1 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    usage
fi

MODEL_ID="$1"
shift

DOWNLOAD_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --gpu)        GPU_ID="$2";          shift 2 ;;
        --port)       PORT="$2";            shift 2 ;;
        --dtype)      DTYPE="$2";           shift 2 ;;
        --max-model-len) MAX_MODEL_LEN="$2"; shift 2 ;;
        --tensor-parallel) TENSOR_PARALLEL="$2"; shift 2 ;;
        --cache-dir)  CACHE_DIR="$2";       shift 2 ;;
        --download-only) DOWNLOAD_ONLY=true; shift ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# ======================== Helpers ========================
log() { echo "[$(date '+%H:%M:%S')] $*"; }
err() { echo "[ERROR] $*" >&2; exit 1; }

check_gpu() {
    if ! command -v nvidia-smi &>/dev/null; then
        err "nvidia-smi not found. Is NVIDIA driver installed?"
    fi
    local gpu_count
    gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
    if (( GPU_ID >= gpu_count )); then
        err "GPU $GPU_ID not found. Available GPUs: 0-$((gpu_count - 1))"
    fi
    local mem_used mem_total
    mem_used=$(nvidia-smi --id="$GPU_ID" --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
    mem_total=$(nvidia-smi --id="$GPU_ID" --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
    local mem_free=$(( mem_total - mem_used ))
    log "GPU $GPU_ID: ${mem_used}MiB / ${mem_total}MiB used (${mem_free}MiB free)"
    if (( mem_free < 10000 )); then
        log "WARNING: GPU $GPU_ID has less than 10GB free. The model may not fit."
        read -p "Continue anyway? [y/N] " -r
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    fi
}

check_port() {
    if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        err "Port $PORT is already in use. Pick another with --port"
    fi
}

# ======================== Step 1: Preflight ========================
log "========================================="
log "BaxBench Model Deployer"
log "========================================="
log "Model:          $MODEL_ID"
log "GPU:            $GPU_ID"
log "Port:           $PORT"
log "Dtype:          $DTYPE"
log "Max model len:  $MAX_MODEL_LEN"
log "Tensor parallel:$TENSOR_PARALLEL"
log "Cache dir:      $CACHE_DIR"
log "========================================="

check_gpu

# ======================== Step 2: Download Model ========================
log "Downloading model '$MODEL_ID' (if not already cached)..."

python3 - <<PYEOF
from huggingface_hub import snapshot_download
import os

cache_dir = os.environ.get("HF_HOME", os.path.expanduser("~/.cache/huggingface"))
print(f"Downloading to cache: {cache_dir}")

path = snapshot_download(
    repo_id="${MODEL_ID}",
    cache_dir="${CACHE_DIR}",
    resume_download=True,
)
print(f"Model downloaded/cached at: {path}")
PYEOF

log "Model download complete."

if [[ "$DOWNLOAD_ONLY" == "true" ]]; then
    log "Download-only mode. Exiting."
    exit 0
fi

# ======================== Step 3: Launch vLLM Server ========================
check_port

log "Starting vLLM OpenAI-compatible server on port $PORT (GPU $GPU_ID)..."
log "Model will be served as: $MODEL_ID"
log ""
log "To use with BaxBench:"
log "  cd /home/wutianyi/baxbench/src && python3 main.py \\"
log "    --models \"$MODEL_ID\" --mode generate \\"
log "    --vllm --vllm_port $PORT \\"
log "    --envs Python-Flask --scenarios login --n_samples 1"
log ""
log "Press Ctrl+C to stop the server."
log "========================================="

# Build GPU visibility string for tensor parallel
if (( TENSOR_PARALLEL == 1 )); then
    export CUDA_VISIBLE_DEVICES="$GPU_ID"
else
    # For multi-GPU: use consecutive GPUs starting from GPU_ID
    gpus=""
    for (( i=0; i<TENSOR_PARALLEL; i++ )); do
        [[ -n "$gpus" ]] && gpus+=","
        gpus+="$((GPU_ID + i))"
    done
    export CUDA_VISIBLE_DEVICES="$gpus"
fi

EXTRA_ARGS=()
if [[ "$TRUST_REMOTE_CODE" == "true" ]]; then
    EXTRA_ARGS+=(--trust-remote-code)
fi

# Launch vLLM
exec python3 -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_ID" \
    --served-model-name "$MODEL_ID" \
    --host 0.0.0.0 \
    --port "$PORT" \
    --dtype "$DTYPE" \
    --max-model-len "$MAX_MODEL_LEN" \
    --tensor-parallel-size "$TENSOR_PARALLEL" \
    --download-dir "$CACHE_DIR" \
    "${EXTRA_ARGS[@]}"
