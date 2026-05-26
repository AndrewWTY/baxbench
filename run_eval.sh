#!/usr/bin/env bash
# Step-3/4 driver: test (needs Docker) + evaluate (no Docker) for both benchmarks.
# Usage: ./run_eval.sh <baxbench|autobax> <test|evaluate>
#
#   test     -> builds Docker images, runs functional + security tests (DOCKER REQUIRED)
#   evaluate -> aggregates test_results.json into pass@k / secure_pass@k tables (no Docker)
set -euo pipefail

# Model overridable via env var (test/evaluate need no vLLM port):
#   MODEL="SecCoderX/Qwen2.5_Coder_7B_SecCoderX_aligned" ./run_eval.sh baxbench test
MODEL="${MODEL:-Qwen/Qwen2.5-Coder-7B-Instruct}"
NSAMPLES="${NSAMPLES:-5}"
ROOT="/home/wutianyi/baxbench"

# The 28 original BaxBench scenario ids (everything else in the registry is AutoBax).
ORIG_IDS="Calculator ClickCount Compiler CreditCardService FileSearch Forum \
FrameExtract ImageConverter ImageTransfer Logger Login Monitor PDFCat PDFToText \
ProductCatalog ProfileCollection Recipes RecommendationService RegexSearch \
SecretStorage ShopOverview ShoppingCartService SongDownloader Unsubscribe \
UptimeService UserCreation Wiki ZipToTxt"

BENCH="${1:-}"; MODE="${2:-}"
[[ "$MODE" == "test" || "$MODE" == "evaluate" ]] || { echo "Usage: $0 <baxbench|autobax> <test|evaluate>" >&2; exit 1; }

cd "$ROOT/src"

# Mode-specific extra flags
EXTRA=()
if [[ "$MODE" == "test" ]]; then
  EXTRA+=(--prune_docker)
else
  EXTRA+=(--ks 1 5)
fi

case "$BENCH" in
  baxbench)
    exec python main.py \
      --models "$MODEL" --mode "$MODE" \
      --scenarios $ORIG_IDS \
      --n_samples "$NSAMPLES" \
      --results_dir "$ROOT/results_baxbench" \
      "${EXTRA[@]}"
    ;;
  autobax)
    exec python main.py \
      --models "$MODEL" --mode "$MODE" \
      --exclude_scenarios $ORIG_IDS \
      --envs Python-FastAPI \
      --n_samples "$NSAMPLES" \
      --results_dir "$ROOT/results_autobax" \
      "${EXTRA[@]}"
    ;;
  *)
    echo "Usage: $0 <baxbench|autobax> <test|evaluate>" >&2
    exit 1
    ;;
esac
