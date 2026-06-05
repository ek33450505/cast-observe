#!/bin/bash
# observe-subagent-stop.sh — cast-observe SubagentStop hook
# Hook event: SubagentStop
#
# Fires when a subagent stops (naturally or at turn limit).
# Responsibilities:
#   1. Emit task_completed or task_blocked event to ~/.claude/cast/events/
#   2. Mirror completed/blocked status to cast.db agent_runs table if accessible
#   3. If agent output contains [TURN CEILING], write checkpoint log to
#      ~/.claude/observe/turn-ceiling-events/
#
# Stdin JSON fields (SubagentStop):
#   agent_name      — name of the subagent that stopped
#   session_id      — parent session ID
#   output          — agent's final output text (may be large)
#   stop_reason     — reason for stop (e.g. "max_turns", "end_turn", "error")
#
# Exit codes:
#   0 — always (hook must not block the parent session)

# Never fail loudly — a broken hook must not interrupt the parent session.
set +e

CAST_DIR="${HOME}/.claude/cast"
EVENTS_DIR="${CAST_DIR}/events"
TURN_CEILING_DIR="${CAST_DIR}/turn-ceiling-events"
DB_PATH="${CAST_DB_PATH:-${HOME}/.claude/cast.db}"
STOP_ERROR_LOG="${HOME}/.claude/logs/subagent-stop-errors.log"
mkdir -p "${HOME}/.claude/logs" 2>/dev/null || true

# _log_error: append a structured error line to hook-errors.log (never fails itself)
_log_error() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR $0: $1" >> "${HOME}/.claude/logs/hook-errors.log" 2>/dev/null || true; }

mkdir -p "$EVENTS_DIR" 2>/dev/null || true

# Read stdin once
INPUT="$(cat 2>/dev/null)"
if [ -z "$INPUT" ]; then
  exit 0
fi

# Parse fields from JSON input via env var (never interpolate into Python source)
export CAST_STOP_INPUT="$INPUT"

PARSED="$(python3 - <<'PYEOF' 2>/dev/null
import sys, json, os

raw = os.environ.get('CAST_STOP_INPUT', '')
if not raw:
    print(json.dumps({"error": "no input"}))
    sys.exit(0)

try:
    data = json.loads(raw)
except Exception:
    print(json.dumps({"error": "invalid json"}))
    sys.exit(0)

# Extract response text — try structured agent_response.content first (Phase C payload),
# then fall back to flat last_assistant_message / output fields (older dispatch paths).
# This multi-path approach fixes truncation underrecording: cast-truncation-check.sh
# only reads agent_response.content, so agents dispatched via older paths were missed.
response_text = ''
try:
    agent_response = data.get('agent_response') or {}
    content_blocks = agent_response.get('content') or []
    if isinstance(content_blocks, list) and content_blocks:
        texts = [
            block.get('text', '')
            for block in content_blocks
            if isinstance(block, dict) and block.get('type') == 'text'
        ]
        response_text = '\n'.join(t for t in texts if t)
except Exception:
    response_text = ''

# Flat-field fallback: last_assistant_message or output
if not response_text:
    response_text = (
        data.get('last_assistant_message') or
        data.get('output') or
        data.get('body') or
        ''
    )

flat_output = data.get("last_assistant_message") or data.get("output") or ""

result = {
    # SubagentStop stdin uses 'agent_type' (not 'agent_name') per Claude Code source.
    # 'agent_name' and 'subagent_name' are not sent by Claude Code; 'agent_type' is
    # the correct field (from createBaseHookInput + SubagentStop payload).
    "agent_name": data.get("agent_type") or data.get("agent_name") or data.get("subagent_name") or "unknown",
    "session_id": data.get("session_id") or "",
    "stop_reason": data.get("stop_reason") or "",
    "output_preview": (flat_output or response_text)[:200],
    "has_turn_ceiling": "[TURN CEILING]" in (flat_output or response_text),
    "output_full": flat_output or response_text,
    "response_text": response_text,
    "agent_id": data.get("agent_id") or data.get("subagent_id") or "",
    "duration_ms": data.get("duration_ms") or data.get("total_duration_ms") or 0,
    "tool_uses": len(data.get("tool_uses", [])) if isinstance(data.get("tool_uses"), list) else (data.get("tool_use_count") or 0),
    "cache_read_input_tokens": data.get("cache_read_input_tokens"),
    "cache_creation_input_tokens": data.get("cache_creation_input_tokens"),
}
print(json.dumps(result))
PYEOF
)" || true

if [ -z "$PARSED" ] || echo "$PARSED" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
  : # parsed ok or we'll fall through
else
  exit 0
fi

# Extract individual fields via env var
export CAST_STOP_PARSED="$PARSED"

AGENT_NAME="$(python3 -c "import json,os; d=json.loads(os.environ.get('CAST_STOP_PARSED','{}')); print(d.get('agent_name','unknown'))" 2>/dev/null || echo "unknown")"
SESSION_ID="$(python3 -c "import json,os; d=json.loads(os.environ.get('CAST_STOP_PARSED','{}')); print(d.get('session_id',''))" 2>/dev/null || echo "")"
STOP_REASON="$(python3 -c "import json,os; d=json.loads(os.environ.get('CAST_STOP_PARSED','{}')); print(d.get('stop_reason',''))" 2>/dev/null || echo "")"
HAS_TURN_CEILING="$(python3 -c "import json,os; d=json.loads(os.environ.get('CAST_STOP_PARSED','{}')); print('1' if d.get('has_turn_ceiling') else '0')" 2>/dev/null || echo "0")"
AGENT_ID="$(python3 -c "import json,os; d=json.loads(os.environ.get('CAST_STOP_PARSED','{}')); print(d.get('agent_id',''))" 2>/dev/null || echo "")"
DURATION_MS="$(python3 -c "import json,os; d=json.loads(os.environ.get('CAST_STOP_PARSED','{}')); print(d.get('duration_ms',0))" 2>/dev/null || echo 0)"
TOOL_USES="$(python3 -c "import json,os; d=json.loads(os.environ.get('CAST_STOP_PARSED','{}')); print(d.get('tool_uses',0))" 2>/dev/null || echo 0)"
CACHE_READ_TOKENS="$(python3 -c "import json,os; d=json.loads(os.environ.get('CAST_STOP_PARSED','{}')); print(d.get('cache_read_input_tokens') or '')" 2>/dev/null || echo "")"
CACHE_CREATE_TOKENS="$(python3 -c "import json,os; d=json.loads(os.environ.get('CAST_STOP_PARSED','{}')); print(d.get('cache_creation_input_tokens') or '')" 2>/dev/null || echo "")"
export CAST_STOP_AGENT_ID="$AGENT_ID"
export CAST_STOP_DURATION_MS="$DURATION_MS"
export CAST_STOP_TOOL_USES="$TOOL_USES"
export CAST_STOP_CACHE_READ_TOKENS="$CACHE_READ_TOKENS"
export CAST_STOP_CACHE_CREATE_TOKENS="$CACHE_CREATE_TOKENS"

# Determine event type: blocked if [TURN CEILING] or stop_reason indicates error
EVENT_TYPE="task_completed"
if [ "$HAS_TURN_CEILING" = "1" ]; then
  EVENT_TYPE="task_blocked"
elif echo "$STOP_REASON" | grep -qiE "(error|fail|rate.?limit|timeout)" 2>/dev/null; then
  EVENT_TYPE="task_blocked"
fi

# ── Step 1: Write event to ~/.claude/observe/events/ ─────────────────────────
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || python3 -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))")"
TIMESTAMP_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || python3 -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).isoformat()+'Z')" | sed 's/+00:00//')"
SAFE_AGENT="${AGENT_NAME//[^a-zA-Z0-9_-]/}"
EVENT_FILE="${EVENTS_DIR}/${TIMESTAMP}-${SAFE_AGENT}-subagent-stop.json"

export CAST_STOP_EVENT_TYPE="$EVENT_TYPE"
export CAST_STOP_AGENT="$AGENT_NAME"
export CAST_STOP_SESSION="$SESSION_ID"
export CAST_STOP_REASON="$STOP_REASON"
export CAST_STOP_TS_ISO="$TIMESTAMP_ISO"
export CAST_STOP_EVENT_FILE="$EVENT_FILE"

python3 - <<'PYEOF' 2>/dev/null || true
import json, os

event = {
    "event_id":    os.environ.get('CAST_STOP_AGENT','unknown') + '-subagent-stop-' + os.environ.get('CAST_STOP_TS_ISO',''),
    "timestamp":   os.environ.get('CAST_STOP_TS_ISO',''),
    "event_type":  os.environ.get('CAST_STOP_EVENT_TYPE','task_completed'),
    "agent":       os.environ.get('CAST_STOP_AGENT','unknown'),
    "session_id":  os.environ.get('CAST_STOP_SESSION',''),
    "stop_reason": os.environ.get('CAST_STOP_REASON',''),
    "source":      "SubagentStop",
}

filepath = os.environ.get('CAST_STOP_EVENT_FILE','')
if filepath:
    with open(filepath, 'w') as f:
        json.dump(event, f, indent=2)
PYEOF

# ── Step 2: Mirror to cast.db agent_runs (best-effort) ───────────────────────
if command -v sqlite3 >/dev/null 2>&1 && [ -f "$DB_PATH" ] && [ -s "$DB_PATH" ]; then
  DB_STATUS="DONE"
  if [ "$EVENT_TYPE" = "task_blocked" ]; then
    DB_STATUS="BLOCKED"
  fi
  export CAST_STOP_DB_STATUS="$DB_STATUS"
  CAST_STOP_RESPONSE_TEXT="$(python3 -c "import json,os; d=json.loads(os.environ.get('CAST_STOP_PARSED','{}')); print(d.get('response_text','') or d.get('output_full',''))" 2>/dev/null || echo "")"
  export CAST_STOP_RESPONSE_TEXT
  python3 - <<'PYEOF' 2>>"$STOP_ERROR_LOG" || true
import sqlite3, os, time

db    = os.path.expanduser(os.environ.get('CAST_DB_PATH', '~/.claude/cast.db'))
agent = os.environ.get('CAST_STOP_AGENT', '')
sess  = os.environ.get('CAST_STOP_SESSION', '')
ts    = os.environ.get('CAST_STOP_TS_ISO', '')
st    = os.environ.get('CAST_STOP_DB_STATUS', 'DONE')
err_log = os.path.expanduser('~/.claude/logs/hook-errors.log')
duration_ms   = int(os.environ.get('CAST_STOP_DURATION_MS', '0') or '0')
tool_uses     = int(os.environ.get('CAST_STOP_TOOL_USES', '0') or '0')
response_text = os.environ.get('CAST_STOP_RESPONSE_TEXT', '') or None
cache_read    = os.environ.get('CAST_STOP_CACHE_READ_TOKENS', '') or None
cache_create  = os.environ.get('CAST_STOP_CACHE_CREATE_TOKENS', '') or None
if cache_read:
    cache_read = int(cache_read)
if cache_create:
    cache_create = int(cache_create)

if not agent or not db:
    raise SystemExit(0)

def _log_hook_error(msg):
    try:
        from datetime import datetime, timezone
        t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with open(err_log, 'a') as f:
            f.write(f"[{t}] ERROR observe-subagent-stop.sh: {msg}\n")
    except Exception:
        pass

agent_id = os.environ.get('CAST_STOP_AGENT_ID', '')

# Add new telemetry columns if they don't exist (idempotent — forward compat with flagship schema)
try:
    conn = sqlite3.connect(db, timeout=5)
    for col, coltype in [
        ('duration_ms', 'INTEGER'),
        ('tool_uses',   'INTEGER'),
        ('response',    'TEXT'),
    ]:
        try:
            conn.execute(f'ALTER TABLE agent_runs ADD COLUMN {col} {coltype}')
        except Exception:
            pass  # column already exists
    conn.commit()
    conn.close()
except Exception:
    pass

# Retry up to 3 times with backoff on SQLITE_BUSY / locked
for attempt in range(3):
    try:
        conn = sqlite3.connect(db, timeout=5)
        cur  = conn.cursor()
        if agent_id:
            cur.execute(
                "UPDATE agent_runs SET status=?, ended_at=?, duration_ms=?, tool_uses=?, response=?, cache_read_input_tokens=?, cache_creation_input_tokens=? "
                "WHERE status='running' AND agent_id=?",
                (st, ts, duration_ms, tool_uses, response_text, cache_read, cache_create, agent_id),
            )
        else:
            cur.execute(
                "UPDATE agent_runs SET status=?, ended_at=?, duration_ms=?, tool_uses=?, response=?, cache_read_input_tokens=?, cache_creation_input_tokens=? "
                "WHERE status='running' AND agent=? AND session_id=? "
                "AND id=(SELECT MIN(id) FROM agent_runs WHERE status='running' AND agent=? AND session_id=?)",
                (st, ts, duration_ms, tool_uses, response_text, cache_read, cache_create, agent, sess, agent, sess),
            )
        conn.commit()
        conn.close()
        break
    except sqlite3.OperationalError as e:
        conn_close_safe = locals().get('conn')
        if conn_close_safe:
            try: conn_close_safe.close()
            except Exception: pass
        if 'locked' in str(e) and attempt < 2:
            time.sleep(0.1 * (attempt + 1))
        else:
            _log_hook_error(f"DB UPDATE failed after {attempt+1} attempt(s): {e}")
            break
    except Exception as e:
        _log_hook_error(f"DB UPDATE unexpected error: {type(e).__name__}: {e}")
        break
PYEOF
fi

# ── Step 3: Turn ceiling checkpoint ──────────────────────────────────────────
if [ "$HAS_TURN_CEILING" = "1" ]; then
  mkdir -p "$TURN_CEILING_DIR" 2>/dev/null || true
  CEIL_FILE="${TURN_CEILING_DIR}/${TIMESTAMP}-${SAFE_AGENT}.json"

  export CAST_CEIL_FILE="$CEIL_FILE"
  python3 - <<'PYEOF' 2>/dev/null || true
import json, os

raw = os.environ.get('CAST_STOP_PARSED', '{}')
try:
    parsed = json.loads(raw)
except Exception:
    parsed = {}

checkpoint = {
    "timestamp":    os.environ.get('CAST_STOP_TS_ISO', ''),
    "agent":        os.environ.get('CAST_STOP_AGENT', 'unknown'),
    "session_id":   os.environ.get('CAST_STOP_SESSION', ''),
    "stop_reason":  os.environ.get('CAST_STOP_REASON', ''),
    "event":        "turn_ceiling_hit",
    "output_preview": parsed.get("output_preview", ""),
    "resume_hint":  "Re-invoke the agent with --resume or dispatch orchestrator to continue from last checkpoint.",
}

filepath = os.environ.get('CAST_CEIL_FILE', '')
if filepath:
    with open(filepath, 'w') as f:
        json.dump(checkpoint, f, indent=2)
PYEOF
fi

exit 0
