# Repository Guidelines

## Project Structure & Module Organization
This repository is a Funktion-native CLI named `base`.

- Core source: `src/`
- CLI entrypoint: `src/main.fun`
- Plan command module: `src/PlanCli.fun`
- Domain modules: `src/Tasks.fun`, `src/Roadmap.fun`, `src/Plans.fun`, `src/Docs.fun`
- Persistence/scope: `src/Store.fun`, `src/Scope.fun`, `src/Models.fun`, `src/Util.fun`
- Script entrypoints: `src/scripts/` (for example `Link.fun`)
- Manifest: `fun.json`

Runtime data is repo-local by default in `<repo-root>/.base/` (`tasks.json`, `roadmap.json`, `plans.json`, `meta.json`).

## Build, Test, and Development Commands
- `funk check --severity error --quiet`: Type-check the full project.
- `funk check src/main.fun --severity error --quiet`: Type-check a specific module graph.
- `funk run src/main.fun -- <args>`: Run CLI directly.
- `funk script base -- <args>`: Run the script alias from `fun.json`.
- `funk script link`: Install/update the global `base` launcher.
- `funk deps` / `funk deps doctor --json`: Inspect dependency state.
- `funk update github:yuri-xyz/funktion/packages/stdlib`: Refresh stdlib materialization.

## Coding Style & Naming Conventions
- Use idiomatic Funktion with explicit, readable types and small focused functions.
- Prefer stdlib utilities over custom helpers (`@std/Args`, `@std/List`, `@std/String`, etc.).
- Use `@std/Output` (`line`, `errLine`) for CLI output; avoid raw `unsafe: print(...)`.
- Keep modules maintainable; split files before they exceed compiler limits (600 lines).
- Naming: modules/files in PascalCase (`PlanCli.fun`), functions in camelCase.

## Testing Guidelines
There are currently no project `.test.fun` files. At minimum, run:
- `funk check --severity error --quiet`
- Manual smoke tests for changed commands (for example `base plan ...`, `base roadmap ...`).

When adding tests, prefer `*.test.fun` and run with `funk test`.

## Commit & Pull Request Guidelines
- Use Conventional Commits (for example `feat: add plan item move command`, `fix: resolve stdlib path handling`).
- Keep commits focused and scoped to one concern.
- PRs should include:
  - concise summary of behavior changes,
  - commands used for validation,
  - sample CLI output when UX changes.
