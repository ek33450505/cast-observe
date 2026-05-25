# cast-observe

Session-level cost tracking and agent run history for Claude Code, with no framework required.

[![CI](https://github.com/ek33450505/cast-observe/actions/workflows/ci.yml/badge.svg)](https://github.com/ek33450505/cast-observe/actions/workflows/ci.yml)
![version](https://img.shields.io/badge/version-0.2.0-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)

## What you get

- Per-session token count and cost in USD tracked automatically
- Agent run history (which agents ran, how long, what it cost)
- Daily and weekly cost summaries with per-agent breakdown
- Budget alerts when you approach or hit a daily limit
- Live TUI dashboard (`cast-observe dash`) — htop for Claude Code
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

cast-observe v0.2.0 — Status
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

# Launch the live TUI dashboard (requires textual — installed by 'cast-observe install')
cast-observe dash
```

## How it works

| Hook | Script | What it records |
|---|---|---|
| SessionStart | observe-session-start.sh | Session ID, working directory, timestamp |
| SessionEnd | observe-session-end.sh | DB pruning, blocked-count escalation, temp file cleanup |
| SubagentStart | observe-subagent-start.sh | Agent name (via agent_type), session ID, event file |
| SubagentStop | observe-subagent-stop.sh | Agent status, cost, turn ceiling events |
| PostToolUse | observe-cost-tracker.sh | Token counts, cost in USD, model |
| PostToolUseFailure | observe-cost-tracker.sh | Tool failure tracking |
| PreCompact / PostCompact | observe-session-end/start.sh | Compact lifecycle hooks |
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

## Part of CAST

cast-observe is the observability primitive layer used by the [CAST framework](https://github.com/ek33450505/claude-agent-team). It ships standalone for Claude Code users who want session cost tracking and agent run history without the full CAST orchestration and multi-agent framework.

## CAST Ecosystem

> Auto-synced from [claude-agent-team/docs/ecosystem.md](https://github.com/ek33450505/claude-agent-team/blob/main/docs/ecosystem.md). Run `~/Projects/personal/claude-agent-team/scripts/sync-ecosystem-readme.sh` to refresh.

<!-- ECOSYSTEM_START -->
| Repo | Description | Latest | Install |
|---|---|---|---|
| [cast-hooks](https://github.com/ek33450505/cast-hooks) | 13 auditable hook scripts — observability, safety guards, quality gates. SessionStart, PreToolUse, PostToolUse, PostCompact. | ![](https://img.shields.io/github/v/release/ek33450505/cast-hooks?style=flat-square) | `brew tap ek33450505/cast-hooks && brew install cast-hooks` |
| [cast-agents](https://github.com/ek33450505/cast-agents) | 23 specialist agents — commit, debug, review, plan, test, research, and more. Agent definitions with YAML frontmatter. v7-synced. | ![](https://img.shields.io/github/v/release/ek33450505/cast-agents?style=flat-square) | `brew tap ek33450505/cast-agents && brew install cast-agents` |
| [cast-memory](https://github.com/ek33450505/cast-memory) | Persistent agent memory with FTS5 search, relevance scoring, shared pool, semantic embeddings. Per-agent knowledge accumulation. | ![](https://img.shields.io/github/v/release/ek33450505/cast-memory?style=flat-square) | `brew tap ek33450505/cast-memory && brew install cast-memory` |
| [cast-routines](https://github.com/ek33450505/cast-routines) | Scheduled autonomous Claude Code routines via YAML + cron. Daily briefings, inbox triage, release celebration, weekly cost reports. | ![](https://img.shields.io/github/v/release/ek33450505/cast-routines?style=flat-square) | `brew tap ek33450505/cast-routines && brew install cast-routines` |
| [cast-parallel](https://github.com/ek33450505/cast-parallel) | Parallel agent execution across worktree sessions. Agent Dispatch Manifest (ADM) support. | ![](https://img.shields.io/github/v/release/ek33450505/cast-parallel?style=flat-square) | `brew tap ek33450505/cast-parallel && brew install cast-parallel` |
| [cast-observe](https://github.com/ek33450505/cast-observe) | Session-level observability — cost tracking, agent run history, token spend, event sourcing. Feeds cast.db. | ![](https://img.shields.io/github/v/release/ek33450505/cast-observe?style=flat-square) | `brew tap ek33450505/cast-observe && brew install cast-observe` |
| [cast-security](https://github.com/ek33450505/cast-security) | Security hooks and audit trails. PII redaction, parry-guard integration, compliance logging. | ![](https://img.shields.io/github/v/release/ek33450505/cast-security?style=flat-square) | `brew tap ek33450505/cast-security && brew install cast-security` |
| [cast-doctor](https://github.com/ek33450505/cast-doctor) | Read-only health check for any Claude Code install. Validates hooks, MCP servers, agent frontmatter, cast.db schema, stale memories. | ![](https://img.shields.io/github/v/release/ek33450505/cast-doctor?style=flat-square) | `brew tap ek33450505/cast-doctor && brew install cast-doctor` |
| [cast-time](https://github.com/ek33450505/cast-time) | Gives Claude Code a clock — injects local time, timezone, and a semantic time-of-day bucket at every SessionStart. | ![](https://img.shields.io/github/v/release/ek33450505/cast-time?style=flat-square) | `brew tap ek33450505/cast-time && brew install cast-time` |
| [cast-dash](https://github.com/ek33450505/cast-dash) | Terminal UI dashboard for live swarm monitoring. 4-panel real-time display (Textual framework). | ![](https://img.shields.io/github/v/release/ek33450505/cast-dash?style=flat-square) | `brew tap ek33450505/cast-dash && brew install cast-dash` |
| [cast-claudes_journal](https://github.com/ek33450505/cast-claudes_journal) | Session continuity — Claude's Journal auto-injects prior-day context via SessionStart hook. Obsidian vault sync. | ![](https://img.shields.io/github/v/release/ek33450505/cast-claudes_journal?style=flat-square) | `brew tap ek33450505/homebrew-claudes-journal && brew install claudes-journal` |
| [cast-website](https://github.com/ek33450505/cast-website) | castframework.dev — marketing site and docs portal for the CAST ecosystem. | ![](https://img.shields.io/github/v/release/ek33450505/cast-website?style=flat-square) | — |
| [cast-desktop](https://github.com/ek33450505/cast-desktop) | Tauri 2 native app — embedded PTY terminal, command palette, 11 dashboard views, Constellation 3D graph. NEW. | ![](https://img.shields.io/github/v/release/ek33450505/cast-desktop?style=flat-square) | `brew tap ek33450505/homebrew-cast-desktop && brew install cast-desktop` |
<!-- ECOSYSTEM_END -->

cast-desktop (Tauri 2 native app) also consumes cast.db observability data via its embedded dashboard.

## License

MIT
