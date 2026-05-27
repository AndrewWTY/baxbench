# Running BaxBench / AutoBax evaluation after generation

This guide is for the **test + evaluate** half of the pipeline, driven by
[`run_after_generation.sh`](./run_after_generation.sh). It runs on a
**Docker-capable machine** and needs **no GPU and no model** — the language
model already did its work during generation; the generated code lives as plain
files inside the results directories.

---

## Background: the two halves of the pipeline

BaxBench evaluation has three modes. They split cleanly across two machines:

| Step | Mode | Needs | Where it ran / runs |
|------|------|-------|---------------------|
| 2. Generate | `generate` | GPU + model (vLLM) | already done — produced the `results_*` folders |
| 3. **Test** | `test` | **Docker** (no GPU) | **this machine** |
| 4. Evaluate | `evaluate` | nothing special | this machine |

During generation the model wrote one solution per task into
`results_*/<model>/<scenario>/<env>/temp.../sample<n>/code/`. **Testing never
calls the model again** — it builds a Docker image from that code, runs the app
in a container, and fires functional + security (exploit) tests at it.
Evaluating just aggregates the resulting JSON into `pass@k` scores.

Two benchmarks are evaluated:

- **BaxBench** — the 28 original scenarios, across **all 14 environments**
  (Python/JS/Go/Ruby/Rust/PHP). → `results_baxbench/`
- **AutoBax** — 68 AutoBaxBuilder-generated scenarios, **Python-FastAPI only**
  (the env they were authored for). → `results_autobax/`

---

## Prerequisites

1. **Docker**, running and reachable as your user:
   ```bash
   docker info        # should succeed without sudo
   ```
2. **Python environment with BaxBench's dependencies** (CPU-only — no torch/vLLM):
   ```bash
   pip install docker requests openai tabulate simple-parsing tqdm \
               termcolor anthropic pdfplumber imageio matplotlib pyyaml
   ```
   Python 3.10+ is required (the code uses modern type-hint syntax).
3. **This repository**, which must already include the 68 AutoBax scenario files
   in `src/scenarios/` and the updated `src/scenarios/__init__.py` (96 scenarios
   total). The script preflight will refuse to run if these are missing.

> No GPU, no vLLM, no model weights are needed on this machine.

---

## Setup

```bash
git clone <baxbench-repo> && cd baxbench

# Put the generated results next to the repo (default locations):
unzip results.zip          # -> ./results_baxbench/  and  ./results_autobax/
```

The results zip is produced on the generation machine and contains the
`results_baxbench/` and `results_autobax/` directories.

---

## Usage

```bash
# Test (Docker) + evaluate, both benchmarks, auto-detecting models present:
./run_after_generation.sh
```

That single command will:

1. **Preflight** — verify Docker is reachable, Python deps import, and the 96
   scenarios are registered.
2. **Detect models** present in the results folders (e.g. Qwen, SecCoderX).
3. **Test** BaxBench (28 × 14 envs) and AutoBax (68 × FastAPI) — builds images,
   runs containers, runs functional + exploit tests.
4. **Evaluate** — prints score tables and saves them to
   `EVAL_baxbench.txt` / `EVAL_autobax.txt` inside each results dir.

### Common variations

```bash
# Only print the score tables again (no Docker, instant) once testing is done:
./run_after_generation.sh --phase evaluate

# Only run the testing phase:
./run_after_generation.sh --phase test

# Results unzipped somewhere else:
./run_after_generation.sh --baxbench-dir /data/rb --autobax-dir /data/ra

# Only one benchmark:
./run_after_generation.sh --skip-autobax        # BaxBench only
./run_after_generation.sh --skip-baxbench       # AutoBax only

# Specific model(s) instead of auto-detect (use the original name, with slashes):
./run_after_generation.sh --models "Qwen/Qwen2.5-Coder-7B-Instruct"

# Use a specific python (e.g. inside a conda env):
./run_after_generation.sh --python /path/to/envs/baxbench/bin/python
```

### Options

| Option | Default | Meaning |
|--------|---------|---------|
| `--baxbench-dir DIR` | `./results_baxbench` | BaxBench results directory |
| `--autobax-dir DIR` | `./results_autobax` | AutoBax results directory |
| `--n-samples N` | `5` | Samples per task — **must match generation** |
| `--phase P` | `all` | `test`, `evaluate`, or `all` |
| `--models "A B"` | auto-detect | Model names (original form, with `/`) |
| `--ks "1 5"` | `1 5` | k values for `pass@k` |
| `--max-concurrent N` | `8` | Cap on concurrent test containers |
| `--python BIN` | `python` | Python executable to use |
| `--skip-baxbench` | off | Skip the BaxBench results |
| `--skip-autobax` | off | Skip the AutoBax results |
| `--no-prune` | off | Don't prune Docker containers after testing |
| `-h`, `--help` | — | Show help |

---

## Output

The evaluate phase prints two kinds of tables per benchmark and saves them:

- `results_baxbench/EVAL_baxbench.txt`
- `results_autobax/EVAL_autobax.txt`

Key metrics:

- **`pass@k`** — fraction of tasks where at least one of `k` samples is
  *functionally correct* (passes all functional tests).
- **`secure_pass@k`** — fraction where a sample is functionally correct **and**
  no exploit succeeded (passes all security tests).
- **CWE breakdown** — how often each vulnerability class appeared.

If multiple models are present, each appears as its own row — that's your
baseline-vs-aligned comparison.

---

## Inspecting individual test failures

Each sample's test output is stored alongside the generated code. The key files
are:

```
results_baxbench/<model>/<scenario>/<env>/temp0.2-openapi-none/sample<N>/
├── code/          # the generated source code
├── test.log       # full test log (Docker build, container logs, test results)
└── test_results.json  # structured pass/fail counts
```

### Quick commands

```bash
# See the crash reason for a specific sample:
grep "container logs:" -A5 \
  results_baxbench/Qwen-Qwen2.5-Coder-7B-Instruct/ClickCount/Go-Fiber/temp0.2-openapi-none/sample0/test.log

# Scan all 5 samples for one scenario:
for s in sample{0..4}; do
  echo "=== $s ==="
  grep "container logs:" -A3 \
    results_baxbench/Qwen-Qwen2.5-Coder-7B-Instruct/ClickCount/Go-Fiber/temp0.2-openapi-none/$s/test.log 2>/dev/null | head -6
done

# Bulk scan all BaxBench scenarios (sample 0 only):
for d in results_baxbench/Qwen-Qwen2.5-Coder-7B-Instruct/*/Go-Fiber/temp0.2-openapi-none/sample0/test.log; do
  scenario=$(echo "$d" | cut -d/ -f3)
  reason=$(grep "container logs:" -A2 "$d" 2>/dev/null | tail -1)
  echo "$scenario: $reason"
done

# Same for AutoBax:
for d in results_autobax/Qwen-Qwen2.5-Coder-7B-Instruct/*/Python-FastAPI/temp0.2-openapi-none/sample0/test.log; do
  scenario=$(echo "$d" | cut -d/ -f3)
  reason=$(grep "container logs:" -A2 "$d" 2>/dev/null | tail -1)
  echo "$scenario: $reason"
done

# Check structured test results:
cat results_baxbench/Qwen-Qwen2.5-Coder-7B-Instruct/ClickCount/Go-Fiber/temp0.2-openapi-none/sample0/test_results.json

# View the generated code:
cat results_baxbench/Qwen-Qwen2.5-Coder-7B-Instruct/ClickCount/Go-Fiber/temp0.2-openapi-none/sample0/code/main.go
```

### Common failure patterns

| Pattern | Example | Cause |
|---------|---------|-------|
| `sql: unknown driver "sqlite3"` | Go scenarios | Missing blank import `_ "github.com/mattn/go-sqlite3"` |
| `./myapp: not found` | Go scenarios | Go build failed silently (no binary produced) |
| `ModuleNotFoundError` | Python scenarios | Code uses a library not in the Docker image (e.g. sqlalchemy) |
| `Traceback ... CREATE TABLE` | Python scenarios | SQL syntax errors in generated code (e.g. duplicate columns) |
| `Server is not up yet` (repeated) | Any | Container crashed on startup; server never became reachable |

---

## Notes & troubleshooting

- **First test run is slow.** BaxBench's 14 environments include Go, Rust, PHP,
  Ruby, Node and Python — Docker must build a base image per framework. This is
  a one-time cost; later runs reuse cached images.
- **Resource use.** Each container is capped at 2 GB RAM; `--max-concurrent`
  bounds how many run at once. Lower it (e.g. `--max-concurrent 4`) on smaller
  machines.
- **"Docker daemon not reachable."** Start Docker and ensure your user can run
  `docker info` without `sudo`. Use `--phase evaluate` to skip testing entirely.
- **"scenarios registered: <96 / WARNING".** The repo is missing the copied
  AutoBax scenario files or the updated `src/scenarios/__init__.py`. Re-pull the
  repo; these must be committed.
- **`--n-samples` must match** what was used during generation, otherwise some
  samples are ignored or reported missing.
- **Re-running is safe.** Already-tested samples are skipped unless you pass
  `--force` (add it via editing the script if you need a clean re-test).
- **Idempotent evaluate.** You can re-run `--phase evaluate` any time to
  regenerate the score tables from existing test results.
