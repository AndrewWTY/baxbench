#!/usr/bin/env bash
###############################################################################
# run_after_generation.sh
#
# One-click STEP 3 (test) + STEP 4 (evaluate) for BaxBench + AutoBax results.
# Run this on a Docker-capable machine after copying in the generated results.
#
# Typical use by a collaborator:
#   git clone <this-baxbench-repo> && cd baxbench
#   unzip results.zip                 # -> results_baxbench/ and results_autobax/
#   # set up the BaxBench python env (see README), then:
#   ./run_after_generation.sh
#
# What it does:
#   * Preflight: checks Docker is reachable, python deps import, scenarios
#     registered (must include the 68 copied AutoBax scenarios).
#   * Auto-detects which models are present in the results dirs.
#   * BaxBench : 28 original scenarios across ALL 14 environments.
#   * AutoBax  : 68 generated scenarios, Python-FastAPI only.
#   * test  -> builds Docker images, runs functional + security tests.
#   * evaluate -> prints pass@k / secure_pass@k tables (also saved to files).
#
# Everything is configurable; see --help.
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------- defaults (all overridable) ----------------
BAXBENCH_DIR="$SCRIPT_DIR/results_baxbench"
AUTOBAX_DIR="$SCRIPT_DIR/results_autobax"
N_SAMPLES=5
TEMPERATURE="0.2"           # must match generation (use 0 for the greedy/temp=0 run)
PHASE="all"                 # test | evaluate | all
PYTHON_BIN="python"
KS="1 5"
MAX_CONCURRENT=4            # cap concurrent test containers (resource safety)
LIMIT=""                    # if set, restrict each benchmark to first N task instances (quick test runs)
MODELS_OVERRIDE=""          # space-separated; empty => auto-detect
DO_BAXBENCH=1
DO_AUTOBAX=1
PRUNE=1
FORCE=0

# The 28 original BaxBench scenario ids (everything else in the registry is AutoBax).
ORIG_IDS="Calculator ClickCount Compiler CreditCardService FileSearch Forum \
FrameExtract ImageConverter ImageTransfer Logger Login Monitor PDFCat PDFToText \
ProductCatalog ProfileCollection Recipes RecommendationService RegexSearch \
SecretStorage ShopOverview ShoppingCartService SongDownloader Unsubscribe \
UptimeService UserCreation Wiki ZipToTxt"

# Candidate models (used for auto-detect; add more here if needed).
CANDIDATE_MODELS=(
  "Qwen/Qwen2.5-Coder-7B-Instruct"
  "SecCoderX/Qwen2.5_Coder_7B_SecCoderX_aligned"
)

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

  --baxbench-dir DIR     Results dir for BaxBench (default: ./results_baxbench)
  --autobax-dir DIR      Results dir for AutoBax  (default: ./results_autobax)
  --n-samples N          Samples per task, must match generation (default: 5)
  --temperature T        Sampling temperature, must match generation (default: 0.2; use 0 for the greedy run)
  --phase P              test | evaluate | all (default: all)
  --models "A B"         Model names (orig form, slashes). Default: auto-detect.
  --ks "1 5"             k values for pass@k (default: "1 5")
  --max-concurrent N     Max concurrent test containers (default: 4)
  --limit N              Restrict each benchmark to first N task instances (quick test run)
  --force                Force re-test of already-tested samples
  --python BIN           Python executable (default: python)
  --skip-baxbench        Do not process the BaxBench results
  --skip-autobax         Do not process the AutoBax results
  --no-prune             Do not prune docker containers after testing
  -h, --help             Show this help

Examples:
  ./run_after_generation.sh                          # test + evaluate, both benches, autodetect models
  ./run_after_generation.sh --phase evaluate         # only re-print score tables (no Docker needed)
  ./run_after_generation.sh --baxbench-dir /data/rb --autobax-dir /data/ra
EOF
  exit "${1:-0}"
}

# ---------------- arg parsing ----------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --baxbench-dir) BAXBENCH_DIR="$2"; shift 2;;
    --autobax-dir)  AUTOBAX_DIR="$2";  shift 2;;
    --n-samples)    N_SAMPLES="$2";    shift 2;;
    --temperature)  TEMPERATURE="$2";  shift 2;;
    --phase)        PHASE="$2";        shift 2;;
    --models)       MODELS_OVERRIDE="$2"; shift 2;;
    --ks)           KS="$2";           shift 2;;
    --max-concurrent) MAX_CONCURRENT="$2"; shift 2;;
    --limit)        LIMIT="$2";         shift 2;;
    --force)        FORCE=1;           shift;;
    --python)       PYTHON_BIN="$2";   shift 2;;
    --skip-baxbench) DO_BAXBENCH=0;    shift;;
    --skip-autobax)  DO_AUTOBAX=0;     shift;;
    --no-prune)     PRUNE=0;           shift;;
    -h|--help)      usage 0;;
    *) echo "Unknown option: $1" >&2; usage 1;;
  esac
done

# resolve to absolute paths (if they exist)
[[ -d "$BAXBENCH_DIR" ]] && BAXBENCH_DIR="$(cd "$BAXBENCH_DIR" && pwd)"
[[ -d "$AUTOBAX_DIR"  ]] && AUTOBAX_DIR="$(cd "$AUTOBAX_DIR"  && pwd)"

log()  { echo -e "\n\033[1;36m[$(date '+%T')] $*\033[0m"; }
warn() { echo -e "\033[1;33m[warn] $*\033[0m" >&2; }
die()  { echo -e "\033[1;31m[error] $*\033[0m" >&2; exit 1; }

# ---------------- preflight ----------------
log "Preflight checks"
cd "$SCRIPT_DIR/src" || die "Cannot find src/ next to this script ($SCRIPT_DIR/src)"

command -v "$PYTHON_BIN" >/dev/null 2>&1 || die "python '$PYTHON_BIN' not found. Activate your BaxBench env or pass --python."

# python deps + scenario registry (must contain the 68 AutoBax scenarios)
"$PYTHON_BIN" - <<'PY' || die "Python preflight failed (see message above). Did you set up the BaxBench env and commit the AutoBax scenarios + __init__.py?"
import sys
try:
    import docker  # noqa
    import requests, tabulate  # noqa
except Exception as e:
    print(f"missing python dependency: {e}", file=sys.stderr); sys.exit(1)
from scenarios import all_scenarios
n = len(all_scenarios)
print(f"  scenarios registered: {n}")
if n < 96:
    print(f"  WARNING: expected >=96 (28 BaxBench + 68 AutoBax), found {n}.", file=sys.stderr)
    print("  Make sure the copied AutoBax scenario files and updated __init__.py are present.", file=sys.stderr)
    sys.exit(1)
PY

if [[ "$PHASE" == "test" || "$PHASE" == "all" ]]; then
  "$PYTHON_BIN" -c "import docker; docker.from_env().ping()" >/dev/null 2>&1 \
    || die "Docker daemon not reachable. The 'test' phase needs Docker. (Use --phase evaluate to skip testing.)"
  echo "  docker daemon: OK"
fi

# ---------------- detect models present ----------------
if [[ -n "$MODELS_OVERRIDE" ]]; then
  read -r -a MODELS <<< "$MODELS_OVERRIDE"
else
  MODELS=()
  for m in "${CANDIDATE_MODELS[@]}"; do
    esc="${m//\//-}"
    if [[ -d "$BAXBENCH_DIR/$esc" || -d "$AUTOBAX_DIR/$esc" ]]; then
      MODELS+=("$m")
    fi
  done
fi
[[ ${#MODELS[@]} -gt 0 ]] || die "No models found in results dirs. Pass --models \"<name>\" explicitly, or check --baxbench-dir/--autobax-dir."
log "Models to process: ${MODELS[*]}"
echo "  BaxBench dir: $BAXBENCH_DIR"
echo "  AutoBax  dir: $AUTOBAX_DIR"

EXTRA_TEST=()
[[ "$PRUNE" == "1" ]] && EXTRA_TEST+=(--prune_docker)

# ---------------- run a phase for one benchmark ----------------
# args: <mode> <bench: baxbench|autobax>
run_one() {
  local mode="$1" bench="$2"
  local results_dir scen_args=()
  if [[ "$bench" == "baxbench" ]]; then
    results_dir="$BAXBENCH_DIR"
    scen_args=(--scenarios $ORIG_IDS)              # 28 originals, all 14 envs
  else
    results_dir="$AUTOBAX_DIR"
    scen_args=(--exclude_scenarios $ORIG_IDS --envs Python-FastAPI)
  fi
  [[ -d "$results_dir" ]] || { warn "results dir for $bench not found ($results_dir); skipping."; return 0; }

  local common=(--models "${MODELS[@]}" --n_samples "$N_SAMPLES" \
                --temperature "$TEMPERATURE" \
                --results_dir "$results_dir" --max_concurrent_runs "$MAX_CONCURRENT" \
                "${scen_args[@]}")
  [[ -n "$LIMIT" ]] && common+=(--limit "$LIMIT")
  [[ "$FORCE" == "1" ]] && common+=(--force)

  if [[ "$mode" == "test" ]]; then
    log "TEST  [$bench]  ($results_dir)"
    "$PYTHON_BIN" main.py --mode test "${common[@]}" "${EXTRA_TEST[@]}"
  else
    log "EVALUATE  [$bench]  ($results_dir)"
    local out="$results_dir/EVAL_${bench}.txt"
    "$PYTHON_BIN" main.py --mode evaluate "${common[@]}" --ks $KS | tee "$out"
    echo "  (saved table to $out)"
  fi
}

# ---------------- orchestrate ----------------
PHASES=()
case "$PHASE" in
  test)     PHASES=(test);;
  evaluate) PHASES=(evaluate);;
  all)      PHASES=(test evaluate);;
  *) die "invalid --phase '$PHASE' (use test|evaluate|all)";;
esac

for ph in "${PHASES[@]}"; do
  [[ "$DO_BAXBENCH" == "1" ]] && run_one "$ph" baxbench
  [[ "$DO_AUTOBAX"  == "1" ]] && run_one "$ph" autobax
done

log "DONE. Evaluation tables saved as EVAL_baxbench.txt / EVAL_autobax.txt in the respective results dirs."
