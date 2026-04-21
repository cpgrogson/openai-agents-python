# Dependency Update Skill

This skill automates the process of checking for outdated dependencies, evaluating compatibility, and applying safe updates to the project.

## Overview

The dependency update skill performs the following steps:

1. **Audit current dependencies** — Scans `pyproject.toml` and `requirements*.txt` files to identify all pinned and unpinned dependencies.
2. **Check for updates** — Queries PyPI for the latest available versions of each dependency.
3. **Evaluate compatibility** — Runs the existing test suite against candidate updates to verify nothing breaks.
4. **Apply updates** — Modifies version constraints in the relevant files for dependencies that pass compatibility checks.
5. **Generate a report** — Produces a summary of what was updated, what was skipped, and why.

## Usage

This skill is intended to be invoked by an AI agent or a CI pipeline on a scheduled basis (e.g., weekly).

### Running manually

**Linux / macOS:**
```bash
bash .agents/skills/dependency-update/scripts/run.sh
```

**Windows (PowerShell):**
```powershell
.agents\skills\dependency-update\scripts\run.ps1
```

## Configuration

The skill respects the following environment variables:

| Variable | Default | Description |
|---|---|---|
| `DEP_UPDATE_STRATEGY` | `minor` | Update strategy: `patch`, `minor`, or `major` |
| `DEP_UPDATE_DRY_RUN` | `false` | If `true`, report changes without writing files |
| `DEP_UPDATE_SKIP` | _(empty)_ | Comma-separated list of packages to skip |
| `DEP_UPDATE_TEST_CMD` | `pytest` | Command used to verify compatibility |

## Output

A markdown report is written to `.agents/skills/dependency-update/reports/latest.md` after each run.

## Constraints

- Only updates packages where the new version satisfies the configured strategy.
- Never downgrades a package.
- Skips packages listed in `DEP_UPDATE_SKIP`.
- Aborts the entire update batch if the test command exits with a non-zero status.

## Agent Integration

See `agents/openai.yaml` for the agent configuration used when this skill is invoked via the OpenAI Agents SDK.
