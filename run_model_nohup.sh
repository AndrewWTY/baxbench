#!/usr/bin/env bash
# Reusable, disconnect-proof per-model generation pipeline.
#   run_model_nohup.sh <MODEL> <PORT> <GPU> [TEMP] [NSAMPLES] [GPU_UTIL]
# Starts a vLLM server for MODEL on GPU/PORT, waits, generates AutoBax (FastAPI)
# then BaxBench (14 envs), then shuts the server down to free the GPU.
# Results land in results_autobax/ and results_baxbench/ under a temp<T> subdir,
# so multiple temperatures coexist without overwriting.
set -uo pipefail

ROOT=/home/wutianyi/baxbench
LOGDIR=$ROOT/logs
mkdir -p "$LOGDIR"
source /home/wutianyi/anaconda3/etc/profile.d/conda.sh
conda activate baxbench

MODEL="${1:?need MODEL}"; PORT="${2:?need PORT}"; GPU="${3:?need GPU}"
TEMP="${4:-0}"; NSAMPLES="${5:-1}"; UTIL="${6:-0.9}"
TAG=$(echo "$MODEL" | tr '/' '-')
SLOG="$LOGDIR/${TAG}_server_t${TEMP}.log"

echo "[$(date '+%F %T')] $MODEL on GPU $GPU / port $PORT (temp=$TEMP n=$NSAMPLES util=$UTIL)"
CUDA_VISIBLE_DEVICES=$GPU nohup python -m vllm.entrypoints.openai.api_server \
  --model "$MODEL" --served-model-name "$MODEL" \
  --host 0.0.0.0 --port "$PORT" --dtype auto --max-model-len 32768 \
  --gpu-memory-utilization "$UTIL" --trust-remote-code \
  > "$SLOG" 2>&1 &
SERVER_PID=$!
echo "[$(date '+%F %T')] server pid=$SERVER_PID (log: $SLOG)"

echo "[$(date '+%F %T')] waiting for readiness (max ~12 min)..."
ready=0
for i in $(seq 1 144); do
  if [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:$PORT/v1/models 2>/dev/null)" = "200" ]; then ready=1; break; fi
  if ! kill -0 $SERVER_PID 2>/dev/null; then echo "[$(date '+%F %T')] ERROR: server died on startup (see $SLOG)"; exit 1; fi
  sleep 5
done
[ "$ready" = 1 ] || { echo "[$(date '+%F %T')] ERROR: server not ready in time"; kill $SERVER_PID 2>/dev/null; exit 1; }
echo "[$(date '+%F %T')] server READY"

echo "[$(date '+%F %T')] === AutoBax (temp=$TEMP n=$NSAMPLES) ==="
MODEL="$MODEL" PORT=$PORT TEMP=$TEMP NSAMPLES=$NSAMPLES bash "$ROOT/run_generation.sh" autobax \
  > "$LOGDIR/${TAG}_autobax_t${TEMP}.log" 2>&1
echo "[$(date '+%F %T')] AutoBax done (exit $?)"

echo "[$(date '+%F %T')] === BaxBench (temp=$TEMP n=$NSAMPLES) ==="
MODEL="$MODEL" PORT=$PORT TEMP=$TEMP NSAMPLES=$NSAMPLES bash "$ROOT/run_generation.sh" baxbench \
  > "$LOGDIR/${TAG}_baxbench_t${TEMP}.log" 2>&1
echo "[$(date '+%F %T')] BaxBench done (exit $?)"

echo "[$(date '+%F %T')] shutting down server pid=$SERVER_PID (free GPU $GPU)"
kill $SERVER_PID 2>/dev/null
echo "[$(date '+%F %T')] === DONE $MODEL (temp=$TEMP) ==="
