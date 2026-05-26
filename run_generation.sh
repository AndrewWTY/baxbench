#!/usr/bin/env bash
# Step-2 generation driver for BaxBench + AutoBax on a local vLLM model.
# Usage: ./run_generation.sh <baxbench|autobax>
set -euo pipefail

# Model + vLLM port are overridable via env vars, so you can run multiple models:
#   MODEL="SecCoderX/Qwen2.5_Coder_7B_SecCoderX_aligned" PORT=8081 ./run_generation.sh baxbench
MODEL="${MODEL:-Qwen/Qwen2.5-Coder-7B-Instruct}"
PORT="${PORT:-8080}"
NSAMPLES="${NSAMPLES:-5}"
TEMP="${TEMP:-0.2}"
ROOT="/home/wutianyi/baxbench"

# The 28 original BaxBench scenario ids (everything else in the registry is AutoBax).
ORIG_IDS="Calculator ClickCount Compiler CreditCardService FileSearch Forum \
FrameExtract ImageConverter ImageTransfer Logger Login Monitor PDFCat PDFToText \
ProductCatalog ProfileCollection Recipes RecommendationService RegexSearch \
SecretStorage ShopOverview ShoppingCartService SongDownloader Unsubscribe \
UptimeService UserCreation Wiki ZipToTxt"

cd "$ROOT/src"

case "${1:-}" in
  baxbench)
    # Original 28 scenarios across ALL 14 environments.
    exec python main.py \
      --models "$MODEL" --mode generate \
      --vllm --vllm_port "$PORT" \
      --scenarios $ORIG_IDS \
      --n_samples "$NSAMPLES" --temperature "$TEMP" \
      --results_dir "$ROOT/results_baxbench"
    ;;
  autobax)
    # The 68 AutoBax scenarios (everything except the 28 originals), FastAPI only.
    exec python main.py \
      --models "$MODEL" --mode generate \
      --vllm --vllm_port "$PORT" \
      --exclude_scenarios $ORIG_IDS \
      --envs Python-FastAPI \
      --n_samples "$NSAMPLES" --temperature "$TEMP" \
      --results_dir "$ROOT/results_autobax"
    ;;
  *)
    echo "Usage: $0 <baxbench|autobax>" >&2
    exit 1
    ;;
esac
