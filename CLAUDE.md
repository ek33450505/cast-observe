# cast-observe

**CAST observability module** — tracks sessions, agents, costs, and tool usage via SQLite. Emits hook events to ~/.claude/cast.db.

## Install
```bash
bash install.sh
```
Installs `cast-observe` to PATH and registers hooks in `~/.claude/settings.json`.

## Test
```bash
bats tests/*.bats
```
Runs 4 test suites: `cli.bats`, `db.bats`, `hooks.bats`, `install.bats`.

## Run
```bash
cast-observe
```
Installed to PATH. Auto-invoked via hook chain during sessions. Can be run manually to check observability state.

## Key Non-Obvious Details

- **Hook events** — All events emitted must use `CAST_` prefix (e.g., `CAST_SessionStart`, `CAST_SubagentStop`)
- **Async required** — Event payloads must include `"async": true` (see `settings.json` — all hooks except SessionStart are async)
- **Hook registration** — All hooks registered in `~/.claude/settings.json` at install time. Defines 7 hook handlers: SessionStart, SessionEnd, SubagentStart, SubagentStop, PostToolUse, PostToolUseFailure, PreCompact, PostCompact
- **Database** — SQLite schema with 38 tables; accessible via `sqlite3 ~/.claude/cast.db`

## Scripts
- `observe-session-start.sh` — Records session metadata at start
- `observe-session-end.sh` — Finalizes session on end or compact
- `observe-subagent-start.sh` — Records subagent dispatch
- `observe-subagent-stop.sh` — Records subagent completion, agent facts, and memories
- `observe-cost-tracker.sh` — Tracks API costs per tool use
- `observe-budget-alert.sh` — Alerts if cost threshold breached
- `cast-dash.py` — TUI dashboard showing live session state
