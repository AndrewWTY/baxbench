#!/usr/bin/env bash
# Disconnect-proof multi-temperature generation for one model.
#   run_model_temps_nohup.sh <MODEL> <PORT> <GPU> <NSAMPLES> <GPU_UTIL> <TEMP1> [TEMP2 ...]
# Starts the vLLM server ONCE, then for each temperature generates AutoBax
# (FastAPI) + BaxBench (14 envs), then shuts the server down.
# Results land in results_*/<model>/<scenario>/<env>/temp<T>-... (temps coexist).
set -uo pipefail

ROOT=/home/wutianyi/baxbench
LOGDIR=$ROOT/logs
mkdir -p "$LOGDIR"
source /home/wutianyi/anaconda3/etc/profile.d/conda.sh
conda activate baxbench

MODEL="${1:?MODEL}"; PORT="${2:?PORT}"; GPU="${3:?GPU}"; NSAMPLES="${4:?NSAMPLES}"; UTIL="${5:?UTIL}"
shift 5
TEMPS=("$@")
[ ${#TEMPS[@]} -gt 0 ] || { echo "need at least one temperature"; exit 1; }
TAG=$(echo "$MODEL" | tr '/' '-')
SLOG="$LOGDIR/${TAG}_server_multi.log"

echo "[$(date '+%F %T')] $MODEL on GPU $GPU / port $PORT (n=$NSAMPLES util=$UTIL temps=${TEMPS[*]})"
CUDA_VISIBLE_DEVICES=$GPU nohup python -m vllm.entrypoints.openai.api_server \
  --model "$MODEL" --served-model-name "$MODEL" \
  --host 0.0.0.0 --port "$PORT" --dtype auto --max-model-len 32768 \
  --gpu-memory-utilization "$UTIL" --trust-remote-code \
  > "$SLOG" 2>&1 &
SERVER_PID=$!
echo "[$(date '+%F %T')] server pid=$SERVER_PID (log: $SLOG)"

ready=0
for i in $(seq 1 144); do
  if [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:$PORT/v1/models 2>/dev/null)" = "200" ]; then ready=1; break; fi
  kill -0 $SERVER_PID 2>/dev/null || { echo "[$(date '+%F %T')] ERROR: server died on startup (see $SLOG)"; exit 1; }
  sleep 5
done
[ "$ready" = 1 ] || { echo "[$(date '+%F %T')] ERROR: server not ready"; kill $SERVER_PID 2>/dev/null; exit 1; }
echo "[$(date '+%F %T')] server READY"

for T in "${TEMPS[@]}"; do
  echo "[$(date '+%F %T')] ===== temp=$T : AutoBax ====="
  MODEL="$MODEL" PORT=$PORT TEMP=$T NSAMPLES=$NSAMPLES bash "$ROOT/run_generation.sh" autobax \
    > "$LOGDIR/${TAG}_autobax_t${T}.log" 2>&1
  echo "[$(date '+%F %T')] temp=$T AutoBax done (exit $?)"

  echo "[$(date '+%F %T')] ===== temp=$T : BaxBench ====="
  MODEL="$MODEL" PORT=$PORT TEMP=$T NSAMPLES=$NSAMPLES bash "$ROOT/run_generation.sh" baxbench \
    > "$LOGDIR/${TAG}_baxbench_t${T}.log" 2>&1
  echo "[$(date '+%F %T')] temp=$T BaxBench done (exit $?)"
done

echo "[$(date '+%F %T')] shutting down server pid=$SERVER_PID (free GPU $GPU)"
kill $SERVER_PID 2>/dev/null
echo "[$(date '+%F %T')] ===== ALL DONE $MODEL temps=${TEMPS[*]} ====="
