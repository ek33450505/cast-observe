# Contributing to cast-observe

Thank you for your interest in cast-observe! This guide covers everything you need to add scripts, tests, and CLI subcommands.

## Prerequisites

- **bats-core** — test runner, included as a git submodule at `tests/bats/`
- **sqlite3** — required for DB features
- **Bash 4+** — all scripts target Bash 4 (macOS ships Bash 3; install via `brew install bash`)
- **Python 3.8+** — required for cost tracker and budget alert hooks
- **Claude Code CLI** — for testing hook behavior end-to-end

## Quick Start

```bash
git clone --recurse-submodules https://github.com/ek33450505/cast-observe
cd cast-observe
bash install.sh
tests/bats/bin/bats tests/
```

## Adding a Hook Script

Hook scripts live in `scripts/observe-*.sh`. All hooks must follow these rules:

1. **Always exit 0** — use `set +e` at the top; a broken hook must never interrupt Claude Code
2. **Handle empty stdin gracefully** — read stdin with `INPUT="$(cat 2>/dev/null || true)"`, then guard:
   ```bash
   [ -z "$INPUT" ] && exit 0
   ```
3. **Read data from stdin JSON, not env vars** — Claude Code passes event data via stdin, not environment variables (exception: `CLAUDE_SESSION_ID` and `CLAUDE_SUBPROCESS` are available as env vars)
4. **Never hardcode paths** — use `$HOME` or `${HOME}/.claude/`
5. **Name the file** `observe-<event>.sh` (e.g., `observe-session-start.sh`)

After adding a script, register it in `install.sh` (the scripts copy block) and add tests in `tests/hooks.bats`.

## Adding a CLI Subcommand

1. Edit `bin/cast-observe`
2. Add a `case` entry in the main dispatch block
3. Update the `--help` block at the top of the file to document the new subcommand
4. Add tests in `tests/cli.bats` (exit 0 assertion + output assertion)

## Adding a BATS Test

Tests live in `tests/<file>.bats`. The four test files and their scope:

| File | Scope |
|---|---|
| `tests/install.bats` | install.sh behavior |
| `tests/cli.bats` | cast-observe CLI subcommands |
| `tests/hooks.bats` | Hook script empty stdin + valid JSON |
| `tests/db.bats` | DB init, schema, idempotency |

Rules:
- Test empty stdin AND valid JSON stdin for every hook script
- Test exit codes for every CLI subcommand
- Use `command -v sqlite3 || skip "sqlite3 not found"` in `setup()` for DB-dependent tests

## PR Checklist

- [ ] `tests/bats/bin/bats tests/` passes locally
- [ ] New hook script: exits 0 with empty stdin (test in `tests/hooks.bats`)
- [ ] New hook script: exits 0 with valid JSON stdin (test in `tests/hooks.bats`)
- [ ] No hardcoded paths — use `$HOME`
- [ ] `CHANGELOG.md` updated for any user-visible changes
