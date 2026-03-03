# base (Funktion-native)

`base` is a Funktion CLI for project-scoped tasks and docs.

It detects the Git repository root from your current directory (including subfolders) and stores all data in:

- default: `<repo-root>/.base`
- global mode (`--global`): `~/.base/projects/<repo-name>-<hash>`
- global override: `BASE_HOME=/custom/path base --global ...`

By default, data is local to the repository via `.base/` at repo root.

## Setup

This project depends on stdlib from:

- `github:yuri-xyz/funktion/packages/stdlib@master`

Verify dependencies:

```bash
funk deps
```

## Run

Use `funk run` directly:

```bash
funk run src/main.fun
funk run src/main.fun -- init
```

Or via script alias in `fun.json`:

```bash
funk script base
funk script base -- init
funk script base -- tasks list
```

## Global Link Script

Use the Funktion project script:

```bash
funk script link
```

What it does:

- installs a global launcher command named `base` that runs `src/main.fun` via `funk run`

Launcher location:

- default: `~/.local/bin/base`
- override: `BASE_BIN_DIR=/custom/bin funk script link`

If needed, add the bin directory to your `PATH`.

## Commands

### Overview

```bash
base
# (or: funk run src/main.fun)
```

Shows scope, pending tasks, roadmap goals, and docs.

Use global store mode for any command by adding `--global`:

```bash
base --global
base --global init
base --global plan list
```

### Initialization

```bash
base init
```

### Tasks

```bash
base tasks list [--all]
base tasks add "Ship CLI" -d "Implement core commands" -t cli,mvp
base tasks update <taskId> --title "Refine UX" --status in_progress
base tasks set-status <taskId> done
base tasks remove <taskId>
```

### Plans

```bash
base plan list [--all]
base plan create "Large refactor" -d "Break up API layer and data model"
base plan show <planId>
base plan set-status <planId> active
base plan update <planId> --status active
base plan add-item <planId> "Split services into modules" -d "One module per bounded context"
base plan update-item <planId> <itemId> --status in_progress
base plan set-item-status <planId> <itemId> in_progress
base plan set-item-status <planId> <itemId> done
base plan move-item <planId> <itemId> 1
base plan remove-item <planId> <itemId>
base plan set-status <planId> done
```

`plan` is for longer implementation plans (multi-step refactors/features). Each plan keeps ordered items with per-item status and completion timestamps.

### Roadmap

```bash
base roadmap list
base roadmap add "Ship team-wide workflow" -d "Define concrete milestone outcomes"
base roadmap set-status <itemId> active
base roadmap update <itemId> --goal "Refine workflow" --status active
base roadmap set-status <itemId> done
base roadmap move <itemId> <position>
base roadmap remove <itemId>
```

`roadmap` is meant for ordered, conceptual goals. Completed goals stay visible in `roadmap list` with their completion timestamp.

### Docs / Knowledge Base

```bash
base docs list
base docs show architecture
base docs add architecture -c "# Architecture"
base docs add roadmap -f ./ROADMAP.md
base docs update architecture -f ./ARCHITECTURE.md
base docs remove architecture
base docs search "queue worker" -l 5
base search "onboarding"
```

## Notes

- `init` is required before task/doc commands.
- Doc search uses a built-in fuzzy score (name + content signals).
- Status values: `todo`, `in_progress`, `done`.
- Plan status values: `planned`, `active`, `done`.
- Plan item status values: `todo`, `in_progress`, `done`.
- Roadmap status values: `planned`, `active`, `done`.

## Bastion Backup Integration

When enabled, mutating `base` commands (tasks/plans/roadmap/tags/docs/init) trigger a best-effort Bastion ingest of the current project's `.base` data directory.

Configure with env vars:

```bash
# optional; default is "bastion"
export BASE_BASTION_BIN=bastion

# default: enabled. set to 0/false/off to disable.
export BASE_BASTION_AUTO_INGEST=true

# global fallback ingest token
export BASE_BASTION_INGEST_TOKEN=...

# optional per-project token override:
# BASE_BASTION_INGEST_TOKEN_<project_key_with_dashes_replaced_by_underscores>
export BASE_BASTION_INGEST_TOKEN_my_repo_ab12cd34ef56=...
```

On each mutation, `base` runs:

```bash
bastion auth ingest path-now --token <token> --source-path <project .base dir> --recursive
```

If Bastion is unavailable or no token is configured, `base` continues normally (no command failure).
