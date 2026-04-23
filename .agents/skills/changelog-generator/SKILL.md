# Changelog Generator Skill

Automatically generates and maintains a CHANGELOG.md file based on git commit history, pull request descriptions, and semantic versioning conventions.

## Overview

This skill analyzes the git log between releases and produces structured changelog entries following the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format. It groups changes by type (Added, Changed, Deprecated, Removed, Fixed, Security) and links to relevant commits or PRs.

## Trigger

This skill runs:
- When a new version tag is pushed
- When manually triggered via workflow dispatch
- When a PR is merged into the main branch (preview mode)

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `from_ref` | Starting git ref (tag, commit, branch) | No | Last tag |
| `to_ref` | Ending git ref | No | `HEAD` |
| `version` | New version string (e.g. `1.2.0`) | No | Auto-detected |
| `output_file` | Path to changelog file | No | `CHANGELOG.md` |
| `dry_run` | Print output without writing to file | No | `false` |

## Outputs

- Updated `CHANGELOG.md` with a new version section prepended
- Summary of changes grouped by category
- Count of commits processed

## Behavior

### Commit Classification

Commits are classified using conventional commit prefixes:

| Prefix | Changelog Section |
|--------|------------------|
| `feat:` | Added |
| `fix:` | Fixed |
| `perf:` | Changed |
| `refactor:` | Changed |
| `deprecate:` | Deprecated |
| `remove:` | Removed |
| `security:` | Security |
| `docs:` | Changed |
| `chore:` | (skipped by default) |
| `test:` | (skipped by default) |

### Version Detection

If no version is provided, the skill attempts to detect it from:
1. `pyproject.toml` → `[project].version`
2. `setup.cfg` → `[metadata].version`
3. Git tags (increments patch by default)

## Example Output

```markdown
## [1.3.0] - 2024-11-15

### Added
- Support for streaming responses in agent runs (#142)
- New `on_handoff` lifecycle hook for tracing handoffs (#138)

### Fixed
- Race condition in concurrent tool execution (#145)
- Incorrect token counting for vision inputs (#141)

### Changed
- Improved error messages for invalid tool schemas (#139)
```

## Configuration

Optional `.agents/skills/changelog-generator/config.yaml` can override defaults:

```yaml
skip_prefixes:
  - chore
  - test
  - ci
max_commits: 500
link_template: "https://github.com/openai/openai-agents-python/commit/{sha}"
```
