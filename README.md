# base

`base` is a Funktion-native CLI for managing project-scoped work:

- tasks
- plans (with ordered items)
- roadmap goals
- project docs (plus fuzzy search)

It auto-detects your Git repo root and stores data in repo-local or global scope.
It is designed for human + AI pair workflows, including tools like Codex and Claude Code.

## Quick Links

- [Why base](#why-base)
- [AI Agent Workflow](#ai-agent-workflow)
- [Installation and Run](#installation-and-run)
- [Quickstart](#quickstart)
- [Storage and Scope](#storage-and-scope)
- [Command Reference](#command-reference)
- [IDs and Status Values](#ids-and-status-values)
- [Bastion Auto-Ingest](#bastion-auto-ingest)
- [Development](#development)
- [Troubleshooting](#troubleshooting)

## Why base

- Git-scoped by default: state lives with the repo in `.base/`
- Fast local workflow: no SaaS, no remote dependency
- Structured planning: plans, plan items, roadmap ordering, statuses
- Built-in knowledge base: markdown docs with fuzzy search
- Flexible scope: switch to global storage with `--global`
- Agent-friendly CLI surface: explicit commands and predictable repo-scoped state

## AI Agent Workflow

`base` is optimized for coding-agent loops (for example Codex and Claude Code):

- durable context: plans, tasks, roadmap, and docs live in-repo by default
- deterministic command surface: simple verbs and stable statuses for automation
- low-friction planning loop: agents can create/update/show/search without external services

## Installation and Run

### Prerequisites

- [Funktion CLI](https://github.com/yuri-xyz/funktion) installed
- Git available in your shell

### Verify dependencies

```bash
funk deps
```

### Run without installing a global binary

```bash
funk run src/main.fun -- help
```

Or use the project script alias:

```bash
funk script base -- help
```

### Install a global `base` launcher

```bash
funk script link
```

This installs `base` at:

- default: `~/.local/bin/base`
- override: `BASE_BIN_DIR=/custom/bin funk script link`

## Quickstart

```bash
# 1) initialize project storage
base init

# 2) add task + roadmap + plan
base tasks add "Ship CLI docs rewrite" -d "Replace README with command-accurate guide" -t docs,cli
base roadmap add "Polish CLI UX" -d "Improve help, output clarity, docs"
base plan create "Release prep" -d "Track final improvements"

# 3) add plan item
base plan add-item #1 "Finalize README" -d "End-to-end command reference"

# 4) add a project note
base docs add architecture -c "# Architecture\n\nCore modules and responsibilities."

# 5) search everything
base search "readme"
```

## Storage and Scope

`base` supports two storage modes:

- local (default): `<repo-root>/.base`
- global (`--global`): `<BASE_HOME|~/.base>/projects/<project-key>`

`BASE_HOME` overrides the storage root in both modes.

Examples:

```bash
base tasks list
base --global tasks list
BASE_HOME=/tmp/base-data base --global tasks list
```

`project-key` is derived from repo identity (slugged repo name + source hash), so global projects stay distinct even with similar names.

### Data layout

After `base init`, the project directory contains:

- `meta.json`
- `tasks.json`
- `tags.json`
- `roadmap.json`
- `plans.json`
- `docs/*.md`

## Command Reference

Use `--global` with any command.

```bash
base --global <command> ...
```

### Overview and init

```bash
base
base init
base help
```

- `base` shows scope, pending tasks, roadmap goals, and docs.
- Most subcommands require initialization first (`base init`).

### Tasks

```bash
base tasks list [--all]
base tasks add <title> [-d|--description <text>] [-t|--tags <csv>] [--id <key>]
base tasks update <taskId> [--title <text>] [-d|--description <text>] [--status <todo|in_progress|done>] [-t|--tags <csv>]
base tasks set-status <taskId> <todo|in_progress|done>
base tasks remove <taskId>
```

Notes:

- `list` hides done tasks unless `--all` is used.
- tags are normalized to lowercase and deduplicated.

### Tags

```bash
base tags list
base tags add <tag>
base tags remove <tag>
base tags rename <from> <to>
```

Notes:

- tag rename/remove also updates task tag assignments.

### Plans

```bash
base plan list [--all]
base plan create <title> [-d|--description <text>] [--id <key>]
base plan show <planId>
base plan set-status <planId> <planned|active|done>
base plan update <planId> [--title <text>] [-d|--description <text>] [--status <planned|active|done>]
base plan remove <planId>
base plan add-item <planId> <title> [-d|--description <text>] [--id <key>]
base plan update-item <planId> <itemId> [--title <text>] [-d|--description <text>] [--status <todo|in_progress|done>]
base plan set-item-status <planId> <itemId> <todo|in_progress|done>
base plan move-item <planId> <itemId> <position>
base plan remove-item <planId> <itemId>
```

Notes:

- plan items are ordered and renumbered when moved/removed.
- completed plans/items retain completion timestamps.

### Roadmap

```bash
base roadmap list
base roadmap add <goal> [-d|--description <text>] [--id <key>]
base roadmap update <itemId> [--goal <text>] [-d|--description <text>] [--status <planned|active|done>]
base roadmap set-status <itemId> <planned|active|done>
base roadmap move <itemId> <position>
base roadmap remove <itemId>
```

Notes:

- roadmap goals are always ordered.
- completion timestamps are set/cleared based on status transitions.

### Docs

```bash
base docs list
base docs show <name>
base docs add <name> [-c|--content <text>] [-f|--file <path>]
base docs update <name> [-c|--content <text>] [-f|--file <path>]
base docs remove <name>
base docs search <query> [-l|--limit <n>]
```

Notes:

- doc names are normalized (lowercase/safe chars) and stored as `.md`.
- `add` and `update` accept inline content or a file path, but not both.
- `docs search` default limit is `5`.

### Global search

```bash
base search <query> [-l|--limit <n>]
```

Searches tasks, plans, plan items, roadmap, and docs together.

- default limit: `12`
- results are grouped by entity type

## IDs and Status Values

Generated IDs use this format:

- `#<sequence>-<slug>`
- example: `#12-release-prep`

You can often pass short IDs like `#12` instead of full IDs. If multiple IDs share the same sequence number, `base` returns an ambiguity error and asks for the full ID.

Canonical statuses:

- task / plan item: `todo`, `in_progress`, `done`
- roadmap / plan: `planned`, `active`, `done`

Accepted aliases include:

- `in-progress`, `doing` -> `in_progress`
- `plan` -> `planned`
- `complete`, `completed` -> `done`

## Bastion Auto-Ingest

Mutating commands (`init`, tasks/plans/roadmap/tags/docs writes) can trigger best-effort Bastion ingest of the project data directory.

Environment variables:

```bash
# optional binary override (default: bastion)
export BASE_BASTION_BIN=bastion

# default is enabled; disable with 0/false/off
export BASE_BASTION_AUTO_INGEST=true

# global fallback token
export BASE_BASTION_INGEST_TOKEN=...

# optional project-scoped override
# name shape: BASE_BASTION_INGEST_TOKEN_<project_key_with_dashes_replaced_by_underscores>
export BASE_BASTION_INGEST_TOKEN_my_repo_ab12cd34ef56=...
```

If Bastion is unavailable or token config is missing, `base` continues without failing the CLI command.

## Development

Type-check the full project:

```bash
funk check --severity error --quiet
```

Type-check a specific entry graph:

```bash
funk check src/main.fun --severity error --quiet
```

Run the CLI:

```bash
funk run src/main.fun -- <args>
funk script base -- <args>
```

Link global launcher:

```bash
funk script link
```

## Troubleshooting

- `Error: Project is not initialized...`: run `base init` first.
- `base: command not found`: run `funk script link` and ensure the launcher directory is in `PATH`.
- `unknown command`: run `base help` for the canonical command list.
