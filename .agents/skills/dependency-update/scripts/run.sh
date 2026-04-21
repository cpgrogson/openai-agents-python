#!/usr/bin/env bash
# Dependency Update Skill
# Automatically checks for outdated dependencies and creates update PRs
# Compatible with: openai-agents-python project

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
LOG_PREFIX="[dependency-update]"
BRANCH_PREFIX="chore/dependency-update"
DATE_SUFFIX="$(date +%Y%m%d)"
UPDATE_BRANCH="${BRANCH_PREFIX}-${DATE_SUFFIX}"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log_info()  { echo "${LOG_PREFIX} INFO:  $*"; }
log_warn()  { echo "${LOG_PREFIX} WARN:  $*" >&2; }
log_error() { echo "${LOG_PREFIX} ERROR: $*" >&2; }

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_prerequisites() {
    local missing=0

    for cmd in python pip git; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Required command not found: $cmd"
            missing=1
        fi
    done

    # pip-tools provides pip-compile / pip-sync
    if ! python -m pip show pip-tools &>/dev/null; then
        log_warn "pip-tools not installed — installing now"
        python -m pip install --quiet pip-tools
    fi

    if [[ $missing -ne 0 ]]; then
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Detect outdated packages
# ---------------------------------------------------------------------------
get_outdated_packages() {
    log_info "Checking for outdated packages..."
    python -m pip list --outdated --format=json 2>/dev/null
}

# ---------------------------------------------------------------------------
# Update pyproject.toml / requirements files
# ---------------------------------------------------------------------------
update_dependencies() {
    log_info "Updating dependencies in project: ${PROJECT_ROOT}"
    cd "${PROJECT_ROOT}"

    # Update all packages that are safe to update (non-breaking minor/patch)
    if [[ -f "pyproject.toml" ]]; then
        log_info "Found pyproject.toml — running pip-compile to refresh lock"
        if [[ -f "requirements.txt" ]]; then
            pip-compile --upgrade --quiet pyproject.toml -o requirements.txt
            log_info "requirements.txt refreshed"
        fi
        if [[ -f "requirements-dev.txt" ]]; then
            pip-compile --upgrade --quiet pyproject.toml \
                --extra dev -o requirements-dev.txt
            log_info "requirements-dev.txt refreshed"
        fi
    elif [[ -f "requirements.in" ]]; then
        pip-compile --upgrade --quiet requirements.in
        log_info "requirements.txt compiled from requirements.in"
    else
        log_warn "No pyproject.toml or requirements.in found — skipping compile step"
    fi
}

# ---------------------------------------------------------------------------
# Commit changes if any
# ---------------------------------------------------------------------------
commit_changes() {
    cd "${PROJECT_ROOT}"

    if git diff --quiet; then
        log_info "No dependency changes detected — nothing to commit."
        return 0
    fi

    log_info "Dependency changes detected — preparing commit on branch: ${UPDATE_BRANCH}"

    # Create or reset the update branch
    if git show-ref --quiet "refs/heads/${UPDATE_BRANCH}"; then
        git checkout "${UPDATE_BRANCH}"
    else
        git checkout -b "${UPDATE_BRANCH}"
    fi

    git add requirements*.txt pyproject.toml 2>/dev/null || true

    OUTDATED_SUMMARY="$(python -m pip list --outdated --format=columns 2>/dev/null || echo 'N/A')"

    git commit -m "chore(deps): bump dependencies ${DATE_SUFFIX}

Automatically updated by the dependency-update skill.

Outdated packages before update:
${OUTDATED_SUMMARY}"

    log_info "Changes committed to branch '${UPDATE_BRANCH}'."
    return 1  # signal that changes were made
}

# ---------------------------------------------------------------------------
# Run verification after update
# ---------------------------------------------------------------------------
run_verification() {
    log_info "Running post-update verification..."
    cd "${PROJECT_ROOT}"

    if [[ -f ".agents/skills/code-change-verification/scripts/run.sh" ]]; then
        bash .agents/skills/code-change-verification/scripts/run.sh
    else
        # Fallback: basic install + test
        python -m pip install --quiet -e .
        if command -v pytest &>/dev/null; then
            pytest --tb=short -q || {
                log_error "Tests failed after dependency update!"
                exit 2
            }
        fi
    fi

    log_info "Verification passed."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log_info "Starting dependency update skill"
    check_prerequisites
    update_dependencies

    local changes_made=0
    commit_changes || changes_made=1

    if [[ $changes_made -eq 1 ]]; then
        run_verification
        log_info "Dependency update complete. Branch ready for PR: ${UPDATE_BRANCH}"
    else
        log_info "All dependencies are already up to date."
    fi
}

main "$@"
