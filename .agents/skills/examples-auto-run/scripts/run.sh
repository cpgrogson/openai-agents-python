#!/usr/bin/env bash
# examples-auto-run/scripts/run.sh
# Automatically discovers and runs all examples in the repository,
# capturing output and reporting pass/fail status for each.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EXAMPLES_DIR="${REPO_ROOT}/examples"
LOG_DIR="${REPO_ROOT}/.agents/skills/examples-auto-run/logs"
TIMEOUT_SECONDS="${EXAMPLES_TIMEOUT:-60}"
PYTHON="${PYTHON_BIN:-python}"

PASSED=()
FAILED=()
SKIPPED=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[examples-auto-run] $*"; }
warn() { echo "[examples-auto-run] WARNING: $*" >&2; }
err()  { echo "[examples-auto-run] ERROR: $*" >&2; }

requires_api_key() {
  local file="$1"
  # Skip examples that explicitly require a live API key when none is set
  if grep -qE 'openai\.api_key|OPENAI_API_KEY' "$file" 2>/dev/null; then
    if [[ -z "${OPENAI_API_KEY:-}" ]]; then
      return 0  # true — requires key, key absent
    fi
  fi
  return 1  # false — safe to run
}

run_example() {
  local script="$1"
  local rel="${script#${REPO_ROOT}/}"
  local log_file="${LOG_DIR}/$(echo "$rel" | tr '/' '__').log"

  mkdir -p "$LOG_DIR"

  if requires_api_key "$script"; then
    warn "Skipping '$rel' — requires OPENAI_API_KEY which is not set."
    SKIPPED+=("$rel")
    return
  fi

  log "Running: $rel"
  local exit_code=0

  # Run with a timeout; capture stdout+stderr to log file
  if command -v timeout &>/dev/null; then
    timeout "${TIMEOUT_SECONDS}" "${PYTHON}" "$script" \
      > "$log_file" 2>&1 || exit_code=$?
  else
    # macOS fallback — use perl-based timeout shim if available
    "${PYTHON}" "$script" > "$log_file" 2>&1 || exit_code=$?
  fi

  if [[ $exit_code -eq 0 ]]; then
    log "  PASS: $rel"
    PASSED+=("$rel")
  elif [[ $exit_code -eq 124 ]]; then
    warn "  TIMEOUT: $rel (>${TIMEOUT_SECONDS}s)"
    FAILED+=("$rel [timeout]")
  else
    warn "  FAIL: $rel (exit $exit_code) — see $log_file"
    FAILED+=("$rel [exit $exit_code]")
  fi
}

# ---------------------------------------------------------------------------
# Discover examples
# ---------------------------------------------------------------------------
discover_examples() {
  if [[ ! -d "$EXAMPLES_DIR" ]]; then
    err "Examples directory not found: $EXAMPLES_DIR"
    exit 1
  fi

  # Find all top-level Python entry-point files inside examples/
  # Prefer files named main.py or matching the parent directory name.
  find "$EXAMPLES_DIR" -maxdepth 3 -name '*.py' \
    | grep -v '__pycache__' \
    | grep -v 'test_' \
    | sort
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  log "Starting examples auto-run"
  log "  Repo root : $REPO_ROOT"
  log "  Examples  : $EXAMPLES_DIR"
  log "  Timeout   : ${TIMEOUT_SECONDS}s per example"
  log "  Python    : $(${PYTHON} --version 2>&1)"
  echo

  mapfile -t EXAMPLES < <(discover_examples)

  if [[ ${#EXAMPLES[@]} -eq 0 ]]; then
    warn "No example scripts discovered under $EXAMPLES_DIR"
    exit 0
  fi

  for script in "${EXAMPLES[@]}"; do
    run_example "$script"
  done

  # ---------------------------------------------------------------------------
  # Summary
  # ---------------------------------------------------------------------------
  echo
  log "=============================="
  log "Results summary"
  log "  Passed : ${#PASSED[@]}"
  log "  Failed : ${#FAILED[@]}"
  log "  Skipped: ${#SKIPPED[@]}"
  log "=============================="

  if [[ ${#FAILED[@]} -gt 0 ]]; then
    err "The following examples failed:"
    for f in "${FAILED[@]}"; do
      err "  - $f"
    done
    exit 1
  fi

  log "All examples passed."
}

main "$@"
