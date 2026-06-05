# Changelog

## [v0.2.1] — 2026-06-05

### Fixed

- `observe-db-init.sh`: removed `CHECK` constraint on `agent_runs.status` — writers emitting `abandoned`, `fallback`, or `unknown` statuses previously hit a constraint violation and lost the row (blocker-severity parity fix with flagship Phase 3)
- `observe-subagent-stop.sh`: added multi-path `agent_response.content` (content_blocks) extraction so agents dispatched via newer Claude Code payload paths are no longer silently dropped
- `observe-subagent-stop.sh`: `UPDATE agent_runs` now writes `duration_ms`, `tool_uses`, `response`, `cache_read_input_tokens`, and `cache_creation_input_tokens` columns (backport from flagship)
- `observe-subagent-stop.sh`: auto-adds missing telemetry columns via `ALTER TABLE IF NOT EXISTS` guard for forward compatibility
- README: corrected DB table count 37 → 38; removed false "Constellation 3D graph" claim from ecosystem block
- CLAUDE.md: corrected DB table count 26+ → 38
- SECURITY.md: added `0.2.x` as currently supported version
- `install.sh`: removed dead `~/.claude/observe` directory creation (migrated to `~/.claude/cast` in v0.2.0)
- Hook script header comments: updated stale `~/.claude/observe/` path references to `~/.claude/cast/`; removed deprecated `Stop` event from `observe-session-end.sh` header

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
