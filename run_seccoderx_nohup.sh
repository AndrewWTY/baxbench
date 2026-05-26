#!/usr/bin/env bash
# Fully self-contained, disconnect-proof SecCoderX pipeline:
#   1) start its own vLLM server on GPU 6 / port 8082
#   2) wait until the server is ready
#   3) generate AutoBax (FastAPI) then BaxBench (14 envs)
#   4) shut the server down to free the GPU
# Launch detached with:
#   nohup bash run_seccoderx_nohup.sh > logs/seccoderx_orchestrator.log 2>&1 & disown
set -uo pipefail

ROOT=/home/wutianyi/baxbench
LOGDIR=$ROOT/logs
mkdir -p "$LOGDIR"

source /home/wutianyi/anaconda3/etc/profile.d/conda.sh
conda activate baxbench

MODEL="SecCoderX/Qwen2.5_Coder_7B_SecCoderX_aligned"
PORT=8082
GPU=6

echo "[$(date '+%F %T')] waiting for GPU $GPU to free from the stopped server..."
sleep 8

echo "[$(date '+%F %T')] starting SecCoderX vLLM server on GPU $GPU / port $PORT"
CUDA_VISIBLE_DEVICES=$GPU nohup python -m vllm.entrypoints.openai.api_server \
  --model "$MODEL" --served-model-name "$MODEL" \
  --host 0.0.0.0 --port $PORT --dtype auto --max-model-len 32768 --trust-remote-code \
  > "$LOGDIR/seccoderx_server.log" 2>&1 &
SERVER_PID=$!
echo "[$(date '+%F %T')] server pid=$SERVER_PID (log: $LOGDIR/seccoderx_server.log)"

echo "[$(date '+%F %T')] waiting for server readiness (max ~12 min)..."
ready=0
for i in $(seq 1 144); do
  if [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:$PORT/v1/models 2>/dev/null)" = "200" ]; then
    ready=1; break
  fi
  if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo "[$(date '+%F %T')] ERROR: server process died during startup. See $LOGDIR/seccoderx_server.log"; exit 1
  fi
  sleep 5
done
[ "$ready" = "1" ] || { echo "[$(date '+%F %T')] ERROR: server not ready in time"; kill $SERVER_PID 2>/dev/null; exit 1; }
echo "[$(date '+%F %T')] server READY"

echo "[$(date '+%F %T')] === generating AutoBax (FastAPI) ==="
MODEL="$MODEL" PORT=$PORT bash "$ROOT/run_generation.sh" autobax > "$LOGDIR/seccoderx_autobax.log" 2>&1
echo "[$(date '+%F %T')] AutoBax done (exit $?)"

echo "[$(date '+%F %T')] === generating BaxBench (14 envs) ==="
MODEL="$MODEL" PORT=$PORT bash "$ROOT/run_generation.sh" baxbench > "$LOGDIR/seccoderx_baxbench.log" 2>&1
echo "[$(date '+%F %T')] BaxBench done (exit $?)"

echo "[$(date '+%F %T')] shutting down SecCoderX server (pid=$SERVER_PID) to free GPU $GPU"
kill $SERVER_PID 2>/dev/null
echo "[$(date '+%F %T')] === ALL SECCODERX GENERATION COMPLETE ==="
