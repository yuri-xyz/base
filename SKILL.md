# base CLI Skill Guide

This guide explains how to use `base` effectively inside any project directory.

## What `base` Does
`base` is a Git-scoped project companion CLI for:
- tasks (`todo` / `in_progress` / `done`)
- plans (long implementation plans with ordered items)
- roadmap goals (conceptual direction, ordered)
- docs/knowledge base (markdown docs + fuzzy search)

Run from repo root or any subdirectory; scope resolves to the same repository.

## Rule: Use CLI, Not Manual File Edits
- Always use `base` commands to create/update/remove data.
- Do **not** edit `.base/*.json` files by hand.
- If a change is needed, map it to the corresponding CLI command (`tasks`, `tags`, `plan`, `roadmap`, `docs`).
- Prefer `--help` or `-h` on the exact command you plan to use when you need to confirm syntax.
- Treat unknown flags/extra args as errors; do not assume the CLI will ignore them.

## Storage Modes
- Default (recommended): repo-local storage at `<repo-root>/.base`
- Global mode: add `--global` to any command to use `~/.base` (or `BASE_HOME`)

Examples:
```bash
base
base init
base --global init
base plan list --global
```

## Quick Start
```bash
base init
base tasks add "Ship onboarding flow" -d "MVP only" -t onboarding,mvp
base plan create "Refactor auth subsystem" -d "Split boundary and adapters"
base roadmap add "Improve developer velocity" -d "Reduce setup and feedback time"
base docs add architecture -f ./ARCHITECTURE.md
```

## Command Groups

### Tasks
- alias: `base task ...`
- `base tasks list [--all]`
- `base tasks add <title> [-d ...] [-t tag1,tag2]`
- `base tasks update <taskId> [--title ...] [-d ...] [--status ...] [-t ...]`
- `base tasks set-status <taskId> <todo|in_progress|done>`
- `base tasks remove <taskId>`

### Tags
- `base tags list`
- `base tags add <tag>`
- `base tags remove <tag>`
- `base tags rename <from> <to>`

### Plans
- `base plan create <title> [-d ...]`
- `base plan list [--all]`
- `base plan show <planId>`
- `base plan set-status <planId> <planned|active|done>`
- `base plan update <planId> [--title ...] [-d ...] [--status planned|active|done]`
- `base plan add-item <planId> <title> [-d ...]`
- `base plan update-item <planId> <itemId> [--title ...] [-d ...] [--status todo|in_progress|done]`
- `base plan set-item-status <planId> <itemId> <todo|in_progress|done>`
- `base plan move-item <planId> <itemId> <position>`
- `base plan remove-item <planId> <itemId>`

### Roadmap
- `base roadmap list`
- `base roadmap add <goal> [-d ...]`
- `base roadmap set-status <itemId> <planned|active|done>`
- `base roadmap update <itemId> [--goal ...] [-d ...] [--status planned|active|done]`
- `base roadmap move <itemId> <position>`
- `base roadmap remove <itemId>`

### Docs / KB
- `base docs list|show|add|update|remove`
- `base docs search <query> [-l <n>]`
- alias: `base kb search <query> [-l <n>]`
- `base search <query> [-l <n>]` for cross-entity search (tasks, plans, roadmap, docs)

## Notes
- `init` is required before mutating/listing project data, but command help works before initialization.
- Plan/roadmap done entries stay visible with completion timestamps.
- Use `funk script link` to install/update the global `base` launcher.
