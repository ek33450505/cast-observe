# Changelog

## [0.2.0] - 2026-04-03

### Added

- `cast-dash.py` — Textual TUI dashboard (htop for Claude Code): live agent/session monitoring
- `cast-stats.sh` — Usage analytics script
- `cast-observe dash` subcommand — launch TUI from the CLI
- `install` now sets up `~/.claude/venv` and installs `textual` for the TUI
- `settings.json` now includes `PostToolUseFailure`, `PreCompact`, `PostCompact` events
- All `settings.json` hook entries now have `id` and `async` fields

### Changed

- Removed deprecated `Stop` event from `settings.json` — `SessionEnd` covers the same lifecycle event
- All hook scripts: migrated `CO_` env var prefix to `CAST_` prefix for consistency with upstream CAST
- All hook scripts: migrated `~/.claude/observe/` paths to `~/.claude/cast/` to align with main CAST runtime
- `observe-subagent-start.sh` — now reads `agent_type` field from SubagentStart stdin JSON (was missing `agent_type` parsing)
- `observe_db.py` — error log path updated to `~/.claude/logs/db-write-errors.log`
- `install` now creates `~/.claude/cast/` instead of `~/.claude/observe/`

## [0.1.0] - 2026-04-02
- Initial release
- Session, agent run, and cost tracking via Claude Code hooks
- cast-observe CLI: status, budget, sessions, db subcommands
- Homebrew formula
