#!/bin/bash
# observe-db-init.sh — cast-observe SQLite schema initialization
# Creates ~/.claude/cast.db with the cast-observe schema (4 tables).
# Idempotent: uses CREATE TABLE IF NOT EXISTS; safe to run repeatedly.
# Schema versioning via PRAGMA user_version = 1 (cast-observe v1).
#
# Usage:
#   observe-db-init.sh [--db /path/to/cast.db]

set -euo pipefail

DB_PATH="${CAST_DB_PATH:-${HOME}/.claude/cast.db}"

# Allow override via flag
if [ "${1:-}" = "--db" ] && [ -n "${2:-}" ]; then
  DB_PATH="$2"
fi

# Ensure parent directory exists
mkdir -p "$(dirname "$DB_PATH")"

# Check for sqlite3
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "Error: sqlite3 not found in PATH. Install sqlite3 to use cast.db." >&2
  exit 1
fi

# Check if already initialized at v1+
CURRENT_VERSION="$(sqlite3 "$DB_PATH" 'PRAGMA user_version;' 2>/dev/null || echo 0)"

if [ "$CURRENT_VERSION" -ge 1 ]; then
  echo "cast-observe: database already initialized at $DB_PATH (schema v${CURRENT_VERSION})" >&2
  exit 0
fi

sqlite3 "$DB_PATH" <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys = ON;

-- Sessions: one row per Claude Code session
CREATE TABLE IF NOT EXISTS sessions (
  id                    TEXT PRIMARY KEY,          -- CLAUDE_SESSION_ID
  project               TEXT,                      -- git repo name
  project_root          TEXT,                      -- absolute path to repo root
  started_at            TEXT,                      -- ISO8601
  ended_at              TEXT,
  total_input_tokens    INTEGER DEFAULT 0,
  total_output_tokens   INTEGER DEFAULT 0,
  total_cost_usd        REAL    DEFAULT 0.0,
  model                 TEXT                       -- primary model used
);

-- Agent runs: one row per agent invocation
CREATE TABLE IF NOT EXISTS agent_runs (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id      TEXT REFERENCES sessions(id),
  agent           TEXT NOT NULL,                   -- 'code-reviewer', 'debugger', etc.
  model           TEXT,                            -- model used
  started_at      TEXT,
  ended_at        TEXT,
  status          TEXT CHECK (status IN ('DONE','DONE_WITH_CONCERNS','BLOCKED','NEEDS_CONTEXT','running','failed')),
  input_tokens    INTEGER,
  output_tokens   INTEGER,
  cost_usd        REAL,
  task_summary    TEXT,                            -- first 200 chars of task
  prompt          TEXT,                            -- full prompt (optional, privacy flag)
  project         TEXT,
  agent_id        TEXT                             -- Claude Code agent_id for cross-event correlation
);

-- Routing events: for forward compatibility with CAST — cast-observe reads but does not write
CREATE TABLE IF NOT EXISTS routing_events (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id      TEXT,
  timestamp       TEXT,
  prompt_preview  TEXT,                            -- first 80 chars of prompt
  action          TEXT,                            -- matched | no_match | group_dispatched | loop_break
  matched_route   TEXT,
  match_type      TEXT,                            -- regex | semantic | group | catchall
  pattern         TEXT,
  confidence      TEXT,                            -- hard | soft | semantic
  project         TEXT,
  event_type      TEXT,
  data            TEXT                             -- JSON blob of event-specific data
);

-- Cost budgets
CREATE TABLE IF NOT EXISTS budgets (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  scope         TEXT,                              -- session | project | global
  scope_key     TEXT,                              -- session_id | project_name | 'global'
  period        TEXT,                              -- daily | weekly | monthly | per-session
  limit_usd     REAL,
  alert_at_pct  REAL DEFAULT 0.80,                -- warn at 80% consumed
  created_at    TEXT
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_sessions_started_at      ON sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_agent_runs_session       ON agent_runs(session_id);
CREATE INDEX IF NOT EXISTS idx_agent_runs_agent         ON agent_runs(agent);
CREATE INDEX IF NOT EXISTS idx_agent_runs_status        ON agent_runs(status);
CREATE INDEX IF NOT EXISTS idx_agent_runs_agent_id      ON agent_runs(agent_id);

-- Set schema version
PRAGMA user_version = 1;
SQL

echo "cast-observe: database initialized at $DB_PATH"
