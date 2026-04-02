# cast-observe

Session-level cost tracking and agent run history for Claude Code, with no framework required.

![version](https://img.shields.io/badge/version-0.1.0-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)

## What you get

- Per-session token count and cost in USD tracked automatically
- Agent run history (which agents ran, how long, what it cost)
- Daily and weekly cost summaries with per-agent breakdown
- Budget alerts when you approach or hit a daily limit
- Direct SQLite access — no server, no cloud, no telemetry

## Install

### Homebrew

```bash
brew tap ek33450505/cast-observe
brew install cast-observe
cast-observe install
```

### Manual

```bash
git clone https://github.com/ek33450505/cast-observe.git
cd cast-observe
bash install.sh
```

## Usage

```
$ cast-observe status

cast-observe v0.1.0 — Status
════════════════════════════════════
  DB:              ~/.claude/cast.db (48K)
  Sessions today:  3
  Cost today:      $0.1247

Recent agent runs:
────────────────────────────────────
  general-purpose        DONE               $0.0412      2026-04-02 14:01
  general-purpose        DONE               $0.0198      2026-04-02 13:45
  general-purpose        DONE_WITH_CONCERNS $0.0089      2026-04-02 13:22


$ cast-observe budget

cast-observe — Budget Summary
════════════════════════════════════
  Today (2026-04-02):
    Input tokens:   124503
    Output tokens:  18921
    Cost:           $0.1247

  This week:
    Input tokens:   891234
    Output tokens:  142309
    Cost:           $0.8834

  Top agents by cost (all time):
    general-purpose           47 runs  $1.2341
    code-writer                8 runs  $0.3412
    bash-specialist            5 runs  $0.1203
```

Additional subcommands:

```bash
cast-observe sessions [--project <name>] [--limit N]
cast-observe budget --week
cast-observe budget --project my-project
cast-observe db path
cast-observe db query "SELECT COUNT(*) FROM agent_runs WHERE status='BLOCKED'"
cast-observe db size
```

## How it works

| Hook | Script | What it records |
|---|---|---|
| SessionStart | observe-session-start.sh | Session ID, working directory, timestamp |
| Stop | observe-session-end.sh | DB pruning, blocked-count escalation |
| SessionEnd | observe-session-end.sh | Same as Stop |
| SubagentStart | observe-subagent-start.sh | Agent name, session ID, event file |
| SubagentStop | observe-subagent-stop.sh | Agent status, cost, turn ceiling events |
| PostToolUse | observe-cost-tracker.sh | Token counts, cost in USD, model |
| PostToolUse | observe-budget-alert.sh | Budget threshold checks |

All hooks run with `async: true` so they never block Claude Code.

## Schema

Four tables in `~/.claude/cast.db`:

| Table | Purpose |
|---|---|
| sessions | One row per Claude Code session — tokens, cost, model, project |
| agent_runs | One row per agent invocation — agent name, status, cost, timing |
| routing_events | Forward-compatible with CAST — cast-observe reads but does not write |
| budgets | Daily/weekly cost limits and alert thresholds |

Direct access:

```bash
sqlite3 ~/.claude/cast.db
```

## Works alongside CAST

cast-observe uses the same `~/.claude/cast.db` path as the CAST multi-agent framework. If you install CAST later, it extends the schema without breaking cast-observe data.

## Requirements

- macOS 12+ or Linux
- Claude Code (Anthropic)
- python3
- sqlite3

## License

MIT
