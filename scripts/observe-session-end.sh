#!/bin/bash
# observe-session-end.sh — cast-observe consolidated session-end hook
# Hook events: Stop, SessionEnd
# Timeout: 15 seconds
#
# Purpose:
#   On session end, perform cast-observe cleanup tasks:
#   - Touch hook-health marker
#   - Escalate on repeated BLOCKED responses
#   - Prune old rows from cast.db
#   - Clean cast-observe temp files for this session
#
# Exit codes:
#   0 — always (hook must NEVER block session close)

# --- Subprocess guard (must be first) ---
if [ "${CLAUDE_SUBPROCESS:-0}" = "1" ]; then exit 0; fi

set +e

# _log_error: append a structured error line to hook-errors.log (never fails itself)
mkdir -p "${HOME}/.claude/logs" 2>/dev/null || true
_log_error() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR $0: $1" >> "${HOME}/.claude/logs/hook-errors.log" 2>/dev/null || true; }

CAST_DIR="${HOME}/.claude/cast"
SESSION_ID="${CLAUDE_SESSION_ID:-default}"

# === HOOK HEALTH MARKER ===
mkdir -p "${CAST_DIR}/hook-last-fired" && touch "${CAST_DIR}/hook-last-fired/Stop.timestamp" "${CAST_DIR}/hook-last-fired/SessionEnd.timestamp"

# === BLOCKED COUNT ESCALATION ===
BLOCKED_LOG="${CAST_DIR}/blocked-count.txt"
BLOCKED_COUNT=$(cat "$BLOCKED_LOG" 2>/dev/null || echo 0)
if [ "${BLOCKED_COUNT}" -ge 2 ] 2>/dev/null; then
  echo "[CAST-ESCALATE] WARNING: ${BLOCKED_COUNT} consecutive BLOCKED responses detected. Human intervention may be required. Check ${CAST_DIR}/events/ for details." >&2
  rm -f "$BLOCKED_LOG"
fi

# === DB PRUNING ===
TTL_DB_ROWS=90
DB="${HOME}/.claude/cast.db"
if command -v sqlite3 >/dev/null 2>&1 && [ -f "$DB" ]; then
  sqlite3 "$DB" "DELETE FROM agent_runs WHERE started_at < datetime('now', '-${TTL_DB_ROWS} days');" 2>/dev/null || true
  sqlite3 "$DB" "DELETE FROM sessions WHERE started_at < datetime('now', '-${TTL_DB_ROWS} days');" 2>/dev/null || true
  # Convert ghost rows (stuck 'running') older than 2 hours to 'failed'
  sqlite3 "$DB" "UPDATE agent_runs SET status='failed' WHERE status='running' AND started_at < datetime('now', '-2 hours');" 2>/dev/null || true
fi

# === TEMP FILE CLEANUP ===
rm -f "${TMPDIR:-/tmp}/cast-depth-${PPID}.depth" 2>/dev/null || true
rm -f "${TMPDIR:-/tmp}/cast-blocked-${SESSION_ID}"*.count 2>/dev/null || true

exit 0
